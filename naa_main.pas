{
	
	New Admin Account (NAA)
	
	PROCEDURES AND FUNCTIONS
	
		procedure ProcessDomain
		procedure MarkInactiveRecords
		procedure UpdateRecord
		procedure InsertRecord
		function DoesObjectIdExist
		procedure DatabaseOpen
		procedure DatabaseClose
		function FixNum
		function FixStr
		function EncloseSingleQuote
		procedure ProgInit
		procedure ProgRun
		procedure ProgDone

		
	FLOW
		ProgInit
			DatabaseOpen
		ProgRun
			FindRecordToCompleteMissingField; 0 > 10
			Check
		ProgDone
			DatabaseClose
		
}



program NewAdminAccount;



{$MODE OBJFPC}



uses
	Crt,
	Classes, 
	DateUtils,						// For SecondsBetween
	Process, 
	SysUtils,
	USupportLibrary,
	SqlDB,
	naa_db;
	//UTextFile;
	
	
	
const
	//FNAME_DOMAIN = 			'domain.conf';
	//DSN = 					'DSN_ADBEHEER_32';
	
	//TBL_LA = 				'lookup_account';
	//FLD_LA_ID = 			'rec_id';
//	FLD_LA_DN = 			'account_dn';
	//FLD_LA_DOM = 			'account_domain';
	//FLD_LA_UPN = 			'account_upn';
	//FLD_LA_NB = 			'account_netbios';
	//FLD_LA_OID = 			'account_object_id';
	//FLD_LA_UN = 			'account_username';
	//FLD_LA_ACTIVE = 		'is_active';
	//FLD_LA_RCD = 			'rcd';
	//FLD_LA_RLU = 			'rlu';
	
	STEP_MOD = 				27;

	
Type
	TMiddleNameRec = Record
		find: string;
		repl: string;
	end;

