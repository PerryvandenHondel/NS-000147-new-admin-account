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
	// Remove for real version, now th email will be send to myself.
	mail := 'perry.vandenhondel@ns.nl';
	
	

	cmd := 'blat.exe ' + path;
	cmd := cmd + ' -to ' + EncloseDoubleQuote(mail);
	cmd := cmd + ' -f ' + EncloseDoubleQuote(MAIL_FROM);
	cmd := cmd + ' -bcc ' + EncloseDoubleQuote(MAIL_BCC);
	cmd := cmd + ' -subject ' + EncloseDoubleQuote(subject);
	cmd := cmd + ' -server vm70as005.rec.nsint';
	cmd := cmd + ' -port 25';

	WriteLn('========================');
	WriteLn;
	WriteLn(cmd);
	WriteLn;
	WriteLn('========================');
	
	RunCommand(cmd);
	Sleep(SLEEP_NEXT_ACTION);
end;


procedure InformAdminAccountWillBeDeleted();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	upn: Ansistring;
	personId: integer;
	accountId: integer;
	mail: Ansistring;
	preAlertDays: integer;
	realLastLogonDate: Ansistring;
	realLastLogonDays: integer;
	tresholdDeleteDays: integer;
	f: TextFile;
	path: Ansistring;
	subject: Ansistring;
begin
	WriteLn('=====');
	WriteLn('InformAdminAccountWillBeDeleted()');
	
	qs := 'SELECT';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_IS_ACTIVE;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_APS_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_UPN;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_MAIL;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_REAL_LAST_LOGON;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_TRESHOLD_DELETE_DAYS;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_PRE_ALERT_DAYS;
	qs := qs + ' ';
	qs := qs + #10#13;
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + #10#13;
	qs := qs + 'INNER JOIN ' + TBL_ADM + ' ON ' + FLD_ADM_ID + '=' + FLD_ATV_ADM_ID + ' ';
	qs := qs + #10#13;
	qs := qs + 'HAVING ' + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + '=' + FLD_ADM_TRESHOLD_DELETE_DAYS + '-' + FLD_ADM_PRE_ALERT_DAYS + ' ';
	qs := qs + #10#13;
	qs := qs + 'AND ' + FLD_ATV_MAIL + ' IS NOT NULL';
	qs := qs + #10#13;
	qs := qs + 'AND ' + FLD_ATV_IS_ACTIVE + '=1';
	qs := qs + ';';
		
	//WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('INFORMATION: There are no records that are about to be deleted!')
	else
	begin
		while not rs.EOF do
		begin
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mail := rs.FieldByName(FLD_ATV_MAIL).AsString;
			personId := rs.FieldByName(FLD_ATV_APS_ID).AsInteger;
			accountId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mail := rs.FieldByName(FLD_ATV_MAIL).AsString;
			preAlertDays := rs.FieldByName(FLD_ADM_PRE_ALERT_DAYS).AsInteger;
			realLastLogonDate := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON).AsString;
			realLastLogonDays := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON_DAYS_AGO).AsInteger;
			tresholdDeleteDays := rs.FieldByName(FLD_ADM_TRESHOLD_DELETE_DAYS).AsInteger;
			
			WriteLn('============================================');
			WriteLn('DELETE	MAIL TO: ', mail);
			WriteLn('   UPN               : ', upn);
			WriteLn('   Real last logon   : ', realLastLogonDate);
			WriteLn;
			
			path := SysUtils.GetTempFileName();
			SysUtils.DeleteFile(path);
			
			// Open the text file and read the lines from it.
			Assign(f, path);
			
			{I+}
			ReWrite(f);
			
			WriteLn('SEND MAIL TO: ', mail);
			WriteLn(f, '*** AUTOMATICCALY GENERATED MESSAGE, DO NOT REPLY! ***');
			WriteLn(f);
			WriteLn(f, 'Hello,');
			WriteLn(f);
			WriteLn(f, 'Your account ', upn, ' is about to be deleted due to inactivity.');
			WriteLn(f, 'The last logon action was on ', realLastLogonDate, ', that was ', realLastLogonDays, ' days ago.');
			WriteLn(f, 'You have ', preAlertDays, ' days left before the account will be deleted.');
			WriteLn(f);
			WriteLn(f, 'Security policy dictates that your latest logon action needs to be less then ', tresholdDeleteDays, ' days.');
			WriteLn(f);
			WriteLn(f, 'Deleted accounts must be created again using a request in Argusweb,');
			WriteLn(f, 'ask you manager or NS contact to make such a request.');
			WriteLn(f);
			WriteLn(f, 'We advise you to perform a logon action at least once a month to ensure an active status of this account.');
			WriteLn(f);
			WriteLn(f, 'Regards,');
			WriteLn(f);
			WriteLn(f);
			WriteLn(f, 'NS AD Beheer');
			WriteLn(f, 'Telephone: +31 88 6711674');
			WriteLn(f, 'E-mail: nsg.hostingadbeheer@ns.nl');
			
			Close(f);
			
			subject := 'IMPORTANT: Your account ' + upn + ' is expected to be deleted!';
			SendOneMail(mail, subject, path);
			
			AddRecordToTableAccountInformed(personId, accountId, subject, 'ACCOUNT_DELETE', Now());
			
			// Delete the body file
			SysUtils.DeleteFile(path);
									
			rs.Next;
		end;
	end;
	rs.Free;
