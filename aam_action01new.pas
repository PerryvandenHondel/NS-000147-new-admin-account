//
//	Admin Account Management -- New account
//
//		
//		function GenerateUpn
//		procedure DoActionNew
//		function ReplaceMiddleNames
//		function GenerateUserName3
//
//	FLOW:
//		DoActionNew
//


unit aam_action01new;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	SysUtils,
	Process,
	USupportLibrary,
	ODBCConn,
	SqlDb,
	aam_global;
	

procedure DoActionNew(curAction: integer);			// Add new actions to the table AAD for password resets
function DoesAccountExist(dn: string): boolean;
procedure TableAadCheckNew(actionSha1: string; recId: integer);

implementation


const
	VTBL_NEW = 					'account_action_view_new';
	VFLD_NEW_ID = 				'anw_id';
	VFLD_NEW_IS_ACTIVE = 		'anw_is_active';
	VFLD_NEW_ACTION_SHA1 = 		'anw_action_sha1';
	VFLD_NEW_APS_ID = 			'anw_person_aps_id';
	VFLD_NEW_FNAME = 			'aps_fname';
	VFLD_NEW_MNAME = 			'aps_mname';
	VFLD_NEW_LNAME = 			'aps_lname';
	VFLD_NEW_ROOTDSE = 			'adm_root_dse';
	VFLD_NEW_UPN_SUFF = 		'adm_upn_suffix';
	VFLD_NEW_ORGUNIT = 			'adm_org_unit';
	VFLD_NEW_USE_SUPP_OU = 		'adm_use_supplier_ou';
	VFLD_NEW_SUPP_CODE =		'asr_code3';
	VFLD_NEW_REF = 				'anw_reference';
	VFLD_NEW_USERNAME = 		'anw_username';
	VFLD_NEW_DN = 				'anw_dn';
	VFLD_NEW_DOMAIN_ID = 		'anw_domain_adm_id';
	VFLD_NEW_UPN = 				'anw_upn';
	VFLD_NEW_PW =		 		'anw_password';
	VFLD_NEW_MOBILE = 			'aps_mobile';
	VFLD_NEW_EMAIL = 			'aps_email';
	VFLD_NEW_TITLE = 			'ati_title';
	VFLD_NEW_REQ_FNAME = 		'vnew_requestor_fname';
	VFLD_NEW_REQ_EMAIL = 		'vnew_requestor_email';
	VFLD_NEW_REQ_MAIL_TO = 		'vnew_requestor_mail_to';
	VFLD_NEW_STATUS = 			'anw_status';
	VFLD_NEW_RCD = 				'anw_rcd';
	VFLD_NEW_RLU = 				'anw_rlu';

	TBL_DGR = 					'account_default_group_dgr';
	FLD_DGR_ID = 				'dgr_id';
	FLD_DGR_IS_ACTIVE =			'dgr_is_active';
	FLD_DGR_ADM_ID = 			'dgr_adm_id';
	FLD_DGR_GROUP_DN = 			'dgr_group_dn';
	FLD_DGR_RCD = 				'dgr_rcd';
	FLD_DGR_RLU = 				'dgr_rlu';
	
	
type
	TMiddleNameRec = record
		find: string;
		repl: string;
	end;
	
	
function DoesAccountExist(dn: string): boolean;
//
//	Check if an account exists
//
//		dn:			Format: CN=fname.lname,OU=somewhere,DC=domain,DC=ext
//
//		true:		Account is locked in the AD
//		false:		Account is not locked in the AD
//
var
	path: string;
	p: TProcess;
	f: TextFile;
	line: string;	// Read a line from the nslookup.tmp file.
	r: boolean;		// Result of the function to return.
begin
	r := false;

	// Get a temp file to store the output of the adfind.exe command.
	path := SysUtils.GetTempFileName(); // Path is C:\Users\<username>\AppData\Local\Temp\TMP00000.tmp
	
	p := TProcess.Create(nil);
	p.Executable := 'cmd.exe'; 
    p.Parameters.Add('/c adfind.exe -b "' + dn + '" -c >' + path);
	p.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
	p.Execute;
	
	Assign(f, path);
	
	{I+}
	Reset(f);
	repeat
		ReadLn(f, line);
		if Pos('1 Objects returned', line) > 0 then
			r := true; // The account exists in the AD.
	until Eof(f);
	Close(f);
	
	SysUtils.DeleteFile(path);
	
	DoesAccountExist := r;
end; // of function DoesAccountExist


