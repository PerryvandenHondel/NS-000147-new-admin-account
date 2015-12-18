//
//	PROGRAM
//		UPDATE_TABLES.EXE
//
//	SUB
//		Read AD and fill database tables with the latest account information
//
//	Program flow:
//		MAIN
//			UpdateMaxPasswordAgeForEachDomain
//				GetDomainMaxPasswordAge
//			ProcessAllActiveDirectories();
//				ProcessSingleActiveDirectory();
//			ChangeStatusObsoleteRecord();
//			
//			When the flag --real-logon is selected also do:
//
//			LastLogonAllDomains
//				LastLogonOneDomain
//					LastLogonOneDc
//						LastLogonAddRecord
//			LastLogonUpdateActiveAccounts
//				

program update_tables;


{$MODE OBJFPC}
{$LONGSTRINGS ON}		// Compile all strings as Ansistrings


uses
	DateUtils,
	StrUtils,
	SysUtils,
	Process,
	USupportLibrary,
	UTextSeparated,
	ODBCConn,
	SqlDb,
	aam_global;
	

const
	SECONDS_PER_DAY = 								86400;		// 24*60*60 = 86400

	ADS_UF_SCRIPT =									1;        	// 0x1
	ADS_UF_ACCOUNTDISABLE =							2;        	// 0x2
	ADS_UF_HOMEDIR_REQUIRED = 						8;        	// 0x8
	ADS_UF_LOCKOUT = 								16;			// 0x10
	ADS_UF_PASSWD_NOTREQD = 						32;			// 0x20
	ADS_UF_PASSWD_CANT_CHANGE = 					64;			// 0x40
	ADS_UF_ENCRYPTED_TEXT_PASSWORD_ALLOWED = 		128; 		// 0x80
	ADS_UF_TEMP_DUPLICATE_ACCOUNT = 				256;		// 0x100
	ADS_UF_NORMAL_ACCOUNT =							512;		// 0x200
	ADS_UF_INTERDOMAIN_TRUST_ACCOUNT = 				2048;		// 0x800
	ADS_UF_WORKSTATION_TRUST_ACCOUNT = 				4096;		// 0x1000
	ADS_UF_SERVER_TRUST_ACCOUNT = 					8192;	    // 0x2000
	ADS_UF_DONT_EXPIRE_PASSWD = 					65536;		// 0x10000
	ADS_UF_MNS_LOGON_ACCOUNT = 						131072; 	// 0x20000	
	ADS_UF_SMARTCARD_REQUIRED = 					262144;		// 0x40000
	ADS_UF_TRUSTED_FOR_DELEGATION = 				524288;		// 0x80000
	ADS_UF_NOT_DELEGATED = 							1048576;	// 0x100000	
	ADS_UF_USE_DES_KEY_ONLY = 						2097152;	// 0x200000
	ADS_UF_DONT_REQUIRE_PREAUTH = 					4194304;	// 0x400000
	ADS_UF_PASSWORD_EXPIRED =						8388608;	// 0x800000
	ADS_UF_TRUSTED_TO_AUTHENTICATE_FOR_DELEGATION =	16777216;	// 0x1000000

	
var
	updateDateTime: TDateTime;
	pathPid: Ansistring;


function IsUacFlagActive(uncValue: integer; uncFlag: integer): integer;
begin
	if (uncValue and uncFlag) = uncFlag then
		IsUacFlagActive := 1
	else
		IsUacFlagActive := 0;
end;


function GetRecordIdBasedOnFieldValue(tableName: Ansistring; fieldReturn: Ansistring; searchField: Ansistring; searchValue: Ansistring): integer;
//
//	Search in a table tableName for the Record ID (fieldReturn) of search field (fieldSearch) with value fieldValue.
//
//	GetRecordIdBasedOnFieldValue(table, fieldReturn, fieldToSearch, valueToSearch);
var
	qs: Ansistring;
	rs: TSQLQuery; // Uses SqlDB
	returnValue: integer;
begin
	qs := 'SELECT ' + fieldReturn;
	qs := qs + ' ';
	qs := qs + 'FROM';
	qs := qs + ' ';
	qs := qs + tableName;
	qs := qs + ' ';
	qs := qs + 'WHERE';
	qs := qs + ' ';
	qs := qs + searchField + '=' + FixStr(searchValue);
	qs := qs + ';';
	//WriteLn('GetRecordIdBasedOnFieldValue(): ', qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.Eof = true then
		returnValue := 0
	else
		returnValue := rs.FieldByName(fieldReturn).AsInteger;
	
	rs.Free;	
	
	GetRecordIdBasedOnFieldValue := returnValue;
