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
	flagRealLogon: boolean;


function IsUacFlagActive(uncValue: integer; uncFlag: integer): integer;
begin
	if (uncValue and uncFlag) = uncFlag then
		IsUacFlagActive := 1
	else
		IsUacFlagActive := 0;
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
		
	GetDomainIdFromRootDse := returnValue;
end;


procedure RecordAddAccount(domainId: integer; dn: string; fname: string; lname: string; upn: string; sam: string; mail: string; created: string; uac: string; pwdLastSet: string);
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
	qs: string;
	qi: string;
	qu: string;
	id: integer;
	rs: TSQLQuery; // Uses SqlDB
begin
	upn := LowerCase(upn);
	mail := LowerCase(mail);

	qs := 'SELECT ' + FLD_ATV_ID + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' + FLD_ATV_DN + '=' + FixStr(dn) + ';';
	
	//WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	//WriteLn;
	//WriteLn(dn, ': ', BoolToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_ACCOUNTDISABLE)));
	
	if rs.Eof = true then
	begin
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
		qi := qi + FLD_ATV_UAC + '=' + uac + ',';
		qi := qi + FLD_ATV_UAC_ACCOUNTDISABLED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_ACCOUNTDISABLE)) + ',';
		qi := qi + FLD_ATV_UAC_NOT_DELEGATED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_NOT_DELEGATED)) + ',';
		qi := qi + FLD_ATV_RLU + '=' + EncloseSingleQuote(DateTimeToStr(updateDateTime)) + ';';
		//WriteLn(qi);
		RunQuery(qi);
	end
	else
	begin
		//WriteLn('UPDATE!');
		id := rs.FieldByName(FLD_ATV_ID).AsInteger;
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
		qu := qu + FLD_ATV_UAC + '=' + uac + ',';
		qu := qu + FLD_ATV_UAC_ACCOUNTDISABLED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_ACCOUNTDISABLE)) + ',';
		qu := qu + FLD_ATV_UAC_NOT_DELEGATED + '=' + IntToStr(IsUacFlagActive(StrToInt(uac), ADS_UF_NOT_DELEGATED)) + ',';
		qu := qu + FLD_ATV_RLU + '=' + EncloseSingleQuote(DateTimeToStr(updateDateTime)) + ' ';
		qu := qu + 'WHERE ' + FLD_ATV_ID + '=' + IntToStr(id) + ';';
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
	f: string;
	dn: string;
	i: integer;
	//p: integer;
	domainId: integer;
