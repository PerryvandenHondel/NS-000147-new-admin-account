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


function GenerateUserName3(strSupplier: string; strFname: string; strMname: string; strLname: string): string;
begin
	WriteLn('GenerateUserName3(): ' + strSupplier + '/' + strFname + ' ' + strMname + ' ' + strLname);
	GenerateUserName3 := '';
end; // of function GenerateUserName



function GetMiddleName(strLastName: string): string;
begin
end;



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



procedure FindRecordToCompleteMissingField();
var
	qs: Ansistring;
	rs: TSQLQuery;							// Uses SqlDB
begin
	qs := 'SELECT ';
	qs := qs + FLD_CAA_DETAIL_ID;
	qs := qs + ',';
	qs := qs + FLD_CAA_ACCOUNT_ID;
	qs := qs + ',';
	qs := qs + FLD_CAA_FULLNAME;
	qs := qs + ',';
	qs := qs + FLD_CAA_FNAME;
	qs := qs + ',';
	qs := qs + FLD_CAA_MNAME;
	qs := qs + ',';
	qs := qs + FLD_CAA_LNAME;
	qs := qs + ',';
	qs := qs + FLD_CAA_LNAME;
	qs := qs + ',';
	qs := qs + FLD_CAA_UPN;
	qs := qs + ',';
	qs := qs + FLD_CAA_NT;
	qs := qs + ',';
	qs := qs + FLD_CAA_OU;
	qs := qs + ',';
	qs := qs + FLD_CAA_USE_SUPP_OU;
	qs := qs + ',';
	qs := qs + FLD_CAA_SUPP_ID;
	qs := qs + ',';
	qs := qs + FLD_CAA_SUPP_NAME;
	qs := qs + ',';
	qs := qs + FLD_CAA_STATUS;
	qs := qs + ' ';
	qs := qs + 'FROM '+ VIE_CAA;
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
			WriteLn(rs.FieldByName(FLD_CAA_DETAIL_ID).AsInteger);
			WriteLn(rs.FieldByName(FLD_CAA_FULLNAME).AsString);
			WriteLn;
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
begin
	//WriteLn(GenerateUserName2('NSA', 'Teresa', 'Lisbon'));
	//WriteLn(GenerateUserName2('KPN', 'Arnold', 'Van den Schwarzennegger'));
	//WriteLn(GenerateUserName2('KPN', 'Arnold', 'Schwarzennegger'));
	WriteLn(GenerateUserName2('HP', 'Piet', 'van de Regger'));
	//WriteLn(GenerateUserName2('CSC', 'Rudolf', 'van Veen'));
	//WriteLn(GenerateUserName2('NSA', 'Richard', 'van ''t Haar'));
	//WriteLn(GenerateUserName2('NSA', '', 'Cher'));
	//WriteLn(GenerateUserName2('NSA', 'Margret', 'Van den Boo-Van Assel')); // > Should become Margret.vdBoovAssel
	
	
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