end;


procedure InformAdminAccountWillBeDisabled();
var
	qs: Ansistring;
	rs: TSQLQuery;		// Uses SqlDB
	personId: integer;
	accountId: integer;
	upn: Ansistring;
	mail: Ansistring;
	preAlertDays: integer;
	realLastLogonDate: Ansistring;
	realLastLogonDays: integer;
	tresholdDisableDays: integer;
	f: TextFile;
	path: Ansistring;
	subject: Ansistring;
begin
	WriteLn('=====');
	WriteLn('InformAdminAccountWillBeDisabled()');
	
	qs := 'SELECT';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_IS_ACTIVE;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_APS_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_UPN;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_MAIL;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_REAL_LAST_LOGON;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_TRESHOLD_DISABLE_DAYS;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_PRE_ALERT_DAYS;
	qs := qs + ' ';
	qs := qs + #10#13;
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + #10#13;
	qs := qs + 'INNER JOIN ' + TBL_ADM + ' ON ' + FLD_ADM_ID + '=' + FLD_ATV_ADM_ID + ' ';
	qs := qs + #10#13;
	qs := qs + 'HAVING ' + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + '>' + FLD_ADM_TRESHOLD_DISABLE_DAYS + '-' + FLD_ADM_PRE_ALERT_DAYS + ' ';
	qs := qs + #10#13;
	qs := qs + 'AND ' + FLD_ATV_MAIL + ' IS NOT NULL';
	qs := qs + #10#13;
	qs := qs + 'AND ' + FLD_ATV_IS_ACTIVE + '=1';
	qs := qs + ';';
		
	//WriteLn(qs);
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := qs;
	rs.Open;

	if rs.EOF = true then
		WriteLn('INFORMATION: There are no records that are about to be disabled!')
	else
	begin
		while not rs.EOF do
		begin
			personId := rs.FieldByName(FLD_ATV_APS_ID).AsInteger;
			accountId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mail := rs.FieldByName(FLD_ATV_MAIL).AsString;
			preAlertDays := rs.FieldByName(FLD_ADM_PRE_ALERT_DAYS).AsInteger;
			realLastLogonDate := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON).AsString;
			realLastLogonDays := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON_DAYS_AGO).AsInteger;
			tresholdDisableDays := rs.FieldByName(FLD_ADM_TRESHOLD_DISABLE_DAYS).AsInteger;
			
			WriteLn('============================================');
			WriteLn('DISABLE MAIL TO: ', mail);
			WriteLn('   UPN                   : ', upn);
			WriteLn('   Real last logon date  : ', realLastLogonDate);
			WriteLn('   Real last logon days  : ', realLastLogonDays);
			WriteLn('   Disable after days    : ', tresholdDisableDays);
			WriteLn;
			
			path := SysUtils.GetTempFileName();
			SysUtils.DeleteFile(path);
			
			// Open the text file and read the lines from it.
			Assign(f, path);
			
			{I+}
			ReWrite(f);
			
			WriteLn('SEND MAIL TO: ', mail);
			WriteLn(f, '*** AUTOMATICCALY GENERATED MESSAGE, DO NOT REPLY! ***');
			WriteLn(f);
			WriteLn(f, 'Hello,');
			WriteLn(f);
			WriteLn(f, 'Your account ', upn, ' is about to be disabled due to inactivity.');
			WriteLn(f, 'The last logon action was on ', realLastLogonDate, ', that was ', realLastLogonDays, ' days ago.');
			WriteLn(f, 'You have ', preAlertDays, ' days left before the account will be disabled.');
			WriteLn(f);
			WriteLn(f, 'Security policy dictates that your latest logon action needs to be less then ', tresholdDisableDays, ' days.');
			WriteLn(f);
			WriteLn(f, 'Disabled accounts can be re-enabled by a request in Argusweb,');
			WriteLn(f, 'ask you manager or NS contact to make such a request.');
			WriteLn(f);
			WriteLn(f, 'We advise you to perform a logon action at least once a month to ensure an active status of this account.');
			WriteLn(f);
			WriteLn(f, 'Regards,');
			WriteLn(f);
			WriteLn(f);
			WriteLn(f, 'NS AD Beheer');
			WriteLn(f, 'Telephone: +31 88 6711674');
			WriteLn(f, 'E-mail: nsg.hostingadbeheer@ns.nl');
			
			Close(f);
			
			subject := 'IMPORTANT: Your account ' + upn + ' is expected to be disabled!';
			SendOneMail(mail, subject, path);
			
			AddRecordToTableAccountInformed(personId, accountId, subject, 'ACCOUNT_DISABLE', Now());
			
			// Delete the body file
			//SysUtils.DeleteFile(path);
						
			rs.Next;
		end;
	end;
	rs.Free;
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
	passwordLastSetDaysAgo: integer;
	maxPasswordAgeInDays: integer;
	passwordExpiresOn: Ansistring;
	preAlertDays: integer;
	path: Ansistring;
	f: TextFile;
	subject: Ansistring;
