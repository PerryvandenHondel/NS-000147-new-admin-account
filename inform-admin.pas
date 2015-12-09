//
//	Title
//		inform-admin.exe
//	Description
//		Inform the administrator for the status on his account:
//			- not logged on for x days
//			- account locked
//			- account will be disabled
//			- account will be deleted
//


program InformAdmin;


{$MODE OBJFPC} // Do not forget this ever
{$M+}
{$H+}


uses
	DateUtils,
	StrUtils,
	SysUtils,
	Process,
	USupportLibrary,
	ODBCConn,
	SqlDb,
	aam_global;

	
procedure AddRecordToTableAccountInformed(personId: integer; accountId: integer; msg: Ansistring; msgType: Ansistring; informedOn: TDateTime);
//
// Add a record to the ACCOUNT_INFORMED_AID
//
// 	personId		Person ID of the administrators unique id in APS table.
//	accountId		Active Account ID (ATV_ID)
//	msg				The message that is sended.
//	msgType			What is the type of the message: Password is about to exipire, Account disabled, account deleted.
//	informedOn		Date and Time of message send.
//
var
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_AID + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_AID_IS_ACTIVE + '=' + IntToStr(VALID_ACTIVE) + ',';
	qi := qi + FLD_AID_APS_ID + '=' + IntToStr(personId) + ',';
	qi := qi + FLD_AID_ATV_ID + '=' + IntToStr(accountId) + ',';
	qi := qi + FLD_AID_MSG + '=' + EncloseSingleQuote(msg) + ',';
	qi := qi + FLD_AID_MSG_TYPE + '=' + EncloseSingleQuote(msgType) + ',';
	qi := qi + FLD_AID_INFORMED_ON + '=' + EncloseSingleQuote(DateTimeToStr(informedOn)) + ';';
	
	RunQuery(qi);
end;
	

procedure SendOneMail(mail: Ansistring; subject: Ansistring; path: Ansistring);
var
	cmd: Ansistring;
begin
	// Remove for real version
	mail := 'perry.vandenhondel@ns.nl';

	cmd := 'blat.exe ' + path;
	cmd := cmd + ' -to ' + EncloseDoubleQuote(mail);
	cmd := cmd + ' -f ' + EncloseDoubleQuote(MAIL_FROM);
	cmd := cmd + ' -bcc ' + EncloseDoubleQuote(MAIL_BCC);
	cmd := cmd + ' -subject ' + EncloseDoubleQuote(subject);
	cmd := cmd + ' -server vm70as005.rec.nsint';
	cmd := cmd + ' -port 25';

	WriteLn;
	WriteLn(cmd);
	WriteLn;
	
	RunCommand(cmd);
	Sleep(SLEEP_NEXT_ACTION);
end;


procedure InformAdminPasswordWillExpire();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	upn: Ansistring;
	mail: Ansistring;
	personId: integer;
	accountId: integer;
	passwordLastSet: Ansistring;
	maxPasswordAgeInDays: integer;
	//passwordLastSetInDay: integer;
	changePasswordBeforeDate: TDateTime;
	preAlertDays: integer;
	path: Ansistring;
	f: TextFile;
	subject: Ansistring;
