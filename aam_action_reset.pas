//
//	Admin Account Management -- Password reset
//


unit aam_action_reset;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	SysUtils,
	USupportLibrary,
	ODBCConn,
	SqlDb,
	aam_global;
	
	
procedure DoActionReset(curAction: integer);			// Add new actions to the table AAD for password resets


implementation

{
	//
	//	AAD = Action Account Do table
	//	Table that contain all the actions that are to be done to perform an action. 
	//
	TBL_AAD =				'account_action_do_aad';
	FLD_AAD_ID = 			'aad_id';
	FLD_AAD_IS_ACTIVE = 	'aad_is_active';
	FLD_AAD_ACTION_ID =		'aad_action_id';
	FLD_AAD_ACTION_NR = 	'aad_action_nr';
	FLD_AAD_CMD = 			'aad_command';
	FLD_AAD_EL = 			'aad_error_level';
	//FLD_AAD_STATUS = 		'aad_status';
	FLD_AAD_RCD = 			'aad_rcd';
	FLD_AAD_RLU = 			'aad_rlu';
}

{
	VIEW_RESET = 			'account_action_view_reset';
	VIEW_RESET_ID = 		'arp_id';
	VIEW_RESET_IS_ACTIVE = 	'arp_is_active';
	VIEW_RESET_ATV_ID = 	'arp_atv_id';
	VIEW_RESET_DN = 		'atv_dn';
	VIEW_RESET_UPN = 		'atv_upn'; 
	VIEW_RESET_SORT = 		'atv_sort';
	VIEW_RESET_ARQ_ID = 	'atv_arq_id';
	VIEW_RESET_MAIL_TO = 	'arq_mail_to';
	VIEW_RESET_FNAME = 		'arg_fname';
	VIEW_RESET_REFERENCE = 	'arp_reference';
	VIEW_RESET_INITPW = 	'arp_initial_password';
	VIEW_RESET_STATUS = 	'arp_status';
	VIEW_RESET_RCD = 		'arp_rcd';
} 


procedure ActionResetInformByEmail(curAction: integer; recId: integer);
var
	qs: Ansistring;
	rs: TSQLQuery;
	upn: string;
	fname: string;
	mailto: string;
	initpw: string;
