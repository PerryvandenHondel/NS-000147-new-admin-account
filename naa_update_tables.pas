//
//	PROGRAM
//		NAA
//
//	SUB
//		Read AD and fill database tables with the latest account information
//
//


program NaaUpdateTables;


{$MODE OBJFPC}
{$LONGSTRINGS ON}		// Compile all strings as Ansistrings


uses
	SysUtils,
	USupportLibrary,
	UTextSeparated,
	ODBCConn,
	SqlDb,
	naa_db;
	

const
	TBL_ADM =				'account_domain_adm';
	FLD_ADM_ROOTDSE = 		'adm_root_dse';
	FLD_ADM_ID = 			'adm_id';
	FLD_ADM_UPN_SUFF = 		'adm_upn_suffix';
	FLD_ADM_DOM_NT = 		'adm_domain_nt';
	FLD_ADM_IS_ACTIVE = 	'adm_is_active';
	FLD_ADM_OU = 			'adm_org_unit';
	
	TBL_ATV = 				'account_active_atv';
	FLD_ATV_ID = 			'atv_id';
	FLD_ATV_DN = 			'atv_dn';
	FLD_ATV_UPN = 			'atv_upn';
	FLD_ATV_SORT = 			'atv_sort';
	FLD_ATV_IS_ACTIVE = 	'atv_is_active';
	FLD_ATV_RLU = 			'atv_rlu';


var
	updateDateTime: TDateTime;


procedure DeleteObsoleteRecords(updateDateTime: TDateTime);
var
	qu: string;
begin
	qu := 'DELETE FROM ' + TBL_ATV + ' ';
	qu := qu + 'WHERE ' + FLD_ATV_RLU + '<' + EncloseSingleQuote(DateTimeToStr(updateDateTime)) + ';';
	WriteLn(qu);
	RunQuery(qu);
end; // of procedure DeleteObsoleteRecords
	
	
procedure RecordAddAccount(dn: string; fname: string; lname: string; upn: string);
//
//	Add a new record to the table when it does not exist yet, key = dn.
//
var
	qs: string;
	qi: string;
	qu: string;
	id: integer;
	rs: TSQLQuery; // Uses SqlDB
begin
	qs := 'SELECT ' + FLD_ATV_ID + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' + FLD_ATV_DN + '=' + FixStr(dn) + ';';
	
	WriteLn(qs);
	
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
			qi := qi + FLD_ATV_SORT + '=' + FixStr(lname + ', ' + fname + ' (' + upn + ')') + ',';
			
		qi := qi + FLD_ATV_IS_ACTIVE + '=1,';
		qi := qi + FLD_ATV_UPN + '=' + FixStr(upn) + ',';
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
			qu := qu + FLD_ATV_SORT + '=' + FixStr(lname + ', ' + fname + ' (' + upn + ')') + ',';
		
		qu := qu + FLD_ATV_UPN + '=' + FixStr(upn) + ',';
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
	
	for x := 0 to High(a) do
	begin
		//WriteLn(x, ':', a[x]);
		if Pos(a[x], s) > 0 then
			r := true;
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
begin
	WriteLn('ProcessSingleActiveDirectory()');
	
	
	// Set the file name
	f := '$$export.csv';
	
	// Delete any existing file.
	DeleteFile(f);
	
	c := 'adfind.exe ';
	c := c + '-b "' + ou + ',' + rootDse + '" ';
	//c := c + '-f "sAMAccountName=*_*" ';
	c := c + '-f "(&(objectCategory=person)(objectClass=user))" ';
	c := c + 'sAMAccountName givenName sn userPrincipalName ';
	c := c + '-csv -nocsvq -csvdelim ;' ;
	c := c + '>' + f;
	WriteLn(c);
	
	el := RunCommand(c);
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
	
	WriteLn('givenName is found at pos: ', csv.GetPosOfHeaderItem('givenName'));
	
	WriteLn('Open file: ', csv.GetPath(), ' status = ', BoolToStr(csv.GetStatus, 'OPEN', 'CLOSED'));
	repeat
		csv.ReadLine();
		// dn;sAMAccountName;givenName;sn;userPrincipalName
		dn := csv.GetValue('dn'); 
		if IsValidAdminAccount(dn) = true then
		begin
			//dn;sAMAccountName;givenName;sn;userPrincipalName
			RecordAddAccount(dn, csv.GetValue('givenName'), csv.GetValue('sn'), csv.GetValue('userPrincipalName'));
			//WriteLn('dn=', dn);
		end; // of if
    until csv.GetEof();
	csv.CloseFile();

	csv.Free;
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

	WriteLn(qs);
	
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
			//WriteLn(rs.FieldByName(FLD_CAA_DETAIL_ID).AsInteger);
			//WriteLn(rs.FieldByName(FLD_CAA_FULLNAME).AsString);
			
			rootDse := rs.FieldByName(FLD_ADM_ROOTDSE).AsString;
			domainNt := rs.FieldByName(FLD_ADM_DOM_NT).AsString;
			ou := rs.FieldByName(FLD_ADM_OU).AsString;
			
			ProcessSingleActiveDirectory(rootDse, domainNt, ou);

			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure ProcessAllAds()


begin
	updateDateTime := Now();
	DatabaseOpen();
	ProcessAllActiveDirectories();
	DeleteObsoleteRecords(updateDateTime);
	//WriteLn(IsValidAdminAccount('CN=NSA_Jan.vEngelen,OU=NSA,OU=Beheer,DC=test,DC=ns,DC=nl'));
	//WriteLn(IsValidAdminAccount('CN=SVC_JkfSqlAgentT,OU=Users,OU=Beheer,DC=test,DC=ns,DC=nl'));
	DatabaseClose();
end.  // of program NaaUpdateTables