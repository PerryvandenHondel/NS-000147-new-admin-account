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
	FLD_ADM_ID = 			'adm_id';
	FLD_ADM_UPN_SUFF = 		'adm_upn_suffix';
	FLD_ADM_DOM_NT = 		'adm_domain_nt';
	FLD_ADM_IS_ACTIVE = 	'adm_is_active';
	FLD_ADM_OU = 			'adm_org_unit';
	
	
procedure ProcessSingleActiveDirectory(dn: string; domainNt: string; ou: string);
var
	c: string;
	csv: CTextSeparated;
	el: integer;
	f: string;
begin
	WriteLn('ProcessSingleActiveDirectory()');
	
	
	// Set the file name
	f := '$$export.csv';
	
	// Delete any existing file.
	DeleteFile(f);
	
	c := 'adfind.exe ';
	c := c + '-b "' + ou + ',' + dn + '" ';
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
	csv.SetSeparator(';'); // Tab char as separator
	// dn;sAMAccountName;givenName;sn
	csv.ReadHeader();
	
	WriteLn('givenName is found at pos: ', csv.GetPosOfHeaderItem('givenName'));
	
	WriteLn('Open file: ', csv.GetPath(), ' status = ', BoolToStr(csv.GetStatus, 'OPEN', 'CLOSED'));
	repeat
		csv.ReadLine();
		WriteLn('  headernum1=', csv.GetValue('givenName')); 
		//WriteLn('  headerstr1=', csv.GetValue('dn')); 
		
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
	
	qs := 'SELECT ' + FLD_ADM_ID + ',' + FLD_ADM_DOM_NT + ',' + FLD_ADM_OU + ' ';
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
			
			rootDse := rs.FieldByName(FLD_ADM_ID).AsString;
			domainNt := rs.FieldByName(FLD_ADM_DOM_NT).AsString;
			ou := rs.FieldByName(FLD_ADM_OU).AsString;
			
			//WriteLn(rootDse);
			
			ProcessSingleActiveDirectory(rootDse, domainNt, ou);

			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure ProcessAllAds()


begin
	DatabaseOpen();
	ProcessAllActiveDirectories();
	DatabaseClose();
end.  // of program NaaUpdateTables