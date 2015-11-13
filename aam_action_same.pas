//
//	Admin Account Management -- Same groups
//
//	FLOW:
//		DoActionSame
//			TableAsm
//			ActionSameProcess
//			ActionSameCheck
//			ActionSameInformByEmail
//




unit aam_action_same;


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
	

procedure DoActionSame(curAction: integer);			// Add new actions to the table AAD for password resets

const		
	VIEW_SAME =							'account_action_view_same';
	VIEW_SAME_ID = 						'vsame_id';
	VIEW_SAME_IS_ACTIVE = 				'vsame_is_active';
	VIEW_SAME_SOURCE_ID = 				'vsame_source_atv_id';
	VIEW_SAME_SOURCE_DN = 				'vsame_source_dn';
	VIEW_SAME_TARGET_ID = 				'vsame_target_atv_id';
	VIEW_SAME_TARGET_DN = 				'vsame_target_dn';
	VIEW_SAME_ARQ_ID = 					'vsame_arq_id';
	VIEW_SAME_MAIL_TO = 				'vsame_mail_to';
	VIEW_SAME_REF = 					'vsame_reference';
	VIEW_SAME_STATUS = 					'vsame_status';
	VIEW_SAME_RCD = 					'vsame_rcd';
	VIEW_SAME_RLU = 					'vsame_rlu';


implementation


procedure InsertRecordsInActionTable(recId: integer; curAction: integer; sourceDn: string; targerDn: string);
//
//	Obtain all the groups of sourceDn and create records in the action table to perform
//
//
var	
	path: string;
	p: TProcess;
	f: TextFile;
	line: string;	// Read a line from the nslookup.tmp file.
begin
	// Get a temp file to store the output of the adfind.exe command.
	path := SysUtils.GetTempFileName(); // Path is C:\Users\<username>\AppData\Local\Temp\TMP00000.tmp
	WriteLn(path);
	
	p := TProcess.Create(nil);
	p.Executable := 'cmd.exe'; 
    p.Parameters.Add('/c adfind.exe -b "' + sourceDn + '" memberOf >' + path);
	p.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
	p.Execute;
	
	// Open the text file and read the lines from it.
	Assign(f, path);
	
	{I+}
	Reset(f);
	repeat
		ReadLn(f, line);
		if Pos('>memberOf: ', line) > 0 then
			WriteLn(line);
			
	until Eof(f);
	Close(f);
	
	//SysUtils.DeleteFile(path);
	
end; // of procedure InsertRecordsInActionTable


procedure DoActionSame(curAction: integer);
//
//		curAction		What is the current action (3 for Same Groups)
//
var
	qs: Ansistring;
	rs: TSQLQuery;
	
	recId: integer;
	sourceDn: string;
	targetDn: string;
	
	upn: string;
	initialPassword: string;
begin
	WriteLn('-----------------------------------------------------------------');
	WriteLn('DoActionSame()');
	WriteLn(ACTION_SAME);
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + VIEW_SAME + ' ';
	qs := qs + 'WHERE ' + VIEW_SAME_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + VIEW_SAME_STATUS + '=0 ' ;
	qs := qs + 'ORDER BY ' + VIEW_SAME_RCD;
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
			recId := rs.FieldByName(VIEW_SAME_ID).AsInteger;
			sourceDn := rs.FieldByName(VIEW_SAME_SOURCE_DN).AsString;
			targetDn := rs.FieldByName(VIEW_SAME_TARGET_DN).AsString;
			
			WriteLn(recId:6, ': ', sourceDn, '   >>   ', targetDn);
			InsertRecordsInActionTable(recId, curAction, sourceDn, targetDn);
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure DoActionSame


end. // of unit aam_action_same