begin
	WriteLn;
	WriteLn('ProcessSingleActiveDirectory()');
	
	domainId := GetDomainIdFromRootDse(rootDse);
	WriteLn('Domain ID=', domainId);
	
	i := 2;  // Start at line 2 with data, line 1 is the header
	
	// Set the file name
	f := 'ad_dump_' + LowerCase(domainNt) + '.tmp';
	
	// Delete any existing file.
	DeleteFile(f);
	
	c := 'adfind.exe ';
	c := c + '-b "' + ou + ',' + rootDse + '"';
	c := c + ' ';
	c := c + '-f "(&(objectCategory=person)(objectClass=user))"';
	c := c + ' ';
	c := c + 'sAMAccountName givenName sn userPrincipalName mail userAccountControl whenCreated pwdLastSet';
	c := c + ' ';
	c := c + '-csv -nocsvq -csvdelim ;';
	c := c + ' ';
	c := c + '-tdcgt -tdcfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%"'; // Convert whenCreated
	c := c + ' ';
	c := c + '-tdcs -tdcsfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%"'; // Convert lastlogonTimestamp, lockoutTime, pwdLastSet
	c := c + '>' + f;
	WriteLn(c);
	
	el := USupportLibrary.RunCommand(c);
	if el = 0 then
	begin
		WriteLn('File export done!');
	end
	else
		WriteLn('ERROR ', el, ' running command ', c);
		
	csv := CTextSeparated.Create(f);
    csv.OpenFileRead();
	csv.ShowVerboseOutput(false);
	csv.SetSeparator(';'); // Tab char as separator
	// dn;sAMAccountName;givenName;sn
	csv.ReadHeader();
	
	repeat
		csv.ReadLine();
		
		dn := csv.GetValue('dn');
		
		// Use one line to show the processed 
		Write('Updating database: ', i:4, ' [', AlignLeft(dn, 120), ']'#13);
		Inc(i);
		if IsValidAdminAccount(dn) = true then
		begin
			RecordAddAccount(domainId, dn, csv.GetValue('givenName'), csv.GetValue('sn'), csv.GetValue('userPrincipalName'), csv.GetValue('sAMAccountName'), csv.GetValue('mail'), csv.GetValue('whenCreated'), csv.GetValue('userAccountControl'), csv.GetValue('pwdLastSet'));
		end; // of if
    until csv.GetEof();
	csv.CloseFile();
	csv.Free;
	WriteLn;
end; // of procedure ProcessSingleActiveDirectory


procedure LastLogonAddRecord(domainId: integer; host: Ansistring; dn: Ansistring; lastLogon: Ansistring);
var	
	qi: Ansistring;
begin
	// Skip lines with empty lastLogon values.
	if Length(lastLogon) = 0 then
		Exit;
	
	// Do not all lines with DN, that's the header
	if Pos('dn', dn) > 0 then
		Exit; 
		
	// Do not process  the lastLogon with invalid date formats.
	if Pos('lastLogon', lastLogon) > 0 then
		Exit;
	
	//WriteLn(#9#9, domainId, '  ' , host, '   ', dn, '     ', lastLogon);
	
	qi := 'INSERT INTO ' + TBL_ALL;
	qi := qi + ' ';
	qi := qi + 'SET';
	qi := qi + ' ';
	qi := qi + FLD_ALL_ADM_ID + '=' + IntToStr(domainId);
	qi := qi + ',';
	qi := qi + FLD_ALL_HOST + '=' + FixStr(host);
	qi := qi + ',';
	qi := qi + FLD_ALL_DN + '=' + FixStr(dn);
	qi := qi + ',';
	qi := qi + FLD_ALL_LL + '=' + FixStr(lastLogon);
	qi := qi + ';';
	
	//WriteLn(qi);
	RunQuery(qi);
end;


procedure LastLogonOneDc(domainId: integer; rootDse: Ansistring; host: Ansistring; ou: Ansistring);
var	
	c: Ansistring;
	path: Ansistring;
	f: TextFile;
	line: Ansistring;
	lineSeparated: TStringArray;
begin
	WriteLn('LastLogonOneDc(): ', domainId, '    ', rootDse, '     ', host, '  ', ou);
	
	// Get a unique temp path to a file.
	path := SysUtils.GetTempFileName();
	// Delete any existing file.
	SysUtils.DeleteFile(path);
	
	host := LowerCase(host); // Proper host name, all small caps.
	
	c := 'adfind.exe ';
	c := c + '-h ' + EncloseDoubleQuote(host) + ' ';
	c := c + '-b ' + EncloseDoubleQuote(ou + ',' + rootDse) + ' ';
	c := c + '-f "' + #38 + '(objectClass=user)(objectCategory=person)" ';
	c := c + 'lastLogon ';
	c := c + '-jtsv -csvnoq ';
	c := c + '-tdcs -tdcsfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%" ';
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
			lineSeparated := SplitString(line, #9);
			LastLogonAddRecord(domainId, host, lineSeparated[0], lineSeparated[1]);
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
				//domainNt := rs.FieldByName(FLD_ADM_DOM_NT).AsString;
				ou := rs.FieldByName(FLD_ADM_OU).AsString;

				WriteLn('- ', rootDse);
			
				LastLogonOneDomain(domainId, rootDse, ou);

				//ProcessSingleActiveDirectory(rootDse, domainNt, ou);
			end;
			rs.Next;
		end;
	end;
	rs.Free;
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

{
function CalculateRealLogon(recId: integer; dn: Ansistring; created: Ansistring): TDateTime;
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	c: Ansistring;
	fqdn: Ansistring;
	path: Ansistring;
	f: TextFile;
	line: Ansistring;
	mostRecentLastLogon: TDateTime;
begin
	WriteLn;
	WriteLn('Calculating the real logon for ', dn, ' (', recId);
	WriteLn('The real logon is made equal to the creation date: ', created);
	
	// Initialize the most recent last logon date time with:
	// Set the real last logon date time as created date time. That's the start.
	// After creation of the account the last logon date time will overwrite the
	// mostRecentLastLogon with logon date times from the specific AD DC's
	mostRecentLastLogon := StrToDateTime(created);
	
	path := SysUtils.GetTempFileName(); // Path is C:\Users\<username>\AppData\Local\Temp\TMP00000.tmp
	SysUtils.DeleteFile(path); // Delete any file that might exists.
	
	qs := 'SELECT ' + FLD_ADD_FQDN + ',' + FLD_ATV_DN + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'INNER JOIN ' + TBL_ADD + ' ON ' + FLD_ADD_ADM_ID + '=' + FLD_ATV_ADM_ID + ' ';
	qs := qs + 'WHERE ' + FLD_ATV_DN + '=' + EncloseSingleQuote(dn) + ' ';
	qs := qs + 'ORDER BY ' + FLD_ADD_FQDN + ';';

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
			fqdn := rs.FieldByName(FLD_ADD_FQDN).AsString;
			dn := rs.FieldByName(FLD_ATV_DN).AsString;
			
			// Obtain the lastLogon value per domain controller for a DN
			c := 'adfind.exe -h ' + EncloseDoubleQuote(LowerCase(fqdn)) + ' ';
			c := c + '-b ' + EncloseDoubleQuote(dn) + ' ';
			c := c + 'lastLogon ';
			c := c + '-csv -csvnoheader -tdcs -tdcsfmt "%YYYY%-%MM%-%DD% %HH%:%mm%:%ss%" ';
			c := c + '-nodn ';
			c := c + '-nocsvq ';
			c := c + '>>' + path;
			USupportLibrary.RunCommand(c);
			
			rs.Next;
		end;
	end;
	rs.Free;
	
	// Open the text file and read the lines from it.
	Assign(f, path);
	
	Reset(f);
	repeat
		ReadLn(f, line);
		WriteLn(line);
		if (Length(line) > 0) and (line[1] <> '0') then
			// Only read the date time when
			// - The length of the line is longer then 0.
			// - The line does not start with a year 0.
			mostRecentLastLogon := GetMostRecent(mostRecentLastLogon, StrToDateTime(line));
	until Eof(f);
	Close(f);
	
	SysUtils.DeleteFile(path);
	
	CalculateRealLogon := mostRecentLastLogon;
end;
}

function GetRealLastLogon(dn: Ansistring; created: TDateTime): TDateTime;
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
	qs := qs + 'WHERE ' + FLD_ALL_DN + '=' + EncloseSingleQuote(dn); 
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
		returnDateTime := created
	else
	begin
		// Compare the created date with the obtained lastlogon date time.
		// Returns the most recent one.
		lastLogin := StrToDateTime(rs.FieldByName(FLD_ALL_LL).AsString);
		returnDateTime := GetMostRecent(lastLogin, created);
	end;
	//WriteLn('GetRealLastLogon(): ', dn, ' > ', DateTimeToStr(returnDateTime));
	GetRealLastLogon := returnDateTime;
end;


{
procedure FindRecordsRealLogon();
var
	qs: Ansistring;
	rs: TSQLQuery; // Uses SqlDB
	mostRecentLastLogon: TDateTime;
	qu: Ansistring;
	created: Ansistring;
	recordId: integer;
	dn: Ansistring;
begin
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_DN + ',' + FLD_ATV_CREATED + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' +  FLD_ATV_IS_ACTIVE + '=1 ';
	qs := qs + 'ORDER BY ' + FLD_ATV_RLU + ';';
	
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
			recordId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			dn := rs.FieldByName(FLD_ATV_DN).AsString;
			created := rs.FieldByName(FLD_ATV_CREATED).AsString;
			
			mostRecentLastLogon := CalculateRealLogon(recordId, dn, created);
			WriteLn(' >>Most recent last logon is: ', DateTimeToStr(mostRecentLastLogon));
			
			qu := 'UPDATE ' + TBL_ATV + ' ';
			qu := qu + 'SET ' + FLD_ATV_REAL_LAST_LOGON + '=' + EncloseSingleQuote(DateTimeToStr(mostRecentLastLogon)) + ' ';
			qu := qu + 'WHERE ' + FLD_ATV_ID + '=' + IntToStr(recordId) + ';';
			
			RunQuery(qu);
			rs.Next;
		end;
	end;
	rs.Free;
end;
}


procedure LastLogonUpdateActiveAccounts();
var
	qs: Ansistring;
	qu: Ansistring;
	rs: TSQLQuery; // Uses SqlDB
	created: TDateTime;
	recordId: integer;
	dn: Ansistring;
	realLastLogon: TDateTime;
begin
	WriteLn('LastLogonUpdateActiveAccounts(): Obtaining the real last logon per account and updating ATV table, please wait...');
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_DN + ',' + FLD_ATV_CREATED + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' +  FLD_ATV_IS_ACTIVE + '=1 ';
	qs := qs + 'ORDER BY ' + FLD_ATV_RLU + ';';
	
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
			recordId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			dn := rs.FieldByName(FLD_ATV_DN).AsString;
			created := StrToDateTime(rs.FieldByName(FLD_ATV_CREATED).AsString);
			
			//WriteLn(#9, recordId, ' ', dn, ' ', DateTimeToStr(created));
			
			realLastLogon := GetRealLastLogon(dn, created);
			
			// Update the active account record with the most recent logon date time value.
			qu := 'UPDATE ' + TBL_ATV;
			qu := qu + ' ';
			qu := qu + 'SET';
			qu := qu + ' ';
			qu := qu + FLD_ATV_REAL_LAST_LOGON + '=' + EncloseSingleQuote(DateTimeToStr(realLastLogon));
			qu := qu + ' ';
			qu := qu + 'WHERE ' + FLD_ATV_ID + '=' + IntToStr(recordId);
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
	WriteLn('	--real-logon		Calculate the real logon timestamp by connecting all DC''s in the domain');
	WriteLn('	--help				The help information');
	WriteLn;
end;


begin
	flagRealLogon := false;
	if ParamCount = 1 then
	
	case ParamStr(1) of
		'--real-logon': flagRealLogon := true;
		'--help': 
			begin
				ProgramUsage();
				Halt(0);
			end;
	end;

	updateDateTime := Now();
	DatabaseOpen();
	
	// Update the max password age from each AD domain.
	UpdateMaxPasswordAgeForEachDomain();
	
	// Get all information from accounts
	ProcessAllActiveDirectories();
	ChangeStatusObsoleteRecord(updateDateTime);
	
	if flagRealLogon = true then
	begin
		// Collect all last login date times for an account of all domain controllers.
		LastLogonAllDomains();
		// Update the active account with the accurate last logon date time.
		LastLogonUpdateActiveAccounts();
	end;
	
	DatabaseClose();
end.  // of program NaaUpdateTables