//var
	//gConnection: TODBCConnection;               // uses ODBCConn
	//gTransaction: TSQLTransaction;  			// Uses SqlDB
	//gstrNow: string;
	
	
{

procedure ProcessDomain(strRootDn: string; strDomainNetbios: string);
var
	f: TextFile;
	p: TProcess;
	c: string;
	fn: string;
	r: integer;
	strLine: Ansistring;
	arrLine: TStringArray;
	intLine: integer;
begin
	WriteLn;
	WriteLn('PROCESSDOMAIN(' + strDomainNetbios + ')');
	//WriteLn('  RootDse: ', strRootDn, '   NetBIOS: ', strDomainNetbios);
	
	// Set the date time of the update for the specific domain.
	gstrNow := DateTimeToStr(Now);
	//WriteLn('Set current update date time to ' + gstrNow + ' for domain ' + strDomainNetbios);
	
	// Buil the file name for the domain export.
	fn := strDomainNetbios + '.tmp';
	
	// Build the command line.
	// adfind -b dc=test,dc=ns,dc=nl -f "(&(objectCategory=Person)(objectClass=User))" sAMAccountName ObjectSid userPrincipalName -csv -nocsvq > TEST.tmp
	c := 'adfind.exe ';
	c := c + '-b ' + strRootDn + ' ';
	c := c + '-f "(&(objectCategory=Person)(objectClass=User))" ';
	c := c + 'sAMAccountName ObjectSid userPrincipalName ';
	c := c + '-csv -nocsvq -csvdelim "|" ';
	c := c + '>' + fn;
	
	WriteLn('Running: ' + c);
	
	// Setup the process to be executed.
	p := TProcess.Create(nil);
	p.Executable := 'cmd.exe'; 
	p.Parameters.Add('/c ' + c);
	//p.Options := [poWaitOnExit];
	p.Options := [poWaitOnExit, poUsePipes];
	
	WriteLn('Exporting all account info from domain '+ strDomainNetbios + ', please wait...');
	
	// Run the sub process.
	p.Execute;
	
	// Get the return code from the process.
	r := p.ExitStatus;
	
	if r = 0 then
	begin
		WriteLn('Importing ' + fn + ' into table ' + TBL_LA + ' for domain ' + strDomainNetbios + ', please wait...');
		
		intLine := 0;
		
		AssignFile(f, fn);}
		{I+}
		{
		try 
			Reset(f);
			repeat
				// Process  every line in the export tmp file.
				ReadLn(f, strLine);
				Inc(intLine);
				if (Length(strLine) > 0) and (intLine > 1) then
				begin
					// Only process valid lines with content.
					arrLine := SplitString(strLine, '|');
					//ProcessDomain(FNAME_ACCOUNT, arrLine[0], arrLine[1] + ',' + arrLine[0], arrLine[2]);
					// Display processed line, remove for speedier processing.
					//WriteLn(intLine:6, ' LINE: ', strLine);
					//WriteLn('   - DN:                ', arrLine[0]);
					//WriteLn('   - sAMAccountName:    ', arrLine[1]);
					//WriteLn('   - ObjectSid:         ', arrLine[2]);
					//WriteLn('   - userPrincipalName: ', arrLine[3]);
					//WriteLn;
					
					if DoesObjectIdExist(arrLine[2]) = true then
						InsertRecord(strDomainNetbios, arrLine[0], arrLine[1], arrLine[2], arrLine[3], gstrNow, gstrNow)
					else
						UpdateRecord(strDomainNetbios, arrLine[0], arrLine[1], arrLine[2], arrLine[3], gstrNow);
					
					WriteMod(intLine, STEP_MOD)
					
				end;
			until Eof(f);
			CloseFile(f);
		except
			on E: EInOutError do
				WriteLn('File ', fn, ' handeling error occurred, Details: ', E.ClassName, '/', E.Message);
		end;
	end
	else
	begin
		WriteLn('ERROR ', r, ' while exporting accounts from domain ' + strDomainNetbios);
	end;
	
	WriteLn;
	//WriteLn('Set inactive all records of ' + strDomainNetbios + ' where RLU = ' + gstrNow);
	MarkInactiveRecords(strDomainNetbios, gstrNow);
end; // of procedure ProcessDomain
}



function GenerateUserName2(strSupplier: string; strFname: string; strLname: string): string;
var
	MiddleNameArray: Array[1..6] of TMiddleNameRec;
	i: integer;
	strLnameBuffer: string;
	strGenerated: string;
