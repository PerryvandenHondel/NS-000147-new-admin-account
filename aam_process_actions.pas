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
}

procedure ProcessActions();
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
	WriteLn('PROCESSACTIONS()');
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + TBL_ACT + ' ';
	qs := qs + 'WHERE ' + FLD_ACT_STATUS + '=0 ';
	qs := qs + 'ORDER BY ' + VIEW_RESET_RCD;
	qs := qs + ';';
	
	WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn(' ProcessActions(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			recId := rs.FieldByName(FLD_ACT_ID).AsInteger;
			dn := rs.FieldByName(FLD_ACT_DESC).AsString;
			
			WriteLn(recId:4, ' ', dn);
			
			rs.Next;
		end;
	end;
	rs.Free;
	}
end; // of procedure ProcessActions


end. // of unit aam_process_actions
