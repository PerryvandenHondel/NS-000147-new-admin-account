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


unit aam_action03same;


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
	VIEW_SAME_ACTION_SHA1 = 			'vsame_action_sha1';
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


procedure ProcessNewActions(curAction: integer; recId: integer);
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
	WriteLn('ProcessNewActions()');
	
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
		WriteLn('ProcessNewActions(): No records found!')
	else
	begin
		while not rs.EOF do
		begin
			recId := rs.FieldByName(FLD_AAD_ID).AsInteger;
			cmd := rs.FieldByName(FLD_AAD_CMD).AsString;
			
			//WriteLn(recId:4, '     ', cmd);
			
			r := RunCommand(cmd);
			UpdateAadErrorLevel(recId, r);
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure ProcessNewActions


procedure TableAsmSetStatus(recId: integer; newStatus: integer);
//
//	Set a new status in the field status_id 
//
var
	qu: Ansistring;
begin
	qu := 'UPDATE ' + VIEW_SAME;
	qu := qu + ' SET';
	qu := qu + ' ' + VIEW_SAME_STATUS + '=' + IntToStr(newStatus);
	qu := qu + ' WHERE ' + VIEW_SAME_ID + '=' + IntToStr(recId);
	qu := qu + ';';
	
	WriteLn('TableAsmSetStatus(): ', qu);
	
	RunQuery(qu);
end; // of procedure TableAsmSetStatus


procedure ActionSameCheck(uniqueActionCode: string; recId: integer);
//procedure ProcessActionCheck(curAction: integer; recId: integer);	
var
	qs: Ansistring;
	rs: TSQLQuery;
	errorLevel: integer;
	allSuccesFull: boolean;
begin
	qs := 'SELECT ' + FLD_AAD_EL;
	qs := qs + ' FROM ' + TBL_AAD;
	//qs := qs + ' WHERE ' + FLD_AAD_ACTION_NR + '=' + IntToStr(curAction);
	//qs := qs + ' AND ' + FLD_AAD_ACTION_ID + '=' + IntToStr(recId);
	qs := qs + ' WHERE ' + FLD_AAD_ACTION_SHA1 + '=' + EncloseSingleQuote(uniqueActionCode);
	qs := qs + ';';
	
	WriteLn('ActionSameCheck(): ', qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	allSuccesFull := true;
	
	if rs.EOF = true then
		WriteLn('ActionSameCheck(): ', uniqueActionCode, ': No records found!')
	else
	begin
		while not rs.EOF do
		begin
			errorLevel := rs.FieldByName(FLD_AAD_EL).AsInteger;
			
			if errorLevel = -2147019886 then
				errorLevel := 0; // The account is already a member of the group. Set to 0. Not an error.
			
			if errorLevel <> 0 then
			begin
				allSuccesFull := false; // Not all steps where successful, set allSuccesFull to false;
			end;
			rs.Next;
		end;
	end;
	rs.Free;
	
	if allSuccesFull = false then
		TableAsmSetStatus(recId, 99)
	else
		TableAsmSetStatus(recId, 100)
end; // of procedure ProcessActionCheck


procedure InsertRecordsInActionTable(recId: integer; curAction: integer; sourceDn: string; targetDn: string; actionSha1: string);
//
//	Obtain all the groups of sourceDn and create records in the action table to perform
//
//
var	
	path: string;
	p: TProcess;
	f: TextFile;
	groupDn: string;
	c: Ansistring;
	line: string;	// Read a line from the nslookup.tmp file.
begin
	// Get a temp file to store the output of the adfind.exe command.
	path := SysUtils.GetTempFileName(); // Path is C:\Users\<username>\AppData\Local\Temp\TMP00000.tmp
	WriteLn(path); // DEBUG
	
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
		begin
			// WriteLn(line); // DEBUG
			
			groupDn := RightStr(line, Length(line) - Length('>memberOf: '));
			//WriteLn(groupDn);
			
			//TableAadAdd(recId, VALID_ACTIVE, curAction, 'dsmod.exe user "' + dn + '" -mustchpwd yes');
			//dsmod group  "CN=US Info,OU=Distribution Lists,DC=Contoso,DC=Com"  -addmbr "CN=Mike Danseglio,CN=Users,DC=Contoso,DC=Com" 
			//NewTableAadAdd(recId, VALID_ACTIVE, curAction, actionSha1, 'dsmod.exe group ' + EncloseDoubleQuote(groupDn)+ ' -addmbr ' + EncloseDoubleQuote(targetDn));
			c := 'dsmod.exe group ' + EncloseDoubleQuote(groupDn)+ ' -addmbr ' + EncloseDoubleQuote(targetDn);
			AddRecordToTableAad(actionSha1, c);
		end; // of if	
	until Eof(f);
	Close(f);
	
	// Delete the temp file 
	SysUtils.DeleteFile(path);
	
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
	actionSha1: string;
begin
	WriteLn('-----------------------------------------------------------------');
	WriteLn('DoActionSame(', curAction, ')');
	
	qs := 'SELECT * ';
	qs := qs + 'FROM ' + VIEW_SAME + ' ';
	qs := qs + 'WHERE ' + VIEW_SAME_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + VIEW_SAME_STATUS + '=0 ' ;
	qs := qs + 'ORDER BY ' + VIEW_SAME_RCD;
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
			recId := rs.FieldByName(VIEW_SAME_ID).AsInteger;
			sourceDn := rs.FieldByName(VIEW_SAME_SOURCE_DN).AsString;
			targetDn := rs.FieldByName(VIEW_SAME_TARGET_DN).AsString;
			
			actionSha1 := GenerateUniqueActionNumber(curAction);
			WriteLn('DoActionSame(): ', actionSha1);
			
			UpdateOneFieldString(VIEW_SAME, VIEW_SAME_ID, recId, VIEW_SAME_ACTION_SHA1, actionSha1);
			
			WriteLn(recId:6, ': ', sourceDn, '   >>   ', targetDn);
			// Get the groups from sourceDn and add new action in the table action for targetDn
			InsertRecordsInActionTable(recId, curAction, sourceDn, targetDn, actionSha1);
			
			// Process all these new actions
			TableAadProcessActions(actionSha1);
			
			// Check if these actions are all done.
			//ProcessActionCheck(curAction, recId);
			ActionSameCheck(actionSha1, recId);
			
			rs.Next;
		end;
	end;
	rs.Free;
end; // of procedure DoActionSame


end. // of unit aam_action_same