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
//			ChangeStatusObsoleteRecord();
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
	TBL_ADM =					'account_domain_adm';
	FLD_ADM_ROOTDSE = 			'adm_root_dse';
	FLD_ADM_ID = 				'adm_id';
	FLD_ADM_UPN_SUFF = 			'adm_upn_suffix';
	FLD_ADM_DOM_NT = 			'adm_domain_nt';
	FLD_ADM_MAX_PASSSWORD_AGE_SECS = 'adm_max_password_age_secs';
	FLD_ADM_IS_ACTIVE = 		'adm_is_active';
	FLD_ADM_OU = 				'adm_org_unit';
	
	TBL_ATV = 					'account_active_atv';
	FLD_ATV_ID = 				'atv_id';
	FLD_ATV_IS_ACTIVE = 		'atv_is_active';
	FLD_ATV_ADM_ID = 			'atv_adm_id';
	FLD_ATV_APS_ID = 			'atv_person_aps_id'; // APS_ID
	FLD_ATV_DN = 				'atv_dn';
	FLD_ATV_SORT = 				'atv_sort';
	FLD_ATV_UPN = 				'atv_upn';
	FLD_ATV_SAM = 				'atv_sam';
	FLD_ATV_FNAME = 			'atv_fname'; // givenName
	FLD_ATV_MNAME = 			'atv_mname'; 
	FLD_ATV_LNAME = 			'atv_lname'; // sn
	FLD_ATV_MAIL = 				'atv_mail';
	FLD_ATV_UAC = 				'atv_uac';
	FLD_ATV_REAL_LAST_LOGON = 	'atv_real_last_logon';
	FLD_ATV_PWD_LAST_SET = 		'atv_password_last_set';
	FLD_ATV_CREATED = 			'atv_created';
	FLD_ATV_RLU = 				'atv_rlu';

	TBL_ADD = 					'account_domain_dc_add';
	FLD_ADD_ID = 				'add_id';
	FLD_ADD_ADM_ID = 			'add_adm_id';
	FLD_ADD_FQDN = 				'add_fqdn';
	
	SECONDS_PER_DAY = 			86400;

var
	updateDateTime: TDateTime;
	flagRealLogon: boolean;


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
	WriteLn('ProcessSingleActiveDirectory()');
	
	domainId := GetDomainIdFromRootDse(rootDse);
	WriteLn('  Domain ID=', domainId);
	
	
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
	
	//WriteLn('givenName is found at pos: ', csv.GetPosOfHeaderItem('givenName'));
	
	//WriteLn('Open file: ', csv.GetPath(), ' status = ', BoolToStr(csv.GetStatus, 'OPEN', 'CLOSED'));
	repeat
		csv.ReadLine();
		
		// dn;sAMAccountName;givenName;sn;userPrincipalName
		dn := csv.GetValue('dn');
		
		// Use one line to show the processed 
		Write(i: 4, ': ', dn, #13);
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


procedure ProcessAllActiveDirectories();
var
	qs: string;
	rootDse: string;
	domainNt: string;
	ou: string;
	rs: TSQLQuery;		// Uses SqlDB
begin
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


procedure FindAllDcsForOneDomain(domainId: integer; rootDse: Ansistring);
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
		ReadLn(f, line);
		//Writeln(domainId, ': ', line);
		AddRecordToTableAdd(domainId, line);
	until Eof(f);
	Close(f);
	
	SysUtils.DeleteFile(path);
end;


procedure FillTableAdd();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	domainId: integer;
	rootDse: Ansistring;
begin
	// Clean all records from the DC table ADD
	RunQuery('TRUNCATE TABLE ' +  TBL_ADD+ ';');
	
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
			FindAllDcsForOneDomain(domainId, rootDse);
			rs.Next;
		end;
	end;
	rs.Free;
end;


function CalculateRealLogon(recId: integer; dn: Ansistring): TDateTime;
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
	WriteLn('Calculate real logon for ', recId, ': ', dn);
	
	// Initialize the most recent last logon date time with:
	mostRecentLastLogon := StrToDateTime('1601-01-01 00:00:00');
	
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
	
	{I+}
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


procedure FindRecordsRealLogon();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	mostRecentLastLogon: TDateTime;
	qu: Ansistring;
	recordId: integer;
begin
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_DN + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' +  FLD_ATV_IS_ACTIVE + '=1;';
	
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
			mostRecentLastLogon := CalculateRealLogon(recordId, rs.FieldByName(FLD_ATV_DN).AsString);
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


function GetDomainMaxPasswordAge(rootDse: string): integer;
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
	
	GetDomainMaxPasswordAge := StrToInt(rs);
end; // of GetDomainMaxPasswordAge


procedure UpdateMaxPasswordAgeForEachDomain();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	domainId: integer;
	rootDse: Ansistring;
	maxPasswordAgeSecs: integer;
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
			
			maxPasswordAgeSecs := GetDomainMaxPasswordAge(rootDse);
			WriteLn(rootDse, ' maxPwdAge: ', maxPasswordAgeSecs, ' seconds');
	
			qu := 'UPDATE ' + TBL_ADM + ' ';
			qu := qu + 'SET ' + FLD_ADM_MAX_PASSSWORD_AGE_SECS + '=' + IntToStr(maxPasswordAgeSecs) + ' ';
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
		'--help': ProgramUsage();
	end;

	//WriteLn('Calculate the real last logon per account: ', flagRealLogon);
	
	
	updateDateTime := Now();
	DatabaseOpen();
	
	// Update the max password age from each AD domain.
	UpdateMaxPasswordAgeForEachDomain();
	
	// Get all information from accounts
	ProcessAllActiveDirectories();
	ChangeStatusObsoleteRecord(updateDateTime);
	
	if flagRealLogon = true then
	begin
		FillTableAdd(); // Fill the ADD (Account Domain DC's) with all DC's from a domain
		FindRecordsRealLogon();
	end;
	
	DatabaseClose();
end.  // of program NaaUpdateTables