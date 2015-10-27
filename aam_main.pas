{
	
	Admin Account Management (AAM)
	
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


program AdminAccountManagement;


{$MODE OBJFPC}			
{$LONGSTRINGS ON}		// Compile all strings as Ansistrings


uses
	Crt,
	Classes, 
	DateUtils,						// For SecondsBetween
	Process, 
	SysUtils,
	USupportLibrary,
	SqlDB,
	aam_global,
	aam_database,
	aam_action_reset;			// ACTION 2
	
	
const
	STEP_MOD = 					27;
	MAX_USER_NAME_LENGTH = 		20;


	
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


procedure RunQuery(qs: Ansistring);
//
//	Run a query
//
var
	q: TSQLQuery;
	t: TSQLTransaction;
begin
	t := TSQLTransaction.Create(gConnection);
	t.Database := gConnection;
	q := TSQLQuery.Create(gConnection);
	q.Database := gConnection;
	q.Transaction := t;
	q.SQL.Text := qs;
	q.ExecSQL;
	t.Commit;
end; // of procedure RunQuery


function ReplaceMiddleNames(s: string): string;
//
// Replace all occurances of MiddleNameArray.Find for MiddleNameArray.Repl.
//
var
	MiddleNameArray: Array[1..6] of TMiddleNameRec;
	i: integer;	
	sBuff: string;
begin
	// Assign the input string to sBuff.
	sBuff := s + ' '; // Add a space to the end. Searching for middle name with a space.
	
	// Assign all middle name variations with the replacement to the array.
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
		sBuff := StringReplace(sBuff, MiddleNameArray[i].find, MiddleNameArray[i].repl, [rfReplaceAll, rfIgnoreCase]);
	end; // of for
	ReplaceMiddleNames := sBuff;
end; // of function ReplaceMiddleNames


function GenerateUserName3(strSupplier: string; fn: string; mn: string; ln: string): string;
var
	r: string;		// Return value of this function.
begin
	WriteLn('GenerateUserName3(): ' + strSupplier + '/' + fn + ' ' + mn + ' ' + ln);
	
	//strLnameBuffer := strLname;
	
	GenerateUserName3 := '';
	
	
	if Length(mn) > 0 then
	begin
		// Add a space to the middle name.
		mn := ReplaceMiddleNames(mn);
	end; // of if
	
	ln := ReplaceMiddleNames(ln);
	
	WriteLn(mn);
	WriteLn(ln);
	
	
	if Length(fn) = 0 then
		// If there is no first name, like Cher or Madonna.
		r := strSupplier + '_' + ln
	else
	begin
		if Length(mn) > 0 then
			r := strSupplier + '_' + fn + '.' + mn + ln
		else
			r:= strSupplier + '_' + fn + '.' + ln;
	end; // of if
	
	// Return the value, trim all spaces around the string.
	GenerateUserName3 := Trim(r);
end; // of function GenerateUserName3


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


procedure TableAccountDetailUpdateStatus(intRecordId: integer; intNewStatus: integer);
//
//	Update the table account_detail.
//	Set a new status in status using intNewStatus.
//
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + TBL_ADT + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_ADT_STATUS + '=' + IntToStr(intNewStatus) + ' ';
	qu := qu + 'WHERE ' + FLD_ADT_ID + '=' + IntToStr(intRecordId) + ';';
	RunQuery(qu);
end; // of TableAccountDetailUpdateStatus


function TableAccountActionInsert(desc: string): string;
//
//	Insert a record in the table ACT
//
//	Returns the Unique Action ID of this insert. For linking to the AAD table.
//
var
	r: string;
	qi: Ansistring;
begin
	r := GetRandomString(16);
	WriteLn('TableAccountActionInsert: ' + desc);
	WriteLn(' -- Unique ID: ' + r);
	qi := 'INSERT INTO ' + TBL_ACT + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_ACT_ID + '=' + FixStr(r) + ',';
	qi := qi + FLD_ACT_DESC + '=' + FixStr(desc) + ';';
	RunQuery(qi);
	TableAccountActionInsert := r;
end; // of function TableAccountActionInsert
	

procedure TableAccountActionDetailInsert(actionId: string; c: string);
//
//	Insert a record in the table AAD
//
var
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_AAD + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_AAD_ACT_ID + '=' + FixStr(actionId) + ',';
	qi := qi + FLD_AAD_CMD + '=' + FixStr(c) + ';';
	RunQuery(qi);
end; // of procedure TableAccountActionDetailInsert


procedure StepFillActionTable(intStatus: integer);
var	
	actionId: string;	// Unique Action ID of char 16
	c: Ansistring;
	desc: string;
	dn: string;
	email: string;
	fname: string;
	initPw: string;
	lname: string;
	mname: string;
	mobile: string;
	qs: Ansistring;
	recId: integer;
	rs: TSQLQuery;
	title: string;
	upn: string;
	userName: string;
begin
	WriteLn('StepFillActionTable(): ', intStatus);
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + VIE_CAA + ' ';
	qs := qs + 'WHERE ' + FLD_CAA_STATUS + '=' + IntToStr(intStatus);
	qs := qs + ';';
	
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
			//WriteLn(rs.FieldByName(FLD_CAA_DN).AsString);
			recId :=  rs.FieldByName(FLD_CAA_DETAIL_ID).AsInteger;
			upn := rs.FieldByName(FLD_CAA_UPN).AsString;
			dn := rs.FieldByName(FLD_CAA_DN).AsString;
			initPw := rs.FieldByName(FLD_CAA_INIT_PW).AsString;
			userName := rs.FieldByName(FLD_CAA_USER_NAME).AsString;
			fname := rs.FieldByName(FLD_CAA_FNAME).AsString;
			mname := rs.FieldByName(FLD_CAA_MNAME).AsString;
			lname := rs.FieldByName(FLD_CAA_LNAME).AsString;
			title := rs.FieldByName(FLD_CAA_TITLE).AsString;
			mobile := rs.FieldByName(FLD_CAA_MOBILE).AsString;
			email := rs.FieldByName(FLD_CAA_EMAIL).AsString;
			
			desc := 'Create new account for ' + upn;
			actionId  := TableAccountActionInsert(desc);
			
			// Create the account using DSADD.EXE
			c := 'dsadd.exe user ';
			c := c + EncloseDoubleQuote(dn);
			//WriteLn(c);
			TableAccountActionDetailInsert(actionId, c);
			
			// Add a UPN to the account
			c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' ';
			c := c + '-upn ' + EncloseDoubleQuote(upn);
			//WriteLn(c);
			TableAccountActionDetailInsert(actionId, c);
			
			// Set the initial password on the account
			c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' ';
			c := c + '-pwd ' + EncloseDoubleQuote(initPw) + ' ';
			c := c + '-mustchpwd yes';
			//WriteLn(c);
			TableAccountActionDetailInsert(actionId, c);

			// Add first name AD attribute
			c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -fn ' + EncloseDoubleQuote(Trim(fname + ' ' + mname));
			TableAccountActionDetailInsert(actionId, c);
			
			// Add last name AD attribute
			c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -ln ' + EncloseDoubleQuote(Trim(lname));
			TableAccountActionDetailInsert(actionId, c);
			
			// Add title AD attribute
			c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -title ' + EncloseDoubleQuote(Trim(title));
			TableAccountActionDetailInsert(actionId, c);
			
			// Add display AD attribute
			c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -display ' + EncloseDoubleQuote(Trim(userName));
			TableAccountActionDetailInsert(actionId, c);
			
			if Length(mobile) > 0 then
			begin
				// Add mobile AD attribute if exists in the database.
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -mobile ' + EncloseDoubleQuote(Trim(mobile));
				TableAccountActionDetailInsert(actionId, c);
			end; // of if
			
			if Length(email) > 0 then
			begin
				// Add mobile AD attribute if exists in the database.
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -email ' + EncloseDoubleQuote(Trim(email));
				TableAccountActionDetailInsert(actionId, c);
			end; // of if
			
			
			// Set the not delegated flag in the UserAccountControl attribute of the account
			// NOT_DELEGATED - When this flag is set, the security context of the user is not delegated to a service even if the service account is set as trusted for Kerberos delegation.
			//	Source: https://support.microsoft.com/en-us/kb/305144
			c := 'adfind.exe -b ' + EncloseDoubleQuote(dn) + ' userAccountControl -adcsv | admod.exe "userAccountControl::{{.:SET:1048576}}"';
			TableAccountActionDetailInsert(actionId, c);
			
			// Change the status to 300. Records added
			TableAccountDetailUpdateStatus(recId, 300);
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure StepFillActionTable


procedure StepCheckForExisting(intStatus: integer);
//
//	Step Check for Existing accounts.
//
var	
	qs: Ansistring;
	rs: TSQLQuery;							// Uses SqlDB
	recId: integer;
	dn: string;
	c: string;
	e: integer;
	
begin
	WriteLn('StepCheckForExisting()----------------');
	qs := 'SELECT '+ FLD_ADT_ID + ',' + FLD_ADT_DN + ' ';
	qs := qs + 'FROM ' + TBL_ADT + ' ';
	qs := qs + 'WHERE ' + FLD_ADT_STATUS + '=' + IntToStr(intStatus);
	
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
			recId := rs.FieldByName(FLD_ADT_ID).AsInteger;
			dn := rs.FieldByName(FLD_ADT_DN).AsString;
			
			WriteLn('Checking DN ' + dn + ' exists...');
			c := 'dsquery.exe user "' + dn + '"';
			WriteLn('COMMAND LINE: ' + c);
			e := RunCommand(c);
			WriteLn('ERRORLEVEL=', e);
			
			//e = 0 			Account is found.
			//e = -2147016656	Account not found, create it.
				
			case e of
				0: 
					TableAccountDetailUpdateStatus(recId, 199); // Account exists already
				-2147016656: 
					TableAccountDetailUpdateStatus(recId, 200); // Account does not exists, next step 200
			else
				TableAccountDetailUpdateStatus(recId, 198); // Unknown response.
			end; // of case.
			rs.Next;
		end;
	end;
	rs.Free;
end;


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
	//t: TSQLTransaction;
	//q: TSQLQuery;
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
		
	RunQuery(qu);
	
	//t := TSQLTransaction.Create(gConnection);
	//t.Database := gConnection;
	//q := TSQLQuery.Create(gConnection);
	//q.Database := gConnection;
	//q.Transaction := t;
	//q.SQL.Text := qu;
	//q.ExecSQL;
	//t.Commit;
end; // of procedure UpdateTableAccountDetail


procedure StepCompleteMissingField(intStatus: integer);
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
	mname: string;
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
	WriteLn('FindRecordToCompleteMissingField()--------------------');

	qs := 'SELECT ';
	qs := qs + FLD_CAA_DETAIL_ID + ',';
	qs := qs + FLD_CAA_ACCOUNT_ID + ',';
	qs := qs + FLD_CAA_FNAME + ',';
	qs := qs + FLD_CAA_MNAME + ',';
	qs := qs + FLD_CAA_LNAME + ',';
	qs := qs + FLD_CAA_DOM_ID + ',';
	//qs := qs + FLD_CAA_UPN + ',';
	qs := qs + FLD_CAA_UPN_SUFF + ',';
	qs := qs + FLD_CAA_NT + ',';
	qs := qs + FLD_CAA_OU + ',';
	qs := qs + FLD_CAA_USE_SUPP_OU + ',';
	qs := qs + FLD_CAA_SUPP_ID + ',';
	qs := qs + FLD_CAA_SUPP_NAME + ',';
	qs := qs + FLD_CAA_STATUS + ' ';
	qs := qs + 'FROM '+ VIE_CAA + ' ';
	qs := qs + 'WHERE ' + FLD_CAA_STATUS + '=' + IntToStr(intStatus);
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
			mname := rs.FieldByName(FLD_CAA_MNAME).AsString;
			lname := rs.FieldByName(FLD_CAA_LNAME).AsString;
			domId := rs.FieldByName(FLD_CAA_DOM_ID).AsString;
			upnSuf := rs.FieldByName(FLD_CAA_UPN_SUFF).AsString;
			ou := rs.FieldByName(FLD_CAA_OU).AsString;
			supName := rs.FieldByName(FLD_CAA_SUPP_ID).AsString;
			useSupOu := rs.FieldByName(FLD_CAA_USE_SUPP_OU).AsBoolean;
					
			WriteLn(recId,'    ',fname,'   ',lname, '   ', domId, '    ', upnSuf, '    ', ou, '   ', supName, '    ', useSupOu);
			
			userName := GenerateUserName3(supName, fname, mname, lname);
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
//var
//	a: string;
begin
	//WriteLn(GenerateUserName2('NSA', 'Teresa', 'Lisbon'));
	//WriteLn(GenerateUserName2('KPN', 'Arnold', 'Van den Schwarzennegger'));
	//WriteLn(GenerateUserName2('KPN', 'Arnold', 'Schwarzennegger'));
	//a := GenerateUserName2('HP', 'Piet', 'van de Regger');
	//WriteLn(GenerateUserName2('CSC', 'Rudolf', 'van Veen'));
	//WriteLn(GenerateUserName2('NSA', 'Richard', 'van ''t Haar'));
	//WriteLn(GenerateUserName2('NSA', '', 'Cher'));
	//WriteLn(GenerateUserName2('NSA', 'Margret', 'Van den Boo-Van Assel')); // > Should become Margret.vdBoovAssel
	
	
	//Writeln(GenerateUpn(a, 'prod.ns.nl'));
	//WriteLn(GenerateDn(a, 'OU=Beheer', 'HP', true, 'DC=prod,DC=ns,DC=nl'));
	//WriteLn(GenerateDn(a, 'OU=Beheer', 'KPN', false, 'DC=rs,DC=root,DC=nedtrain,DC=nl'));

	//WriteLn(ReplaceMiddleNames('van den'));
	//WriteLn(ReplaceMiddleNames('Wachtveld-Van Bergen'));
	{
	a := GenerateUserName3('CSC', 'Rudolf', 'van', 'Veen');
	WriteLn(a);
	
	a := GenerateUserName3('CSC', '', '', 'Madonna');
	WriteLn(a);
		
	a := GenerateUserName3('CSC', 'Ruud', '', 'Madonna');
	WriteLn(a);
	
	a := GenerateUserName3('CSC', 'Martina', '', 'Berg-Van den Tol');
	WriteLn(a);
	
	a := GenerateUserName3('CSC', 'Martina', 'van ''t', 'Berg-Van den Tol');
	WriteLn(a);
	}
	
	//StepCompleteMissingField(0);		// 0 > 100
	//StepCheckForExisting(100);	 		// 100 > 199;
	//StepFillActionTable(200);			// 200 > 299
	//ProcessAllAds();
	
	DoActionReset();
	
end;


procedure ProgDone();
begin
	DatabaseClose();
end;
	
	
begin
	ProgInit();
	ProgRun();
	ProgDone();
end. // of program