procedure UpdateAnw(recId: integer; userName: string; upn: string; dn: string; pw: string);
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + VTBL_NEW;
	qu := qu + ' SET';
	qu := qu + ' ' + VFLD_NEW_USERNAME+ '=' + EncloseSingleQuote(userName);
	qu := qu + ',' + VFLD_NEW_DN + '=' + EncloseSingleQuote(dn);
	qu := qu + ',' + VFLD_NEW_UPN + '=' + EncloseSingleQuote(upn);
	qu := qu + ',' + VFLD_NEW_PW + '=' + EncloseSingleQuote(pw);
	qu := qu + ' WHERE ' + VFLD_NEW_ID + '=' + IntToStr(recId);
	qu := qu + ';';
	WriteLn(qu);
	RunQuery(qu);
end; // of procedure UpdateAnw
	
	
function GenerateDn(a: string; ou: string; sup: string; useSupplierOu: integer; d: string): string;
//
//	Generate the Distinguished Name (DN) of a account.
//
//	a			Account
//	ou 			Organizational Unit
//	sup			Supplier code
//	useSup		Boolean to use the supplier code
//	d 			Domain RootDSE
var 
	r: string;
begin
	if useSupplierOu = 1 then
		r := 'CN=' + a + ',OU=' + sup + ',' + ou + ',' + d
	else
		r := 'CN=' + a + ',' + ou + ',' + d;
	
	GenerateDn := r;
end; // of function GenerateDn
	
	
function GenerateUpn(strAccountName: string; strDomainName: string): string;
//
// Generate a valid UPN (User Principal Name): fname.lname@domain.ext 
//
begin
	GenerateUpn := strAccountName + '@' + strDomainName;
end; // of function GenerateUpn
	

function ReplaceMiddleNames(s: string): string;
//
// Replace all occurances of MiddleNameArray.Find for MiddleNameArray.Repl.
//
var
	MiddleNameArray: Array[1..7] of TMiddleNameRec;
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
	
	MiddleNameArray[7].find := 'op '; 
	MiddleNameArray[7].repl := 'o';
	
	
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
	GenerateUserName3 := '';
	
	// Remove any spaces in the first name.
	fn := StringReplace(fn, ' ', '', [rfReplaceAll, rfIgnoreCase]);
	
	if Length(mn) > 0 then
	begin
		// Add a space to the middle name.
		mn := ReplaceMiddleNames(mn);
	end; // of if
	
	ln := ReplaceMiddleNames(ln);
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


procedure TableAnwSetStatus(recId: integer; newStatus: integer);
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + VTBL_NEW;
	qu := qu + ' SET';
	qu := qu + ' ' + VFLD_NEW_STATUS + '=' + IntToStr(newStatus);
	qu := qu + ' WHERE ' + VFLD_NEW_ID + '=' + IntToStr(recId);
	qu := qu + ';';
	WriteLn('TableAnwSetStatus(): ', qu);
	RunQuery(qu);
end; // of procedure TableAnwSetStatus


procedure ActionNewSendmail(recId: integer; curAction: integer; reqFname: string; reqEmail: string; upn: string; pw: string; ref: string);
//procedure ActionNewSendmail(recId: integer; curAction: integer; fname: string; upn: string; initpw: string; mailto: string; ref: string);
var
	fileBody: string;
	traceCode: string; // Unique code for this action PRODID+ACTION+REC (147-2-15)
	f: TextFile;
	//cmd: Ansistring;
	subject: Ansistring;
	fileAttach: string;
	samAccountName: Ansistring;