begin
	WriteLn('=====');
	WriteLn('InformAdminPasswordWillExpire()');

	qs := 'SELECT';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_APS_ID;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_IS_ACTIVE;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_UPN;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_MAIL;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_PWD_LAST_SET;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_PWD_LAST_SET_DAYS_AGO;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ATV_PWD_EXPIRES_ON;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_PRE_ALERT_DAYS;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_MAX_PASSSWORD_AGE_DAYS;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + FLD_ADM_TRESHOLD_DISABLE_DAYS;
	qs := qs + ',';
	qs := qs + #10#13;
	qs := qs + '(' + FLD_ADM_MAX_PASSSWORD_AGE_DAYS + '-' + FLD_ADM_PRE_ALERT_DAYS + ') AS PreAlertDays';
	qs := qs + #10#13;
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + #10#13;
	qs := qs + 'INNER JOIN ' + TBL_ADM + ' ON ' + FLD_ADM_ID + '=' + FLD_ATV_ADM_ID;
	qs := qs + #10#13;
	qs := qs + 'HAVING ' + FLD_ATV_PWD_LAST_SET_DAYS_AGO + '=PreAlertDays';
	qs := qs + #10#13;
	qs := qs + 'AND ' + FLD_ATV_IS_ACTIVE + '=1';
	qs := qs + #10#13;
	qs := qs + 'ORDER BY ' + FLD_ATV_PWD_LAST_SET_DAYS_AGO;
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
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mail := rs.FieldByName(FLD_ATV_MAIL).AsString;
			personId := rs.FieldByName(FLD_ATV_APS_ID).AsInteger;
			accountId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			passwordLastSet := rs.FieldByName(FLD_ATV_PWD_LAST_SET).AsString;
			passwordLastSetDaysAgo := rs.FieldByName(FLD_ATV_PWD_LAST_SET_DAYS_AGO).AsInteger;
			maxPasswordAgeInDays := rs.FieldByName(FLD_ADM_MAX_PASSSWORD_AGE_DAYS).AsInteger;
			preAlertDays := rs.FieldByName(FLD_ADM_PRE_ALERT_DAYS).AsInteger;
			passwordExpiresOn := rs.FieldByName(FLD_ATV_PWD_EXPIRES_ON).AsString;
			
			WriteLn('Only records with ', preAlertDays, ' days for pre-alert.');
			
			
			WriteLn('-----------------------------------------------');
			WriteLn('PASSWORD EXPIRES MAIL TO: ', mail);
			WriteLn('upn                 : ', upn);
			WriteLn('Password last set   : ', passwordLastSet);
			WriteLn('Password days old   : ', IntToStr(passwordLastSetDaysAgo));
			WriteLn('Password expires on : ', passwordExpiresOn);
			WriteLn;
			
			path := SysUtils.GetTempFileName();
			//WriteLn('Mail body: ', path);
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
			WriteLn(f, 'Your password is about to expire for account ', upn, '.');
			WriteLn(f, 'The password is last changed on ', passwordLastSet, ', the current password is still valid for ', preAlertDays, ' days.');
			WriteLn(f);
			WriteLn(f, 'Please login and change your password before ', passwordExpiresOn, '.');
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
			
			subject := 'IMPORTANT: The password of your account ' + upn + ' is about to expire!';
			SendOneMail(mail, subject, path);

			AddRecordToTableAccountInformed(personId, accountId, subject, 'PASSWORD_EXPIRED', Now());
			
			// Delete the body file
			//SysUtils.DeleteFile(path);
			
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
	InformAdminAccountWillBeDisabled();
	InformAdminAccountWillBeDeleted();
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