begin
	WriteLn('GenerateUserName2(): ' + strSupplier + '/' + strFname + ' ' + strLname);
	
	strLnameBuffer := strLname;
	
	GenerateUserName2 := '';
	
	MiddleNameArray[1].find := 'van '; 
	MiddleNameArray[1].repl := 'v';
	
	MiddleNameArray[2].find := 'de '; 
	MiddleNameArray[2].repl := 'd';
	
	MiddleNameArray[3].find := 'den '; 
	MiddleNameArray[3].repl := 'd';
	
	MiddleNameArray[4].find := '''t '; 
	MiddleNameArray[4].repl := 't';
	
	MiddleNameArray[5].find := 'der '; 
	MiddleNameArray[5].repl := 'd';
	
	MiddleNameArray[6].find := 'la '; 
	MiddleNameArray[6].repl := 'l';
	
	for i := 1 to Length(MiddleNameArray) do
	begin
		//WriteLn('Find [' + MiddleNameArray[i].find + '] and replace with [' + MiddleNameArray[i].repl + ']');
		strLnameBuffer := StringReplace(strLnameBuffer, MiddleNameArray[i].find, MiddleNameArray[i].repl, [rfReplaceAll, rfIgnoreCase]);
		//WriteLn(strLnameBuffer);
	end;
	
	// Replace the minus character from the Last name.
	strLnameBuffer := StringReplace(strLnameBuffer, '-', '', [rfReplaceAll, rfIgnoreCase]);
	
	//WriteLn('FINAL LASTNAME: '+ strLnameBuffer);
	
	// Generate a full user name <SUPPLIER>_<FNAME>.<LNAME>
	if Length(strFname) = 0 then
		// Check for persons with only 1 name, like Cher and Madonna
		strGenerated := strSupplier + '_' + strLnameBuffer
	else
		// Persons with first and last names.
		strGenerated := strSupplier + '_' + strFname + '.' + strLnameBuffer;
		
	if Length(strGenerated) > 20 then
	begin
		strGenerated := LeftStr(strSupplier + '_' + LeftStr(strFname, 1) + '.' + strLnameBuffer, 20);
		//WriteLn('Finale generated name is to long, so only the first letter of the first name is used.');
		//WriteLn(strGenerated);
	end;
	GenerateUserName2 := strGenerated;
end; // of function GenerateUserName



function GenerateDn(a: string; ou: string; sup: string; useSup: boolean; d: string): string;
//
//	Generate the Distinguished Name (DN) of a account.
//
//	a			Account
//	ou 			Organizational Unit
//	sup			Supplier code
//	useSup		Boolean to use the supplier code
//	d 			Domain
var 
	r: string;
begin
	if useSup = true then
		r := 'CN=' + a + ',OU=' + sup + ',' + ou + ',' + d
	else
		r := 'CN=' + a + ',' + ou + ',' + d;
	
	GenerateDn := r;
end; // of function GenerateDn



function GenerateUpn(strAccountName: string; strDomainName: string): string;
begin
	GenerateUpn := strAccountName + '@'+ strDomainName;
end; // of function GenerateUpn



procedure UpdateTableAccountDetail(recId: integer; userName: string; upn: string; dn: string; pw: string);
//
//	Update the table account_detail with the generated values
//		user name
//		upn
//		dn
//		pw
//
//	Sets the status to 10;
var
	qu: Ansistring;
	q: TSQLQuery;
	t: TSQLTransaction;
begin
	qu := 'UPDATE ' + TBL_ADT + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_ADT_UN + '=' + FixStr(userName) + ',';
	qu := qu + FLD_ADT_DN + '=' + FixStr(dn) + ',';
	qu := qu + FLD_ADT_UPN + '=' + FixStr(upn) + ',';
	qu := qu + FLD_ADT_PW + '=' + FixStr(pw) + ',';
	// Change status to 100 for next step!
	qu := qu + FLD_ADT_STATUS + '=100 ';
	qu := qu + 'WHERE ' + FLD_ADT_ID + '=' + IntToStr(recId) + ';';
	
	WriteLn('UpdateTableAccountDetail():'  + qu);
	
	t := TSQLTransaction.Create(gConnection);
	t.Database := gConnection;
	q := TSQLQuery.Create(gConnection);
	q.Database := gConnection;
	q.Transaction := t;
	q.SQL.Text := qu;
	q.ExecSQL;
	t.Commit;
end;



procedure FindRecordToCompleteMissingField();
//
//	Status
//		0		Find all records that have status 0
//		10		Records are updated with username, dn, upn and pw.
//
var
	qs: Ansistring;
	rs: TSQLQuery;							// Uses SqlDB
	recId: integer;			// Unique record Id
	fname: string;			// First name
	lname: string;			// Last name
	domId: string;			// DC=domain,DC=ext
	upnSuf: string;			// domain.ext
	ou: string;				// OU=ouname
	supName: string;		// SUP
	useSupOu: boolean;		// Boolean
	userName: string;		// Generated user name
	dn: string;				// Distinguished Name of the account
	upn: string;			// full UPN for the account
	pw: string;				// Initial password
begin
	qs := 'SELECT ';
	qs := qs + FLD_CAA_DETAIL_ID + ',';
	qs := qs + FLD_CAA_ACCOUNT_ID + ',';
	qs := qs + FLD_CAA_FNAME + ',';
	qs := qs + FLD_CAA_LNAME + ',';
	qs := qs + FLD_CAA_DOM_ID + ',';
	qs := qs + FLD_CAA_UPN + ',';
	qs := qs + FLD_CAA_NT + ',';
	qs := qs + FLD_CAA_OU + ',';
	qs := qs + FLD_CAA_USE_SUPP_OU + ',';
	qs := qs + FLD_CAA_SUPP_ID + ',';
	qs := qs + FLD_CAA_SUPP_NAME + ',';
	qs := qs + FLD_CAA_STATUS + ' ';
	qs := qs + 'FROM '+ VIE_CAA + ' ';
	qs := qs + 'WHERE ' + FLD_CAA_STATUS + '=0';
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
			
			recId := rs.FieldByName(FLD_CAA_DETAIL_ID).AsInteger;
			fname := rs.FieldByName(FLD_CAA_FNAME).AsString;
			lname := rs.FieldByName(FLD_CAA_LNAME).AsString;
			domId := rs.FieldByName(FLD_CAA_DOM_ID).AsString;
			upnSuf := rs.FieldByName(FLD_CAA_UPN).AsString;
			ou := rs.FieldByName(FLD_CAA_OU).AsString;
			supName := rs.FieldByName(FLD_CAA_SUPP_ID).AsString;
			useSupOu := rs.FieldByName(FLD_CAA_USE_SUPP_OU).AsBoolean;
					
			WriteLn(recId,'    ',fname,'   ',lname, '   ', domId, '    ', upnSuf, '    ', ou, '   ', supName, '    ', useSupOu);
			
			userName := GenerateUserName2(supName, fname, lname);
			upn := GenerateUpn(userName, upnSuf);
			dn := GenerateDn(userName, ou, supName, useSupOu, domId);
			pw := GeneratePassword(); // From USupportLibrary
//			GenerateDn(a: string; ou: string; sup: string; useSup: boolean; d: string): string;
			
			WriteLn('User name:    ', userName);
			WriteLn('UPN:          ', upn);
			WriteLn('DN:           ', dn);
			WriteLn('Initial password: ', pw);
			WriteLn;
			
			UpdateTableAccountDetail(recId, userName, upn, dn, pw);
			
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure FindRecordToCreateNewAccounts



procedure ProgInit();
begin
	DatabaseOpen();
end;



procedure ProgRun();
var
	a: string;
begin
	//WriteLn(GenerateUserName2('NSA', 'Teresa', 'Lisbon'));
	//WriteLn(GenerateUserName2('KPN', 'Arnold', 'Van den Schwarzennegger'));
	//WriteLn(GenerateUserName2('KPN', 'Arnold', 'Schwarzennegger'));
	a := GenerateUserName2('HP', 'Piet', 'van de Regger');
	//WriteLn(GenerateUserName2('CSC', 'Rudolf', 'van Veen'));
	//WriteLn(GenerateUserName2('NSA', 'Richard', 'van ''t Haar'));
	//WriteLn(GenerateUserName2('NSA', '', 'Cher'));
	//WriteLn(GenerateUserName2('NSA', 'Margret', 'Van den Boo-Van Assel')); // > Should become Margret.vdBoovAssel
	
	
	Writeln(GenerateUpn(a, 'prod.ns.nl'));
	WriteLn(GenerateDn(a, 'OU=Beheer', 'HP', true, 'DC=prod,DC=ns,DC=nl'));
	WriteLn(GenerateDn(a, 'OU=Beheer', 'KPN', false, 'DC=rs,DC=root,DC=nedtrain,DC=nl'));

	 
	FindRecordToCompleteMissingField();
end;



procedure ProgDone();
begin
	DatabaseClose();
end;

	
	
begin
	ProgInit();
	ProgRun();
	ProgDone();
end.

// end of program