begin
	// Build the path of the e-mail contents file.
	traceCode := IntToStr(PROG_ID) + '-' + IntToStr(curAction) + '-' + IntToStr(recId);
	
	fileBody := 'body.txt';
	fileAttach := 'bareadme.txt';
	
	samAccountName := LeftStr(upn, Pos('@', upn) - 1);
	samAccountName := LeftStr(samAccountName, 20);
	
	if FileExists(fileBody) = true then
		DeleteFile(fileBody);
	
	Assign(f, fileBody);
	ReWrite(f);
	
	WriteLn(f, 'Hello ', reqFname, ',');
	WriteLn(f);
	WriteLn(f, 'New administrative account is created');
	WriteLn(f);
	WriteLn(f, 'UPN format:       ', upn);
	WriteLn(f, 'NetBIOS format:   ', samAccountName);
	WriteLn(f);
	WriteLn(f, 'Initial password:       ' + pw);
	WriteLn(f);
	WriteLn(f, 'Requested under:        ', ref);
	WriteLn(f);
	WriteLn(f, 'Trace code:             ', traceCode);
	WriteLn(f);
	WriteLn(f, 'IMPORTANT: SEND ATTACHMENT ' + UpperCase(fileAttach) + ' TO THE USER OF THIS NEW ACCOUNT!!');
	WriteLn(f);
	
	Close(f);
	
	
	subject := 'New administrative account is created for ' + upn + ' #' + ref + ' #' + traceCode;
	
	// Send the fileBody using the mailer procedure.
	SendMail(reqEmail, MAIL_FROM, fileBody, fileAttach, subject);
	{
	cmd := ' blat.exe ' + path;
	cmd := cmd + ' -to ' + EncloseDoubleQuote(reqEmail);
	cmd := cmd + ' -f ' + EncloseDoubleQuote(MAIL_FROM);
	cmd := cmd + ' -bcc ' + EncloseDoubleQuote(MAIL_BCC);
	if FileExists(fileAccountInfo) = true then
		cmd := cmd + ' -attacht ' + EncloseDoubleQuote(fileAccountInfo);
	cmd := cmd + ' -subject ' + EncloseDoubleQuote('New account is created for ' + upn + ' #' + ref + ' #' + traceCode);
	cmd := cmd + ' -server vm70as005.rec.nsint';
	cmd := cmd + ' -port 25';

	RunCommand(cmd);
	}
	// Update the status to 900: Send e-mail
	TableAnwSetStatus(recId, 900);
	
	// Delete the body file of the e-mail.
	DeleteFile(fileBody);
end; // of procedure ActionResetSendmail


procedure TableAadCheckNew(actionSha1: string; recId: integer);	
var
	qs: Ansistring;
	rs: TSQLQuery;
	errorLevel: integer;
	allSuccesFull: boolean;
	cmd: Ansistring;
begin
	qs := 'SELECT ' + FLD_AAD_EL + ',' + FLD_AAD_CMD;
	qs := qs + ' FROM ' + TBL_AAD;
	qs := qs + ' WHERE ' + FLD_AAD_ACTION_SHA1 + '=' + EncloseSingleQuote(actionSha1);
	qs := qs + ';';
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	allSuccesFull := true;
	
	if rs.EOF = true then
		WriteLn('TableAadCheckNew(): No records found with ActionSha1: ', actionSha1)
	else
	begin
		WriteLn('TableAadCheckNew(): Checking all action for ActionSha1: ', actionSha1);
		while not rs.EOF do
		begin
			errorLevel := rs.FieldByName(FLD_AAD_EL).AsInteger;
			cmd := rs.FieldByName(FLD_AAD_CMD).AsString;
			WriteLn('  ', cmd, ' >>ERRORLEVEL=', errorLevel);
			if errorLevel <> 0 then
			begin
				WriteLn('    ***FAILED***');
				allSuccesFull := false; // Not all steps where successful
			end;
			rs.Next;
		end;
	end;
	rs.Free;
	
	WriteLn('TableAadCheckNew() allSuccessFull=', allSuccesFull);
	
	if allSuccesFull = false then
		TableAnwSetStatus(recId, 99) // failure during execution of command lines
	else
		TableAnwSetStatus(recId, 100); // All error levels are 0, success.
end; // of procedure ActionResetCheck


procedure TableAtvAdd(apsId: integer; fname: string; mname: string; lname: string; userName: string; upn: string; dn: string);
//
//	Add a new record to the table ATV (Active Accounts)
//
//		apsId:		Record number of the person
//		fname:		First name of the account
//		mname:		Middle name of the account
//		lname:		Last name of the account
//		userName:	User name of the account
//		upn:		User Principal Name if the account
//		dn:			Distinguished Name of the account
//
var
	sort: string;
	qi: string;
begin
	WriteLn('TableAtvAdd(): Add a newly created account to ' + TBL_ATV);
	
	sort := lname + ', ' + fname;
	if Length(mname) > 0 then
		sort := sort + ' ' + mname; // If there is a middle name, add it.
	
	sort := sort + ' (' + upn + ')';
	
	qi := 'INSERT INTO ' + TBL_ATV + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_ATV_APS_ID + '=' + IntToStr(apsId) + ',';
	qi := qi + FLD_ATV_IS_ACTIVE + '=1,';
	qi := qi + FLD_ATV_SORT + '=' + FixStr(sort) + ',';
	qi := qi + FLD_ATV_UPN + '=' + FixStr(upn) + ',';
	qi := qi + FLD_ATV_SAM + '=' + FixStr(userName) + ',';
	qi := qi + FLD_ATV_DN + '=' + FixStr(dn) + ';';
	RunQuery(qi);