begin
	{
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_UPN + ',' + FLD_ATV_MAIL + ',' + FLD_ATV_PWD_LAST_SET + ',' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + ',';
	qs := qs + 'TIMESTAMPDIFF(day, ' + FLD_ATV_PWD_LAST_SET + ',Now()) AS password_set_ago_in_days ';
	//qs := qs + 'DATE_ADD(', FLD_ATV_PWD_LAST_SET, ',INTERVAL ' ,  )
	qs := qs + #10#13;
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + #10#13;
	qs := qs + 'INNER JOIN ' + TBL_ADM + ' ON ' + FLD_ADM_ID + '=' + FLD_ATV_ADM_ID + ' ';
	qs := qs + #10#13;
	qs := qs + 'WHERE TIMESTAMPDIFF(day, ' + FLD_ATV_PWD_LAST_SET + ',Now())=' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + '-' + FLD_ADM_PRE_ALERT_DAYS + ' ';
	qs := qs + #10#13;
	qs := qs + 'AND ' + FLD_ATV_MAIL + ' IS NOT NULL ';
	qs := qs + #10#13;
	qs := qs + 'ORDER BY ' + FLD_ATV_PWD_LAST_SET + ' DESC;';
	}
	
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_APS_ID + ',' + FLD_ATV_UPN + ',' + FLD_ATV_MAIL + ',' + FLD_ATV_PWD_LAST_SET + ',' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + ',' + FLD_ADM_PRE_ALERT_DAYS + ',';
	qs := qs + 'DATEDIFF(NOW(), ' + FLD_ATV_PWD_LAST_SET + ') AS password_set_ago_in_days ';
	qs := qs + #10#13;
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + #10#13;
	qs := qs + 'INNER JOIN ' + TBL_ADM + ' ON ' + FLD_ADM_ID + '=' + FLD_ATV_ADM_ID + ' ';
	qs := qs + 'WHERE DATEDIFF(NOW(), ' + FLD_ATV_PWD_LAST_SET + ')=' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + '-' + FLD_ADM_PRE_ALERT_DAYS + ' ';
	qs := qs + 'AND ' + FLD_ATV_MAIL + ' IS NOT NULL;';
	
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
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mail := rs.FieldByName(FLD_ATV_MAIL).AsString;
			personId := rs.FieldByName(FLD_ATV_APS_ID).AsInteger;
			accountId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			passwordLastSet := rs.FieldByName(FLD_ATV_PWD_LAST_SET).AsString;
			maxPasswordAgeInDays := rs.FieldByName(FLD_ADM_MAX_PASSSWORD_AGE_DAYS).AsInteger;
			//passwordLastSetInDay := rs.FieldByName('password_set_ago_in_days').AsInteger;
			preAlertDays := rs.FieldByName(FLD_ADM_PRE_ALERT_DAYS).AsInteger;
			changePasswordBeforeDate := IncDay(StrToDateTime(passwordLastSet), maxPasswordAgeInDays);
			
			WriteLn('-----------------------------------------------');
			
			path := SysUtils.GetTempFileName();
			WriteLn('Mail body: ', path);
			SysUtils.DeleteFile(path);
			
			// Open the text file and read the lines from it.
			Assign(f, path);
	
			{I+}
			ReWrite(f);
			
			WriteLn('SEND MAIL TO: ', mail, '>', personId);
			WriteLn(f, '*** AUTOMATICCALY GENERATED MESSAGE, DO NOT REPLY! ***');
			WriteLn(f);
			WriteLn(f, 'Hello,');
			WriteLn(f);
			WriteLn(f, 'Your password is about to expire for account ', upn);
			WriteLn(f, 'The password is last changed on ', passwordLastSet, ', the current password is still valid for ', preAlertDays, ' days.');
			WriteLn(f);
			WriteLn(f, 'Change your password before ', DateTimeToStr(changePasswordBeforeDate));
			WriteLn(f);
			WriteLn(f, 'The AD domain password policy requires that a password needs to be changed every ', maxPasswordAgeInDays, ' days.');
			WriteLn(f);
			WriteLn(f, 'Regards,');
			WriteLn(f);
			WriteLn(f);
			WriteLn(f, 'NS AD Beheer');
			WriteLn(f, 'Telephone: +31 88 6711674');
			WriteLn(f, 'E-mail: nsg.hostingadbeheer@ns.nl');
			
			Close(f);

			subject := 'INFORMATION: Account ' + upn + ', the password is about to expire.';
			
			SendOneMail(mail, subject, path);
			AddRecordToTableAccountInformed(personId, accountId, subject, 'PASSWORD_EXPIRED', Now());
			
			// Delete the body file
			SysUtils.DeleteFile(path);
			
			rs.Next;
			WriteLn;
		end;
	end;
	rs.Free;
end;	


procedure ProgramInit();
begin
	DatabaseOpen();
end; // of procedure ProgramInit


procedure ProgramRun();
begin
	WriteLn('Running...');
	InformAdminPasswordWillExpire();
	
end; // of procedure ProgramRun


procedure ProgramDone();
begin
	DatabaseClose();
end; // of procedure ProgramDone


begin
	ProgramInit();
	ProgramRun();
	ProgramDone();
end. // of program InformAdmin