end;
	
	
function IsDisabled(iUac: LongInt): boolean;
	{'
	''	Check the disabled status of an account using the UAC
	''	(User Account Control Value)
	''	
	''	Magic line: If (intUac And ADS_UF_ACCOUNTDISABLE) = ADS_UF_ACCOUNTDISABLE Then DISABLED
	''
	''	Returns
	''		True: 	Account is locked
	''		False:	Account is not locked
	'}
begin;
	if (iUac and ADS_UF_ACCOUNTDISABLE) = ADS_UF_ACCOUNTDISABLE then
		IsDisabled := true
	else
		IsDisabled := false;
		
	
end; // of function IsDisabled
	
	
procedure ChangeStatusObsoleteRecord(updateDateTime: TDateTime);
var
	qu: string;
begin
	qu := 'UPDATE ' + TBL_ATV + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_ATV_IS_ACTIVE + '=999 ';
	qu := qu + 'WHERE ' + FLD_ATV_RLU + '<' + EncloseSingleQuote(DateTimeToStr(updateDateTime)) + ';';
	RunQuery(qu);
end; // of procedure ChangeStatusObsoleteRecord


function GetDomainIdFromRootDse(rootDse: Ansistring): integer;
var
	qs: string;
	rs: TSQLQuery; // Uses SqlDB
	returnValue: integer;
begin
	qs := 'SELECT ' + FLD_ADM_ID + ' ';
	qs := qs + 'FROM ' + TBL_ADM + ' ';
	qs := qs + 'WHERE ' + FLD_ADM_ROOTDSE + '=' + EncloseSingleQuote(rootDse) + ';';
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.Eof = true then
		returnValue := 0
	else
		returnValue := rs.FieldByName(FLD_ADM_ID).AsInteger;
	
	rs.Free;
	GetDomainIdFromRootDse := returnValue;
end;


function GetPasswordAgeOfDomainInDays(domainId: integer): integer;
var
	qs: string;
	rs: TSQLQuery; // Uses SqlDB
	returnValue: integer;
begin
	returnValue := 0;
	
	qs := 'SELECT ' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + ' ';
	qs := qs + 'FROM ' + TBL_ADM + ' ';
	qs := qs + 'WHERE ' + FLD_ADM_ID + '=' + IntToStr(domainId) + ';';
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.Eof = true then
		returnValue := 0
	else
		returnValue := rs.FieldByName(FLD_ADM_MAX_PASSSWORD_AGE_DAYS).AsInteger;

	rs.Free;
	GetPasswordAgeOfDomainInDays := returnValue;
end;


procedure RecordAddAccount(domainId: integer; dn: string; fname: string; lname: string; upn: string; sam: string; mail: string; created: string; uac: string; pwdLastSet: string; objectSid: string);
//
//	Add a new record to the table when it does not exist yet, key = dn.
//	
//		domainId:	Unique record number of the domain in table ADM
//		dn:			Distinguished Name of the object
//		fname:		First name
//		lname:		Last name
//		upn:		User Principal Name > fname.lname@domain.ext
//		sam:		sAMAccountName
//		mail:		E-mail address
//		created: 	Date Time of creation 
//		uac:		User Account Control value
//
var
	recordId: integer;
	qi: string;
	qu: string;
	passwordLastSetDaysAgo: integer;
	passwordExpires: TDateTime;
	maxPasswordAgeInDays: integer;
begin
	upn := LowerCase(upn);
	mail := LowerCase(mail);

	// Calculate the password last set age in days.
	if Pos('0000-00-00', pwdLastSet) > 0 then
	begin
		// pwdLastSet is set to change at next logon, age becomes 0 days old.
		passwordLastSetDaysAgo := 0;
		//passwordExpires := StrToDateTime('0000-00-00 00:00:00');
	end
	else
	begin
		passwordLastSetDaysAgo := DaysBetween(Now(), StrToDateTime(pwdLastSet));
		maxPasswordAgeInDays := GetPasswordAgeOfDomainInDays(domainId);
		passwordExpires := IncDay(StrToDateTime(pwdLastSet), maxPasswordAgeInDays);
		//WriteLn('Password will expire at ', DateTimeToStr(passwordExpires));
	end;

	recordId := GetRecordIdBasedOnFieldValue(TBL_ATV, FLD_ATV_ID, FLD_ATV_OBJECTSID, objectSid);
	if recordId = 0 then
	begin
		// Insert a new record
		qi := 'INSERT INTO ' + TBL_ATV + ' ';
		qi := qi + 'SET ';
		qi := qi + FLD_ATV_DN + '=' + FixStr(dn) + ',';
		
		if Length(fname) = 0 then
			qi := qi + FLD_ATV_SORT + '=' + FixStr(lname + ' (' + upn + ')') + ',' // When only the last name is used
		else
		begin
			qi := qi + FLD_ATV_SORT + '=' + FixStr(lname + ', ' + fname + ' (' + upn + ')') + ',';
			qi := qi + FLD_ATV_FNAME + '=' + FixStr(fname) + ',';
		end; // of if
		
		qi := qi + FLD_ATV_LNAME + '=' + FixStr(lname) + ',';
		qi := qi + FLD_ATV_ADM_ID + '=' + IntToStr(domainId) + ',';
		qi := qi + FLD_ATV_IS_ACTIVE + '=1,';
		qi := qi + FLD_ATV_UPN + '=' + FixStr(upn) + ',';
		qi := qi + FLD_ATV_SAM + '=' + FixStr(sam) + ',';
		qi := qi + FLD_ATV_MAIL + '=' + FixStr(mail) + ',';
		qi := qi + FLD_ATV_CREATED + '=' + FixStr(created) + ',';
		qi := qi + FLD_ATV_PWD_LAST_SET + '=' + FixStr(pwdLastSet) + ',';
		qi := qi + FLD_ATV_OBJECTSID + '=' + FixStr(objectSid) + ',';
		qi := qi + FLD_ATV_PWD_LAST_SET_DAYS_AGO + '=' + IntToStr(passwordLastSetDaysAgo) + ',';
		if passwordLastSetDaysAgo > 0 then
		begin
			qi := qi + FLD_ATV_PWD_EXPIRES_ON + '=' + EncloseSingleQuote(DateTimeToStr(passwordExpires)) + ',';
		end;
		qi := qi + FLD_ATV_UAC + '=' + uac + ',';
		qi := qi + FLD_ATV_UAC_ACCOUNTDISABLED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_ACCOUNTDISABLE)) + ',';
		qi := qi + FLD_ATV_UAC_NOT_DELEGATED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_NOT_DELEGATED)) + ',';
		qi := qi + FLD_ATV_RLU + '=' + EncloseSingleQuote(DateTimeToStr(updateDateTime)) + ';';
		//WriteLn(qi);
		RunQuery(qi);
	end
	else
	begin
		// Update existing record.
		qu := 'UPDATE '+ TBL_ATV + ' ';
		qu := qu + 'SET ';
		
		if Length(fname) = 0 then
			qu := qu + FLD_ATV_SORT + '=' + FixStr(lname + ' (' + upn + ')') + ',' // When only the last name is used
		else
		begin
			qu := qu + FLD_ATV_SORT + '=' + FixStr(lname + ', ' + fname + ' (' + upn + ')') + ',';
			qu := qu + FLD_ATV_FNAME + '=' + FixStr(fname) + ',';
		end; // of if
		
		qu := qu + FLD_ATV_LNAME + '=' + FixStr(lname) + ',';
		qu := qu + FLD_ATV_ADM_ID + '=' + IntToStr(domainId) + ',';
		qu := qu + FLD_ATV_UPN + '=' + FixStr(upn) + ',';
		qu := qu + FLD_ATV_SAM + '=' + FixStr(sam) + ',';
		qu := qu + FLD_ATV_MAIL + '=' + FixStr(mail) + ',';
		qu := qu + FLD_ATV_CREATED + '=' + FixStr(created) + ',';
		qu := qu + FLD_ATV_PWD_LAST_SET + '=' + FixStr(pwdLastSet) + ',';
		qu := qu + FLD_ATV_OBJECTSID + '=' + FixStr(objectSid) + ',';
		qu := qu + FLD_ATV_PWD_LAST_SET_DAYS_AGO + '=' + IntToStr(passwordLastSetDaysAgo) + ',';
		if passwordLastSetDaysAgo > 0 then
		begin
			qu := qu + FLD_ATV_PWD_EXPIRES_ON + '=' + EncloseSingleQuote(DateTimeToStr(passwordExpires)) + ',';
		end;
		qu := qu + FLD_ATV_UAC + '=' + uac + ',';
		qu := qu + FLD_ATV_UAC_ACCOUNTDISABLED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_ACCOUNTDISABLE)) + ',';
		qu := qu + FLD_ATV_UAC_NOT_DELEGATED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_NOT_DELEGATED)) + ',';
		qu := qu + FLD_ATV_RLU + '=' + EncloseSingleQuote(DateTimeToStr(updateDateTime)) + ' ';
		qu := qu + 'WHERE ' + FLD_ATV_ID + '=' + IntToStr(recordId) + ';';
		//WriteLn(qu);
		RunQuery(qu);
	end;