begin
	qs := 'SELECT *';
	qs := qs + ' FROM ' + VIEW_RESET;
	qs := qs + ' WHERE ' + VIEW_RESET_ID + '=' + IntToStr(recId);
	qs := qs + ';';
	
	WriteLn('ActionResetInformByEmail(): ', qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('ActionResetInformByEmail(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			upn := rs.FieldByName(VIEW_RESET_UPN).AsString;
			fname := rs.FieldByName(VIEW_RESET_FNAME).AsString;
			mailto := rs.FieldByName(VIEW_RESET_MAIL_TO).AsString;
			initpw := rs.FieldByName(VIEW_RESET_INITPW).AsString;
			ref := rs.FieldByName(VIEW_RESET_REFERENCE).AsString;
			WriteLn('EMAIL CONTENTS: Beste ', fname, ', password reset for ', upn, ' is now set to: ',  initpw, ' (mailto: ', mailto, ')');
			
			
			
			
			
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure ActionResetInformByEmail


procedure TableArpSetStatus(recId: integer; newStatus: integer);
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + VIEW_RESET;
	qu := qu + ' SET';
	qu := qu + ' ' + VIEW_RESET_STATUS + '=' + IntToStr(newStatus);
	qu := qu + ' WHERE ' + VIEW_RESET_ID + '=' + IntToStr(recId);
	qu := qu + ';';
	
	WriteLn('TableArpSetStatus(): ', qu);
	
	RunQuery(qu);
end; // of procedure TableArpSetStatus

procedure ActionResetCheck(curAction: integer; recId: integer);	
var
	qs: Ansistring;
	rs: TSQLQuery;
	errorLevel: integer;
	allSuccesFull: boolean;
begin
	qs := 'SELECT ' + FLD_AAD_EL;
	qs := qs + ' FROM ' + TBL_AAD;
	qs := qs + ' WHERE ' + FLD_AAD_ACTION_NR + '=' + IntToStr(curAction);
	qs := qs + ' AND ' + FLD_AAD_ACTION_ID + '=' + IntToStr(recId);
	qs := qs + ';';
	
	WriteLn('ActionResetCheck(): ', qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	allSuccesFull := true;
	
	if rs.EOF = true then
		WriteLn('ActionResetCheck(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			errorLevel := rs.FieldByName(FLD_AAD_EL).AsInteger;
			WriteLn(errorLevel:12);
			if errorLevel <> 0 then
			begin
				// Not all steps where successful, set 
				allSuccesFull := false;
			end;
			rs.Next;
		end;
	end;
	rs.Free;
	
	if allSuccesFull = false then
		TableArpSetStatus(recId, 99)
	else
		TableArpSetStatus(recId, 100)
end; // of procedure ActionResetCheck(


procedure TableAadAdd(actId: integer; isActive: integer; actionNumber: integer; command: string);
//
//	Add a record to the table AAD
//
//		actId				Action Number.
//		isActive			Is this active?  0=INACTIVE, 1=ACTIVE, 9=TEST
//		actionNumber		For what action is this? 1=NEW ACCOUNT ,2=RESET PASSWORD, etc
//		command				Full command to do
var
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_AAD;
	qi := qi + ' SET'; 
	qi := qi + ' ' + FLD_AAD_ACTION_ID + '=' + IntToStr(actId);
	qi := qi + ',' + FLD_AAD_IS_ACTIVE + '=' + IntToStr(isActive);
	qi := qi + ',' + FLD_AAD_ACTION_NR + '=' + IntToStr(actionNumber);
	qi := qi + ',' + FLD_AAD_CMD + '=' + FixStr(command) + ';';
	
	WriteLn('TableAadAdd(): ', qi);
	
	RunQuery(qi);
end; // of procedure TableAadAdd


procedure UpdateAadErrorLevel(recId: integer; errorLevel: integer);
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + TBL_AAD;
	qu := qu + ' SET';
	qu := qu + ' ' + FLD_AAD_EL + '=' + IntToStr(errorLevel);
	qu := qu + ' WHERE ' + FLD_AAD_ID + '=' + IntToStr(recId);
	qu := qu + ';';
	
	WriteLn('UpdateAadErrorLevel(): ', qu);
	
	RunQuery(qu);
end; // of procedure UpdateAadErrorLevel


procedure ActionResetProcess(curAction: integer; recId: integer);
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	cmd: string;
	//upn: string;
	//initialPassword: string;
	//actId: integer;
	//stepNum: integer;
	r: integer;
begin
	WriteLn('PROCESSACTIONS()');
	
	// Select all records where the error level is not filled in,
	// And the is_active field = 9.
	qs := 'SELECT *';
	qs := qs + ' FROM ' + TBL_AAD;
	qs := qs + ' WHERE ' + FLD_AAD_EL + ' IS NULL';
	qs := qs + ' AND ' + FLD_AAD_ACTION_ID + '=' + IntToStr(recId);
	qs := qs + ' AND ' + FLD_AAD_ACTION_NR + '=' + IntToStr(curAction);
	qs := qs + ' AND ' + FLD_AAD_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE);
	qs := qs + ' ORDER BY ' + FLD_AAD_RCD;
	qs := qs + ';';
	
	WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('ProcessActions(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			recId := rs.FieldByName(FLD_AAD_ID).AsInteger;
			cmd := rs.FieldByName(FLD_AAD_CMD).AsString;
			
			WriteLn(recId:4, '     ', cmd);
			
			r := RunCommand(cmd);
			WriteLn('RunCommand: ', cmd);
			WriteLn('ERRORLEVEL=' , r);
			
			UpdateAadErrorLevel(recId, r);
			
			rs.Next;
		end;
	end;
	rs.Free;
	
end; // of procedure ProcessActions



procedure UpdatePassword(recId: integer; newPassword: string);
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + VIEW_RESET;
	qu := qu + ' SET';
	qu := qu + ' ' + VIEW_RESET_INITPW + '=' + EncloseSingleQuote(newPassword);
	qu := qu + ' WHERE ' + VIEW_RESET_ID + '=' + IntToStr(recId);
	qu := qu + ';';
	
	WriteLn('UpdatePassword(): ', qu);
	
	RunQuery(qu);
end; // of procedure UpdatePassword


procedure DoActionReset(curAction: integer);
//
//		curAction		What is the current action (2 for password reset)
//
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	recId: integer;
	dn: string;
	upn: string;
	initialPassword: string;
begin
	WriteLn('DOACTIONRESET()');
	WriteLn(ACTION_RESET);
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + VIEW_RESET + ' ';
	qs := qs + 'WHERE ' + VIEW_RESET_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + VIEW_RESET_STATUS + '=0 ' ;
	qs := qs + 'ORDER BY ' + VIEW_RESET_RCD;
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
			recId := rs.FieldByName(VIEW_RESET_ID).AsInteger;
			dn := rs.FieldByName(VIEW_RESET_DN).AsString;
			upn := rs.FieldByName(VIEW_RESET_UPN).AsString;
			initialPassword := rs.FieldByName(VIEW_RESET_INITPW).AsString;
			if Length(initialPassword) = 0 then
			begin
				// When no initial password is entered in the table, generate a new password
				initialPassword := GeneratePassword();
				
				// Update the table to register the generated password. 
				UpdatePassword(recId, initialPassword);
			end; // of if
			
			WriteLn(recId:4, ' ', dn, '  ', upn, '  ', initialPassword);
			
			// Add the first step: Write the command to the action_do table to setup a new password.
			TableAadAdd(recId, VALID_ACTIVE, curAction, 'dsmod.exe user "' + dn + '" -pwd "' + initialPassword + '"');
			
			// Set the 2nd step: Write the command to "Must change password flag on".
			TableAadAdd(recId, VALID_ACTIVE, curAction, 'dsmod.exe user "' + dn + '" -mustchpwd yes');
			
			
			// Execute all actions in table AAD for password resets
			ActionResetProcess(curAction, recId);

			// Check all records that are processed for a correct execution
			ActionResetCheck(curAction, recId);
			
			// Send a e-mail to the requester with the password.
			ActionResetInformByEmail(curAction, recId);
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure ActionResetFillTableAad


end. // of unit aam_action_reset