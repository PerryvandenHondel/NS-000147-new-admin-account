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
	
	
const
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


procedure DoActionReset();


implementation


{	TBL_AAD =				'account_action_detail_aad';
	FLD_AAD_ID = 			'aad_id';
	FLD_AAD_ACT_ID =		'aad_act_id';
	FLD_AAD_CMD = 			'aad_command';
	FLD_AAD_EL = 			'aad_error_level';
	FLD_AAD_RCD = 			'aad_rcd';
	FLD_AAD_RLU = 			'aad_rlu';
}

procedure TableAadAdd(actId: integer; stepNum: integer; command: string);
//
//	Add a record to the table AAD
//
var
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_AAD + ' ';
	qi := qi + 'SET '; 
	qi := qi + FLD_AAD_ACT_ID + '=' + IntToStr(actId) + ',';
	qi := qi + FLD_AAD_STEP_NUM + '=' + IntToStr(stepNum) + ',';
	qi := qi + FLD_AAD_CMD + '=' + FixStr(command) + ' ';
	
	WriteLn(qi);
	
	RunQuery(qi);
end; // of procedure TableAadAdd


function TableActAdd(desc: string): integer;
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
	qi := qi + FLD_ACT_DESC + '=' + FixStr(desc) + ';';
	WriteLn(qi);
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
	qs := qs + 'WHERE ' + VIEW_RESET_IS_ACTIVE + '=1 ';
	qs := qs + 'AND ' + VIEW_RESET_STATUS + '=0 ';
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
			
			WriteLn(recId:4, ' ', dn, '  ', upn, '  ', initialPassword);
			
			actId := TableActAdd('Password reset for ' + upn);
			
			// Add the first step: set the password
			TableAadAdd(actId, stepNum, 'dsmod.exe user "' + dn + '" -pwd "' + initialPassword + '"');
			
			// Set the 2nd step: Must change password flag on.
			Inc(stepNum);
			TableAadAdd(actId, stepNum, 'dsmod.exe user "' + dn + '" -mustchpwd yes');
						
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure DoActionReset


end. // of unit aam_action_reset
