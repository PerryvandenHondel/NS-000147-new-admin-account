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
	aam_global,
	aam_database;			// Link all database 
	
	
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

	{
	Defined in AAM_DATABASE.PAS, perhaps move to AAM_GLOBAL.PAS for global program use.
	TBL_ACT = 				'account_action_act';
	FLD_ACT_ID = 			'act_id';
	FLD_ACT_ACTION_NR = 	'act_action_nr';
	FLD_ACT_DESC = 			'act_description';
	FLD_ACT_RCD = 			'act_rcd';
	FLD_ACT_RLU = 			'act_rlu';
	}

procedure DoActionReset();


implementation


procedure DoActionReset();
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
			recId := rs.FieldByName(VIEW_RESET_ID).AsInteger;
			dn := rs.FieldByName(VIEW_RESET_DN).AsString;
			upn := rs.FieldByName(VIEW_RESET_UPN).AsString;
			initialPassword := rs.FieldByName(VIEW_RESET_INITPW).AsString;
			
			WriteLn(recId:4, ' ', dn, '  ', upn, '  ', initialPassword);
			
			WriteLn(TableActAdd('Password reset for ' + upn));
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure DoActionReset


end. // of unit aam_action_reset