end; // of procedure RecordAddAccount


function IsValidAdminAccount(s: string): boolean;
//
//	Check if the account s is a valid administrative account.
//
//	Does this account has a valid prefix
//
var
	r: boolean;
	a: TStringArray;
	v: string;
	x: integer;
begin
	r := false;
	v := 'BEH_;NSA_;NSI_;NSS_;KPN_;GTN_;CSC_;HP_;EDS_;HPE_';
	a := SplitString(v, ';');
	
	// Bug
	s := UpperCase(s);
	
	//WriteLn('IsValidAdminAccount(): ', s);
	
	for x := 0 to High(a) do
	begin
		//WriteLn(x, ':', a[x]);
		if Pos(a[x], s) > 0 then
		begin
			//WriteLn('   >>>', s, ' IS VALID');
			r := true;
			break;
		end;
	end; // of for
	IsValidAdminAccount := r;
end; // of function IsValidAdminAccount


procedure ProcessSingleActiveDirectory(rootDse: string; domainNt: string; ou: string);
//
//	Process a single AD domain.
//
var
	c: string;
	csv: CTextSeparated;
	el: integer;
	path: Ansistring;
	dn: string;
	i: integer;
	domainId: integer;
begin
	WriteLn;
	WriteLn('ProcessSingleActiveDirectory()');
	
	domainId := GetDomainIdFromRootDse(rootDse);
	//WriteLn('Domain ID=', domainId);
	
	i := 2;  // Start at line 2 with data, line 1 is the header
	
	// TODO: Use a temp file here
	// Set the file name
	//f := 'ad_dump_' + LowerCase(domainNt) + '.tmp';
	path := SysUtils.GetTempFileName(); // Path is C:\Users\<username>\AppData\Local\Temp\TMP00000.tmp
	
	
	// Delete any existing file.
	DeleteFile(path);
	
	c := 'adfind.exe ';
	c := c + '-b "' + ou + ',' + rootDse + '"';
	c := c + ' ';
	c := c + '-f "(&(objectCategory=person)(objectClass=user))"';
	c := c + ' ';
	c := c + 'sAMAccountName';
	c := c + ' ';
	c := c + 'givenName';
	c := c + ' ';
	c := c + 'sn';
	c := c + ' ';
	c := c + 'userPrincipalName';
	c := c + ' ';
	c := c + 'mail';
	c := c + ' ';
	c := c + 'userAccountControl';
	c := c + ' ';
	c := c + 'whenCreated';
	c := c + ' ';
	c := c + 'pwdLastSet';
	c := c + ' ';
	c := c + 'objectSid';
	c := c + ' ';
	c := c + '-csv -nocsvq -csvdelim ;';
	c := c + ' ';
	c := c + '-tdcgt -tdcfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%"'; // Convert whenCreated
	c := c + ' ';
	c := c + '-tdcs -tdcsfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%"'; // Convert lastlogonTimestamp, lockoutTime, pwdLastSet
	c := c + '>' + path;
	WriteLn(c);
	
	el := USupportLibrary.RunCommand(c);
	if el = 0 then
	begin
		WriteLn('File export done!');
	end
	else
		WriteLn('ERROR ', el, ' running command ', c);
		
	csv := CTextSeparated.Create(path);
    csv.OpenFileRead();
	csv.ShowVerboseOutput(false);
	csv.SetSeparator(';'); // Tab char as separator
	csv.ReadHeader();
	
	repeat
		csv.ReadLine();
		
		dn := csv.GetValue('dn');
		
		// Use one line to show the processed 
		Write('Updating database: ', i:4, ' [', AlignLeft(dn, 120), ']'#13);
		Inc(i);
		if IsValidAdminAccount(dn) = true then
		begin
			RecordAddAccount(domainId, dn, csv.GetValue('givenName'), csv.GetValue('sn'), csv.GetValue('userPrincipalName'), csv.GetValue('sAMAccountName'), csv.GetValue('mail'), csv.GetValue('whenCreated'), csv.GetValue('userAccountControl'), csv.GetValue('pwdLastSet'), csv.GetValue('objectSid'));
		end; // of if
    until csv.GetEof();
	csv.CloseFile();
	csv.Free;
	
	SysUtils.DeleteFile(path); // Delete the temp file in path.
	
	WriteLn;
end; // of procedure ProcessSingleActiveDirectory


procedure AddRecordToTableHost(domainId: integer; fqdn: Ansistring);
var
	qi: Ansistring;
	hostId: integer;
begin
	hostId := GetRecordIdBasedOnFieldValue(TBL_HST, FLD_HST_ID, FLD_HST_FQDN, fqdn);
	if hostId = 0 then
	begin
		// Add a record because there is no FQDN found with a valid hostId.
		qi := 'INSERT INTO ' + TBL_HST;
		qi := qi + ' ';
		qi := qi + 'SET';
		qi := qi + ' ';
		qi := qi + FLD_HST_ADM_ID + '=' + IntToStr(domainId);
		qi := qi + ',';
		qi := qi + FLD_HST_FQDN + '=' + FixStr(fqdn);
		qi := qi + ',';
		qi := qi + FLD_HST_IS_ACTIVE + '=1';
		qi := qi + ';';
		
		RunQuery(qi);
	end;
end;


procedure LastLogonAddRecord(domainId: integer; hostId: integer; atvId: integer; lastLogon: TDateTime);
//procedure LastLogonAddRecord(domainId: integer; host: Ansistring; objectSid: Ansistring; atvId: integer; dn: Ansistring; lastLogon: TDateTime);
var	
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_ALL;
	qi := qi + ' ';
	qi := qi + 'SET';
	qi := qi + ' ';
	qi := qi + FLD_ALL_ADM_ID + '=' + IntToStr(domainId);
	qi := qi + ',';
	qi := qi + FLD_ALL_HST_ID + '=' + IntToStr(hostId);
	qi := qi + ',';
	qi := qi + FLD_ALL_ATV_ID + '=' + IntToStr(atvId);
	qi := qi + ',';
	qi := qi + FLD_ALL_LL + '=' + FixStr(DateTimeToStr(lastLogon));
	qi := qi + ';';
	RunQuery(qi);
end;


procedure LastLogonOneDc(domainId: integer; rootDse: Ansistring; fqdn: Ansistring; ou: Ansistring);
var	
	c: Ansistring;
	path: Ansistring;
	f: TextFile;
	line: Ansistring;
	lineSeparated: TStringArray;
	//dn: Ansistring;
	dateToCheck: Ansistring;
	objectSid: Ansistring;
	convertedDateTime: TDateTime;
	atvId: integer;
	hostId: integer;
begin
	fqdn := LowerCase(fqdn); // Proper host name, all small caps.
	WriteLn(#9, '- Domain Controller ', fqdn);
	
	// Get a unique temp path to a file.
	path := SysUtils.GetTempFileName();
	// Delete any existing file.
	SysUtils.DeleteFile(path);
	
	c := 'adfind.exe ';
	c := c + '-h ' + EncloseDoubleQuote(fqdn);
	c := c + ' ';
	c := c + '-b ' + EncloseDoubleQuote(ou + ',' + rootDse);
	c := c + ' ';
	c := c + '-f "' + #38 + '(objectClass=user)(objectCategory=person)"';
	c := c + ' ';
	c := c + 'objectSid';
	c := c + ' ';
	c := c + 'lastLogon';
	c := c + ' ';
	c := c + '-jtsv';			// Output in Tab separated values
	c := c + ' ';
	c := c + '-csvnoq'; 		// Do not add quote's around the exported values
	c := c + ' ';
	c := c + '-csvnoheader';	// Do not add a header to output file
	c := c + ' ';
	c := c + '-tdcs';
	c := c + ' ';
	c := c + '-tdcsfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%"';
	c := c + '>' + path;
	//WriteLn(c);

	RunCommand(c);
	
	AssignFile(f, path);
	{I+}
	try 
		Reset(f);
		repeat
			ReadLn(f, line);
			//WriteLn(#9, line);
			SetLength(lineSeparated, 0);
			lineSeparated := SplitString(line, #9); // Tab separated
			
			//dn := lineSeparated[0];
			objectSid := lineSeparated[1];
			atvId := GetRecordIdBasedOnFieldValue(TBL_ATV, FLD_ATV_ID, FLD_ATV_OBJECTSID, objectSid);
			if atvId > 0 then
			begin
				dateToCheck := lineSeparated[2]; 
				if TryStrToDateTime(dateToCheck, convertedDateTime) = true then
				begin
					begin
						hostId := GetRecordIdBasedOnFieldValue(TBL_HST, FLD_HST_ID, FLD_HST_FQDN, fqdn);
						//WriteLn(#9#9, hostId, #9, objectSid, '=', atvId, #9, DateTimeToStr(convertedDateTime));
						LastLogonAddRecord(domainId, hostId, atvId, convertedDateTime);
					end;
				end;
			end;
		until Eof(f);
		CloseFile(f);
	except
		on E: EInOutError do
			WriteLn('ERROR: File ', path, ' handeling error occurred, Details: ', E.ClassName, '/', E.Message);
	end;
	SysUtils.DeleteFile(path);
end;


procedure LastLogonOneDomain(domainId: integer; rootDse: Ansistring; ou: Ansistring);
var
	path: Ansistring;
	f: TextFile;
	line: Ansistring;
	c: Ansistring;
begin
	path := SysUtils.GetTempFileName();
	
	// Delete any existing file.
	DeleteFile(path);
	
	c := 'adfind.exe ';
	c := c + '-b ' + EncloseDoubleQuote(rootDse) + ' ';
	c := c + '-sc dclist>' + path;
	//WriteLn(c);
	
	USupportLibrary.RunCommand(c);
	
	// Open the text file and read the lines from it.
	Assign(f, path);
	
	{I+}
	Reset(f);
	repeat
		ReadLn(f, line); // line contains the specific DC.
		
		AddRecordToTableHost(domainId, line);
		
		LastLogonOneDc(domainId, rootDse, line, ou);
	until Eof(f);
	Close(f);
	
	SysUtils.DeleteFile(path);
end;


procedure LastLogonAllDomains();
var
	qs: string;
	rootDse: string;
	domainId: integer;
	//domainNt: string;
	ou: string;
	rs: TSQLQuery;		// Uses SqlDB
begin
	WriteLn;
	WriteLn('LastLogonAllDomains()');
	
	qs := 'SELECT ' + FLD_ADM_ID + ',' + FLD_ADM_ROOTDSE + ',' + FLD_ADM_OU + ' ';
	qs := qs + 'FROM ' + TBL_ADM + ' ';
	qs := qs + 'WHERE ' + FLD_ADM_IS_ACTIVE + '=1';
	qs := qs + ';';

	//WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('No records found!')
	else
	begin
		while not rs.EOF do
		begin
			begin
				domainId := rs.FieldByName(FLD_ADM_ID).AsInteger;
				rootDse := rs.FieldByName(FLD_ADM_ROOTDSE).AsString;
				ou := rs.FieldByName(FLD_ADM_OU).AsString;

				Write('- Domain ', rootDse + '                                  ', #13);
			
				LastLogonOneDomain(domainId, rootDse, ou);

			end;
			rs.Next;
		end;
	end;
	rs.Free;
	WriteLn;
end; // of procedure ProcessAllAds()


procedure ProcessAllActiveDirectories();
var
	qs: string;
	rootDse: string;
	domainNt: string;
	ou: string;
	rs: TSQLQuery;		// Uses SqlDB
begin
	WriteLn;
	WriteLn('ProcessAllActiveDirectories()');
	
	qs := 'SELECT ' + FLD_ADM_ROOTDSE + ',' + FLD_ADM_DOM_NT + ',' + FLD_ADM_OU + ' ';
	qs := qs + 'FROM ' + TBL_ADM + ' ';
	qs := qs + 'WHERE ' + FLD_ADM_IS_ACTIVE + '=1';
	qs := qs + ';';

	//WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('No records found!')
	else
	begin
		while not rs.EOF do
		begin
			rootDse := rs.FieldByName(FLD_ADM_ROOTDSE).AsString;
			domainNt := rs.FieldByName(FLD_ADM_DOM_NT).AsString;
			ou := rs.FieldByName(FLD_ADM_OU).AsString;

			ProcessSingleActiveDirectory(rootDse, domainNt, ou);

			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure ProcessAllAds()


procedure AddRecordToTableAdd(domainId: integer; fqdn: Ansistring);
var
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_ADD + ' ' ;
	qi := qi + 'SET ' + FLD_ADD_FQDN + '=' + EncloseSingleQuote(fqdn) + ',';
	qi := qi + FLD_ADD_ADM_ID + '=' + IntToStr(domainId) + ';';
	RunQuery(qi);
end;


function GetRealLastLogon(atvId: integer; created: TDateTime): TDateTime;
var
	qs: Ansistring;
	rs: TSQLQuery; // Uses SqlDB
	lastLogin: TDateTime;
	returnDateTime: TDateTime;
begin
	qs := 'SELECT ' + FLD_ALL_LL;
	qs := qs + ' ';
	qs := qs + 'FROM ' + TBL_ALL;
	qs := qs + ' ';
	qs := qs + 'WHERE ' + FLD_ALL_ATV_ID + '=' + IntToStr(atvId); 
	qs := qs + ' '; 
	qs := qs + 'ORDER BY ' + FLD_ALL_LL + ' DESC';
	qs := qs + ' '; 
	qs := qs + 'LIMIT 1';
	qs := qs + ';'; 
	
	//WriteLn(qs);
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		// There is  no last logon found, returns the created value.
		// Because you can't logon before the account is created.
		returnDateTime := created
	else
	begin
		// Compare the created date with the obtained lastlogon date time.
		// Returns the most recent one.
		lastLogin := StrToDateTime(rs.FieldByName(FLD_ALL_LL).AsString);
		returnDateTime := GetMostRecent(lastLogin, created);
	end;
	GetRealLastLogon := returnDateTime;
end;


procedure LastLogonUpdateActiveAccounts();
var
	qs: Ansistring;
	qu: Ansistring;
	rs: TSQLQuery; // Uses SqlDB
	created: TDateTime;
	atvId: integer;
	realLastLogon: TDateTime;
	realLastLogonDaysAgo: integer;
begin
	WriteLn('LastLogonUpdateActiveAccounts(): Obtaining the real last logon per account and updating ATV table, please wait...');
	qs := 'SELECT ' + FLD_ATV_ID;
	qs := qs + ',';
	qs := qs + FLD_ATV_CREATED;
	qs := qs + ' ';
	qs := qs + 'FROM ' + TBL_ATV;
	qs := qs + ' ';
	qs := qs + 'WHERE ' +  FLD_ATV_IS_ACTIVE + '=1';
	qs := qs + ' ';
	qs := qs + 'ORDER BY ' + FLD_ATV_RLU;
	qs := qs + ';';
	
	WriteLn;
	WriteLn(qs);
	WriteLn;
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('No records found!')
	else
	begin
		while not rs.EOF do
		begin
			atvId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			//dn := rs.FieldByName(FLD_ATV_DN).AsString;
			created := StrToDateTime(rs.FieldByName(FLD_ATV_CREATED).AsString);
			
			//WriteLn(#9, recordId, ' ', dn, ' ', DateTimeToStr(created));
			
			realLastLogon := GetRealLastLogon(atvId, created);
			
			realLastLogonDaysAgo := DaysBetween(Now(), realLastLogon);
			
			Write(#9#9, 'Updating ', atvId, #9,  DateTimeToStr(realLastLogon), '                 ', #13);
			
			// Update the active account record with the most recent logon date time value.
			qu := 'UPDATE ' + TBL_ATV;
			qu := qu + ' ';
			qu := qu + 'SET';
			qu := qu + ' ';
			qu := qu + FLD_ATV_REAL_LAST_LOGON + '=' + EncloseSingleQuote(DateTimeToStr(realLastLogon));
			qu := qu + ',';
			qu := qu + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + '=' + IntToStr(realLastLogonDaysAgo);
			qu := qu + ' ';
			qu := qu + 'WHERE ' + FLD_ATV_ID + '=' + IntToStr(atvId);
			qu := qu + ';';
			
			//WriteLn(qu);
			RunQuery(qu);
			
			rs.Next;
		end;
	end;
	rs.Free;
end;


function GetDomainMaxPasswordAgeInSeconds(rootDse: string): double;
//
//	Get the maximum password age of an AD domain as defined in it's Domain Policy
//
//		rootDse:	Format: DC=domain,DC=ext
//
var
	path: string;
	p: TProcess;
	f: TextFile;
	line: string;
	//r: longint;
	rs: string;
begin
	//r := 0;

	// Get a temp file to store the output of the adfind.exe command.
	path := SysUtils.GetTempFileName(); // Path is C:\Users\<username>\AppData\Local\Temp\TMP00000.tmp
	
	p := TProcess.Create(nil);
	p.Executable := 'cmd.exe'; 
    p.Parameters.Add('/c adfind.exe -b ' + EncloseDoubleQuote(rootDse) + ' -s base maxPwdAge >' + path);
	p.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
	p.Execute;
	
	// Open the text file and read the lines from it.
	Assign(f, path);
	
	{I+}
	Reset(f);
	repeat
		ReadLn(f, line);
		if Pos('>maxPwdAge: ', line) > 0 then
			rs := Trim(StringReplace(line, '>maxPwdAge: ', '', [rfIgnoreCase])); 
	until Eof(f);
	Close(f);
	
	// Delete the temp file
	SysUtils.DeleteFile(path);
	rs := ReplaceText(rs, '0000000', ''); 
	rs := ReplaceText(rs, '-', '');
	
	GetDomainMaxPasswordAgeInSeconds := StrToFloat(rs);
end; // of GetDomainMaxPasswordAge


procedure UpdateMaxPasswordAgeForEachDomain();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	domainId: integer;
	rootDse: Ansistring;
	maxPasswordAgeSecs: double;
	maxPasswordAgeDays: double;
	qu: Ansistring;
begin
	qs := 'SELECT ' + FLD_ADM_ID + ',' + FLD_ADM_ROOTDSE + ' ';
	qs := qs + 'FROM ' + TBL_ADM + ' ';
	qs := qs + 'WHERE ' + FLD_ADM_IS_ACTIVE + '=1';
	qs := qs + ';';
	//WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('No records found!')
	else
	begin
		while not rs.EOF do
		begin
			domainId := rs.FieldByName(FLD_ADM_ID).AsInteger;
			rootDse := rs.FieldByName(FLD_ADM_ROOTDSE).AsString;
			
			//maxPasswordAgeSecs := GetDomainMaxPasswordAge(rootDse);
			maxPasswordAgeSecs := GetDomainMaxPasswordAgeInSeconds(rootDse);
			maxPasswordAgeDays := maxPasswordAgeSecs / 86400;
			WriteLn(rootDse, ' Domain policy maximum password age is ', Int(maxPasswordAgeDays):0:0, ' days');
	
			qu := 'UPDATE ' + TBL_ADM + ' ';
			qu := qu + 'SET ' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + '=' + FloatToStr(maxPasswordAgeDays) + ' ';
			qu := qu + 'WHERE ' + FLD_ADM_ID + '=' + IntToStr(domainId) + ';';
			
			RunQuery(qu);
			rs.Next;
		end;
	end;
	rs.Free;
end;

	
procedure ProgramUsage();
begin
	WriteLn('Usage:');
	WriteLn('  ' + ParamStr(0) + ' <option>');
	WriteLn;
	WriteLn('Options:');
	WriteLn('	--real-logon   Calculate the real logon timestamp by connecting all DC''s in the domain');
	WriteLn('	--help         The help information');
	WriteLn;
end;


begin
	pathPid := GetPathOfPidFile();
	WriteLn('PID file: ', pathPid);
	
	WriteLn('Use option --help to show this programs options');
	
	if ParamStr(1) = '--help' then 
	begin
		ProgramUsage();
		Halt(0);
	end;

	updateDateTime := Now();
	DatabaseOpen();
	
	// Update the maximum password age from each AD domain.
	UpdateMaxPasswordAgeForEachDomain();
	
	// Get all information from accounts
	ProcessAllActiveDirectories();
	ChangeStatusObsoleteRecord(updateDateTime);
	
	if ParamStr(1) = '--real-logon' then 
	begin
		// Collect all last login date times for an account of all domain controllers.
		LastLogonAllDomains();
		// Update the active account with the accurate last logon date time
		// and days ago.
		LastLogonUpdateActiveAccounts();
	end;
	
	DatabaseClose();
	
	DeleteFile(pathPid);
end.  // of program NaaUpdateTables