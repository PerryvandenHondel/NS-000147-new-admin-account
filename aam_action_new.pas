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




unit aam_action_new;


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


implementation


const
	VTBL_NEW = 					'account_action_view_new';
	VFLD_NEW_ID = 				'anw_id';
	VFLD_NEW_IS_ACTIVE = 		'anw_is_active';
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
	VFLD_NEW_UPN = 				'anw_upn';
	VFLD_NEW_PW =		 		'anw_password';
	VFLD_NEW_STATUS = 			'anw_status';
	VFLD_NEW_RCD = 				'anw_rcd';
	VFLD_NEW_RLU = 				'anw_rlu';

type
	TMiddleNameRec = record
		find: string;
		repl: string;
	end;
	

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
begin
	GenerateUpn := strAccountName + '@'+ strDomainName;
end; // of function GenerateUpn
	

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
	

procedure DoActionNew(curAction: integer);
//
//		curAction		What is the current action (2 for password reset)
//
var
	qs: Ansistring;
	rs: TSQLQuery;
	recId: integer;
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
begin
	WriteLn('-----------------------------------------------------------------');
	WriteLn('DOACTIONNEW()');
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + VTBL_NEW + ' ';
	qs := qs + 'WHERE ' + VFLD_NEW_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + VFLD_NEW_STATUS + '=0 ' ;
	qs := qs + 'ORDER BY ' + VFLD_NEW_RCD;
	qs := qs + ';';
	
	WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('DOACTIONNEW(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			recId := rs.FieldByName(VFLD_NEW_ID).AsInteger;
			WriteLn(recId:4);
			
			fname := rs.FieldByName(VFLD_NEW_FNAME).AsString;
			mname := rs.FieldByName(VFLD_NEW_MNAME).AsString;
			lname := rs.FieldByName(VFLD_NEW_LNAME).AsString;
			rootDse := rs.FieldByName(VFLD_NEW_ROOTDSE).AsString;
			upnSuff := rs.FieldByName(VFLD_NEW_UPN_SUFF).AsString;
			orgUnit := rs.FieldByName(VFLD_NEW_ORGUNIT).AsString;
			useSuppOu := rs.FieldByName(VFLD_NEW_USE_SUPP_OU).AsInteger;
			supName := rs.FieldByName(VFLD_NEW_SUPP_CODE).AsString;
			
			userName := GenerateUserName3(supName, fname, mname, lname);
			upn := GenerateUpn(userName, upnSuff);
			dn := GenerateDn(userName, orgUnit, supName, useSuppOu, rootDse);
			pw := GeneratePassword(); // From USupportLibrary
//			GenerateDn(a: string; ou: string; sup: string; useSup: boolean; d: string): string;
			
			WriteLn('User name:        ', userName);
			WriteLn('UPN:              ', upn);
			WriteLn('DN:               ', dn);
			WriteLn('Initial password: ', pw);
			WriteLn;
			
			//dn := rs.FieldByName(VIEW_RESET_DN).AsString;
			//upn := rs.FieldByName(VIEW_RESET_UPN).AsString;
			//initialPassword := rs.FieldByName(VIEW_RESET_INITPW).AsString;
			
			
			
			rs.Next;
		end;
	end;
	rs.Free;
	
end; // of procedure DoActionNew


end. // of unit aam_action_new