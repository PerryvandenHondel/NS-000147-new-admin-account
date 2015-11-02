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
	
	

procedure DoActionReset();


implementation


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

{
function TableActAdd(desc: string; isActive: integer): integer;
//
//	Insert a record in the table ACT
//
var
	qi: Ansistring;
	qs: Ansistring;
	rs: TSQLQuery;
	r: integer;
begin
	r := 0;

	// Insert a new record in table ACT
	qi := 'INSERT INTO ' + TBL_ACT + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_ACT_ACTION_NR + '=' + IntToStr(ACTION_RESET) + ',';
	qi := qi + FLD_ACT_ACTIVE + '=' + IntToStr(isActive) + ',';
	qi := qi + FLD_ACT_DESC + '=' + FixStr(desc) + ';';
	//WriteLn(qi);
	RunQuery(qi);
	
	// Get the latest FLD_ACT_ID added for ACTION_RESET.
	qs :='SELECT ' + FLD_ACT_ID + ' ';
	qs := qs + 'FROM ' + TBL_ACT + ' ';
	qs := qs + 'WHERE ' + FLD_ACT_ACTION_NR + '=' + IntToStr(ACTION_RESET) + ' ';
	qs := qs + 'ORDER BY ' + FLD_ACT_RCD + ' DESC ';
	qs := qs + 'LIMIT 1;';
	WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('TableActAdd(): Cant find the latest record added for action: ', ACTION_RESET)
	else
	begin
		r := rs.FieldByName(FLD_ACT_ID).AsInteger;
	end;
	
	TableActAdd := r;
end; // of function TableAccountActionDetailInsert
}

{
procedure TableActUpdateStepCount(actId: integer; stepCount: integer);
//
//	Write the value of stepNum to the ACT table.
//	How many steps for the action
//	
//		actId			Action ID
//		stepCount		Number of steps
//
var	
	qu: Ansistring;
begin
	qu := 'UPDATE ' + TBL_ACT + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_ACT_STEP_COUNT + '=' + IntToStr(stepCount) + ' ';
	qu := qu + 'WHERE ' + FLD_ACT_ID + '=' + IntToStr(actId) + ';';
	
	RunQuery(qu);
end; // of procedure TableActUpdateStepCount
}


procedure ProcessActions();


implementation


{	TBL_ACT = 				'account_action_act';
	FLD_ACT_ID = 			'act_id';
	FLD_ACT_ACTION_NR = 	'act_action_nr';
	FLD_ACT_DESC = 			'act_description';
	FLD_ACT_STATUS = 		'act_status';
	FLD_ACT_RCD = 			'act_rcd';
	FLD_ACT_RLU = 			'act_rlu';

	TBL_AAD =				'account_action_detail_aad';
	FLD_AAD_ID = 			'aad_id';
	FLD_AAD_ACT_ID =		'aad_act_id';
	FLD_AAD_STEP_NUM = 		'aad_step';
	FLD_AAD_CMD = 			'aad_command';
	FLD_AAD_EL = 			'aad_error_level';
	FLD_AAD_STATUS = 		'aad_status';
	FLD_AAD_RCD = 			'aad_rcd';
	FLD_AAD_RLU = 			'aad_rlu';
	}

{
procedure TableActSetStatus(recId: integer; newStatus: integer);
//
//	Set the status of the field act_status to the value newStatus
//
var
	qu: Ansistring;	
begin
	qu := 'UPDATE ' + TBL_ACT + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_ACT_STATUS + '=' + IntToStr(newStatus) + ' ';
	qu := qu + 'WHERE ' + FLD_ACT_ID + '=' + IntToStr(recId) + ';';
	
	RunQuery(qu);
end; // of procedure TableActSetStatus
	
	
procedure TableAadSetErrorLevel(recId: integer; el: integer);
//
//	Set the error level in the table
//
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + TBL_AAD + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_AAD_EL + '=' + IntToStr(el) + ' ';
	qu := qu + 'WHERE ' + FLD_AAD_ID + '=' + IntToStr(recId) + ';';
	
	RunQuery(qu);
end; // of procedure TableAadSetErrorLevel


function ProcessActionDetails(actId: integer): integer;
//
//	Process all steps for an Action
//
//	Return a result
//		100 = OK
//		900	= FAILED on of the steps
//
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	recId: integer;
	cmd: Ansistring;
	el: integer;
	actRecId: integer;
begin
	WriteLn('ProcessActionDetails()');
	
	qs := 'SELECT ' + FLD_AAD_ID + ',' + FLD_AAD_CMD + ' ';
	qs := qs + 'FROM ' + TBL_AAD + ' ';
	qs := qs + 'WHERE ' + FLD_AAD_ACT_ID + '=' + IntToStr(actId) + ' ';
	qs := qs + 'ORDER BY ' + FLD_AAD_STEP_NUM + ';';
	
	WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('ProcessActionDetails(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			recId := rs.FieldByName(FLD_AAD_ID).AsInteger;
			cmd := rs.FieldByName(FLD_AAD_CMD).AsString;
			
			el := RunCommand(cmd);
			
			TableAadSetErrorLevel(recId, el);

			rs.Next;
		end;
	end;
	rs.Free;

	// Now check if there is a error level returned other then 0 for all the steps.
	// If so, then set the status of the ACT status to 999
	qs := 'SELECT ' + FLD_AAD_EL + ',' + FLD_AAD_STEP_NUM + ',' + FLD_AAD_ACT_ID + ' ';
	qs := qs + 'FROM ' + TBL_AAD + ' ';
	qs := qs + 'WHERE ' + FLD_AAD_ACT_ID + '=' + IntToStr(actId) + ' ';
	qs := qs + 'ORDER BY ' + FLD_AAD_STEP_NUM + ';';

	WriteLn(qs);

	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;	
	if rs.EOF = true then
	begin
		WriteLn('ProcessActionDetails(): No records found!');
		WriteLn('Now check if there is a error level');
	end
	else
	begin
		while not rs.EOF do
		begin
			
			actRecId := rs.FieldByName(FLD_AAD_ACT_ID).AsInteger;
			el := rs.FieldByName(FLD_AAD_EL).AsInteger;
			WriteLn(actRecId);
			if el <> 0 then
			begin
				// When the Error Level value is not 0, it failed and the action is failed
				TableActSetStatus(actRecId, 999);
				break;
			end;
			rs.Next;
		end;
	end;
	rs.Free;
end; // of function ProcessActionDetails
}




{
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


procedure ProcessActions();
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	recId: integer;
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


procedure DoActionReset();
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	recId: integer;
	dn: string;
	upn: string;
	initialPassword: string;
	actId: integer;
	stepNum: integer;
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
			stepNum := 1;
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
			TableAadAdd(recId, VALID_ACTIVE, ACTION_RESET, 'dsmod.exe user "' + dn + '" -pwd "' + initialPassword + '"');
			
			// Set the 2nd step: Write the command to "Must change password flag on".
			TableAadAdd(recId, VALID_ACTIVE, ACTION_RESET, 'dsmod.exe user "' + dn + '" -mustchpwd yes');
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure DoActionReset


end. // of unit aam_action_reset
