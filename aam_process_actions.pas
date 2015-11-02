//
//	Admin Account Management -- Process actions
//


unit aam_process_actions;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	SysUtils,
	USupportLibrary,
	ODBCConn,
	SqlDb,
	aam_global;
	
	
//const


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


procedure ProcessActions();
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	recId: integer;
	desc: string;
	upn: string;
	initialPassword: string;
	actId: integer;
	stepNum: integer;
	r: integer;
begin
	WriteLn('PROCESSACTIONS()');
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + TBL_ACT + ' ';
	qs := qs + 'WHERE ' + FLD_ACT_STATUS + '=0 ';
	qs := qs + 'AND ' + FLD_ACT_ACTIVE + '=1 ';
	qs := qs + 'ORDER BY ' + FLD_ACT_RCD;
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
			recId := rs.FieldByName(FLD_ACT_ID).AsInteger;
			desc := rs.FieldByName(FLD_ACT_DESC).AsString;
			
			WriteLn(recId:4, ' ', desc);
			
			//r := ProcessActionDetails(recId);
			WriteLn(r);
			
			
			rs.Next;
		end;
	end;
	rs.Free;
	
end; // of procedure ProcessActions


end. // of unit aam_process_actions