end; // procedure TableAtvAdd


procedure AddDefaultDomainGroups(recId: integer; domainId: integer; accountDn: string; curAction: integer; actionSha1: string);
//
//	Add the default groups to the account.
//
var
	qs: string;
	rs: TSQLQuery;
	groupDn: string;
	c: Ansistring;
begin
	qs := 'SELECT ' + FLD_DGR_GROUP_DN + ' ';
	qs := qs + 'FROM ' + TBL_DGR + ' ';
	qs := qs + 'WHERE ' + FLD_DGR_IS_ACTIVE + '=1 ';
	qs := qs + 'AND ' + FLD_DGR_ADM_ID + '=' + IntToStr(domainId) + ' ';
	qs := qs + 'ORDER BY ' + FLD_DGR_GROUP_DN;
	qs := qs + ';';
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('AddDefaultDomainGroups(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			groupDn := rs.FieldByName(FLD_DGR_GROUP_DN).AsString;
			c := 'dsmod.exe group ' + EncloseDoubleQuote(groupDn)+ ' -addmbr ' + EncloseDoubleQuote(accountDn);
			AddRecordToTableAad(actionSha1, c);
			rs.Next;
		end;
	end;
	rs.Free;
end;


procedure DoActionNew(curAction: integer);
//
//		curAction		What is the current action (1 = new account)
//
var
	qs: Ansistring;
	rs: TSQLQuery;
	recId: integer;
	recApsId: integer;
	fname: string;
	mname: string;
	lname: string;
	rootDse: string;
	upnSuff: string;
	orgUnit: string;
	useSuppOu: integer;
	userName: string;
	supName: string;
	upn: string;
	dn: string;
	pw: string;
	mobile: string;
	email: string;
	company: string;
	title: string;
	c: Ansistring;
	reqFname: string;
	//reqEmail: string;
	reqMailTo: string;
	ref: string;
	domainId: integer;
	actionSha1: string;
begin
	WriteLn('-----------------------------------------------------------------');
	WriteLn('DOACTIONNEW(', curAction, ')');
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + VTBL_NEW + ' ';
	qs := qs + 'WHERE ' + VFLD_NEW_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + VFLD_NEW_STATUS + '=0 ' ;
	qs := qs + 'ORDER BY ' + VFLD_NEW_RCD;
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
			recId := rs.FieldByName(VFLD_NEW_ID).AsInteger;
			recApsId := rs.FieldByName(VFLD_NEW_APS_ID).AsInteger; // Record APS_ID. Unique ID of person
			
			fname := rs.FieldByName(VFLD_NEW_FNAME).AsString;
			mname := rs.FieldByName(VFLD_NEW_MNAME).AsString;
			lname := rs.FieldByName(VFLD_NEW_LNAME).AsString;
			rootDse := rs.FieldByName(VFLD_NEW_ROOTDSE).AsString;
			upnSuff := rs.FieldByName(VFLD_NEW_UPN_SUFF).AsString;
			orgUnit := rs.FieldByName(VFLD_NEW_ORGUNIT).AsString;
			useSuppOu := rs.FieldByName(VFLD_NEW_USE_SUPP_OU).AsInteger;
			supName := rs.FieldByName(VFLD_NEW_SUPP_CODE).AsString;
			mobile := rs.FieldByName(VFLD_NEW_MOBILE).AsString;
			email := rs.FieldByName(VFLD_NEW_EMAIL).AsString;
			company := rs.FieldByName(VFLD_NEW_SUPP_CODE).AsString;
			title := rs.FieldByName(VFLD_NEW_TITLE).AsString;
			reqFname := rs.FieldByName(VFLD_NEW_REQ_FNAME).AsString;
			reqMailTo := rs.FieldByName(VFLD_NEW_REQ_MAIL_TO).AsString;		// Send mail to this requestor e-mail addres(ses)
			ref := rs.FieldByName(VFLD_NEW_REF).AsString;
			domainId := rs.FieldByName(VFLD_NEW_DOMAIN_ID).AsInteger;
			
			// Generate the following fields.
			userName := GenerateUserName3(supName, fname, mname, lname);
			upn := GenerateUpn(userName, upnSuff);
			dn := GenerateDn(userName, orgUnit, supName, useSuppOu, rootDse);
			pw := GeneratePassword(); // From USupportLibrary
			
			WriteLn('DN:               ', dn);
			
			if DoesAccountExist(dn) = false then
			begin
				// Account DN does not exist, continue...
				actionSha1 := GenerateUniqueActionNumber(curAction);
				
				WriteLn('User name:        ', userName);
				WriteLn('UPN:              ', upn);
				WriteLn('Initial password: ', pw);
				WriteLn('Action SHA:       ', actionSha1);
				WriteLn;
				
				UpdateOneFieldString(VTBL_NEW, VFLD_NEW_ID, recId, VFLD_NEW_ACTION_SHA1, actionSha1);
							
				UpdateAnw(recId, userName, upn, dn, pw);
						
				// Add the account
				c := 'dsadd.exe user ' + EncloseDoubleQuote(dn);
				AddRecordToTableAad(actionSha1, c);
			
				// Set the UPN
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -upn ' + EncloseDoubleQuote(upn);
				AddRecordToTableAad(actionSha1, c);
				
				// Add first name AD attribute
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -fn ' + EncloseDoubleQuote(Trim(fname + ' ' + mname));
				AddRecordToTableAad(actionSha1, c);
				
				// Add last name AD attribute
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -ln ' + EncloseDoubleQuote(Trim(lname));
				AddRecordToTableAad(actionSha1, c);
				
				// Add title AD attribute
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -title ' + EncloseDoubleQuote(Trim(title));
				AddRecordToTableAad(actionSha1, c);
				
				// Add display AD attribute
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -display ' + EncloseDoubleQuote(Trim(userName));
				AddRecordToTableAad(actionSha1, c);
				
				// Add the mobile number if it exists
				if Length(mobile) > 0 then
				begin
					// Add mobile AD attribute if exists in the database.
					c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -mobile ' + EncloseDoubleQuote(Trim(mobile));
					AddRecordToTableAad(actionSha1, c);
				end; // of if
			
				// Add compnay AD attribute
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -company ' + EncloseDoubleQuote(Trim(company));
				AddRecordToTableAad(actionSha1, c);
				
				// Add the email address when it exists.
				if Length(email) > 0 then
				begin
					// Add mobile AD attribute if exists in the database.
					c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -email ' + EncloseDoubleQuote(Trim(email));
					AddRecordToTableAad(actionSha1, c);
				end; // of if
			
				// Set the initial password
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' ';
				c := c + '-pwd ' + EncloseDoubleQuote(pw) + ' ';
				c := c + '-mustchpwd yes';
				AddRecordToTableAad(actionSha1, c);
								
				// Set the not delegated flag in the UserAccountControl attribute of the account
				// NOT_DELEGATED - When this flag is set, the security context of the user is not delegated to a service even if the service account is set as trusted for Kerberos delegation.
				//	Source: https://support.microsoft.com/en-us/kb/305144
				c := 'adfind.exe -b ' + EncloseDoubleQuote(dn) + ' userAccountControl -adcsv | admod.exe "userAccountControl::{{.:SET:1048576}}"';
				AddRecordToTableAad(actionSha1, c);
				
				// dsmod user <user's distinguished name (DN)> -disabled no
				// Enable the account.
				c := 'dsmod.exe user ' + EncloseDoubleQuote(dn) + ' -disabled no';
				AddRecordToTableAad(actionSha1, c);
				
				AddDefaultDomainGroups(recId, domainId, dn, curAction, actionSha1);
				
				// Account records created in table AAD, status = 100, continue with processing.
				TableAnwSetStatus(recId, 100);
				
				// Process all the records in the table AAD
				//TableAadProcessNew(actionSha1);
				TableAadProcessActions(actionSha1);
				
				// Check all actions for the new account creation
				TableAadCheckNew(actionSha1, recId);
				
				// procedure ActionNewSendmail(recId: integer; curAction: integer; fname: string; upn: string; initpw: string; mailto: string; ref: string);
				ActionNewSendmail(recId, curAction, reqFname, reqMailTo, upn, pw, ref);
				
				// Add the new account to the table account_active_atv
				TableAtvAdd(recApsId, fname, mname, lname, userName, upn, dn);
			end // of if 
			else
			begin
				WriteLn('================================================================================');
				WriteLn('DoActionNew() WARNING: DN ', dn, ' does already exists!!');
				WriteLn('=================================================================================');
				TableAnwSetStatus(recId, 98); // Set status to 99 for existing record
			end;
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure DoActionNew


end. // of unit aam_action_new