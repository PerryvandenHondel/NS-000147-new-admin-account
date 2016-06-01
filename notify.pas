program Notify;

	

{$MODE OBJFPC}			
{$LONGSTRINGS ON}		// Compile all strings as Ansistring



uses
	Crt,
	Classes, 
	DateUtils,						// For SecondsBetween
	Process, 
	SysUtils,
	USupportLibrary,
	SqlDB,
	aam_global;
	
	
	
var
	boolForReal: boolean;
	


procedure DoNotifyDisabled(atDays: integer; preDays: integer);
var	
	qs: Ansistring;
	rs: TSQLQuery;
	recId: integer;
	fname: Ansistring;
	upn: Ansistring;
	mailTo: Ansistring;
	lastLogon: Ansistring;
	//lastLogonDays: integer;
	notifyDays: integer;
	fileBody: Ansistring;
	f: TextFile;
	subject: Ansistring;
begin
	notifyDays := atDays - preDays;

	WriteLn('-----------------------------------');
	WriteLn('DoNotifyDisabled() Disable at ' + IntToStr(notifyDays) + ' days.');
	
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_UPN + ',' + FLD_ATV_MAIL + ',' + FLD_ATV_FNAME + ',' + FLD_ATV_REAL_LAST_LOGON + ',' + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' + FLD_ATV_IS_ACTIVE + '=1 '; // + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + FLD_ATV_MAIL + ' IS NOT NULL ' ;
	qs := qs + 'AND ' + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + '=' + IntToStr(notifyDays);
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
			recId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			fname := rs.FieldByName(FLD_ATV_FNAME).AsString;
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mailTo := rs.FieldByName(FLD_ATV_MAIL).AsString;
			lastLogon := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON).AsString;
			//lastLogonDays := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON_DAYS_AGO).AsInteger;
			
			fileBody := 'body.txt';
			if FileExists(fileBody) = true then
				DeleteFile(fileBody);
			
			Assign(f, fileBody);
			ReWrite(f);
	
			WriteLn(f, 'Hello ', fname, ',');
			WriteLn(f);
			WriteLn(f, 'Your administrative account ' + upn + ' was last used to logon on ' + lastLogon + ', that''s ' + IntToStr(notifyDays) + ' days ago.');
			WriteLn(f);
			WriteLn(f, 'The account will be disabled after ' + IntToStr(atDays) + ' days of inactity.');
			WriteLn(f, 'If you still need this administrative account for your work then make sure that you logon with this acount at least once a month to keep it active.');
			WriteLn(f);
			WriteLn(f, 'You have until ' + DateToStr(IncDay(Now(), preDays)) + ' to logon with this account before it will be disabled.');
			WriteLn(f);
			WriteLn(f, 'Regards,');
			WriteLn(f);
			WriteLn(f);
			WriteLn(f);
			WriteLn(f, 'NS AD Beheer');
			WriteLn(f, 'E-mail: nsg.hostingadbeheer@ns.nl');
			WriteLn(f, 'Phone: +31 88 6711674');
			
			Close(f);
	
			subject := 'Disable notification for ' + upn + ', ' + IntToStr(preDays) + ' day(s) left';
			WriteLn(IntToStr(recId) + '     ' + mailTo + '    ' + subject);
			
			// FOR TESTING UNCOMMENT THE NEXT LINE!
			//mailTo := 'perry.vandenhondel@ns.nl';
			if boolForReal = True then
				SendMail(mailTo, MAIL_FROM, fileBody, '', subject);
			
			// Next Record in the set
			rs.Next;
			
			WriteLn;
		end;
	end;
	rs.Free;
end;

	
	
procedure DoNotifyDelete(atDays: integer; preDays: integer);
var	
	qs: Ansistring;
	rs: TSQLQuery;
	recId: integer;
	fname: Ansistring;
	upn: Ansistring;
	mailTo: Ansistring;
	lastLogon: Ansistring;
	//lastLogonDays: integer;
	notifyDays: integer;
	fileBody: Ansistring;
	f: TextFile;
	subject: Ansistring;
begin
	notifyDays := atDays - preDays;

	WriteLn('-----------------------------------');
	WriteLn('DoNotifyDelete() Delete at ' + IntToStr(notifyDays) + ' days.');
	
	qs := 'SELECT ' + FLD_ATV_ID + ',' + FLD_ATV_UPN + ',' + FLD_ATV_MAIL + ',' + FLD_ATV_FNAME + ',' + FLD_ATV_REAL_LAST_LOGON + ',' + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + ' ';
	qs := qs + 'FROM ' + TBL_ATV + ' ';
	qs := qs + 'WHERE ' + FLD_ATV_IS_ACTIVE + '=1 '; // + IntToStr(VALID_ACTIVE) + ' ';
	qs := qs + 'AND ' + FLD_ATV_MAIL + ' IS NOT NULL ' ;
	qs := qs + 'AND ' + FLD_ATV_REAL_LAST_LOGON_DAYS_AGO + '=' + IntToStr(notifyDays);
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
			recId := rs.FieldByName(FLD_ATV_ID).AsInteger;
			fname := rs.FieldByName(FLD_ATV_FNAME).AsString;
			upn := rs.FieldByName(FLD_ATV_UPN).AsString;
			mailTo := rs.FieldByName(FLD_ATV_MAIL).AsString;
			lastLogon := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON).AsString;
			//lastLogonDays := rs.FieldByName(FLD_ATV_REAL_LAST_LOGON_DAYS_AGO).AsInteger;
			
			
			fileBody := 'body.txt';
			if FileExists(fileBody) = true then
				DeleteFile(fileBody);
			
			Assign(f, fileBody);
			ReWrite(f);
	
			WriteLn(f, 'Hello ', fname, ',');
			WriteLn(f);
			WriteLn(f, 'Your administrative account ' + upn + ' was last used to logon on ' + lastLogon + ', that''s ' + IntToStr(notifyDays) + ' days ago.');
			WriteLn(f);
			WriteLn(f, 'The account is now disabled an will be deleted after ' + IntToStr(atDays) + ' days of inactity.');
			WriteLn(f, 'If you still need this administrative account for your work then let your BAM enable the account using a request in Argusweb.');
			WriteLn(f, 'When the account is deleted it can''t be restored and needs to be created again.');
			WriteLn(f);
			WriteLn(f, 'You have until ' + DateToStr(IncDay(Now(), preDays)) + ' to make these arrangements.');
			WriteLn(f);
			WriteLn(f, 'Regards,');
			WriteLn(f);
			WriteLn(f);
			WriteLn(f);
			WriteLn(f, 'NS AD Beheer');
			WriteLn(f, 'E-mail: nsg.hostingadbeheer@ns.nl');
			WriteLn(f, 'Phone: +31 88 6711674');
			
			Close(f);
	
			subject := 'Delete notification for ' + upn + ', ' + IntToStr(preDays) + ' day(s) left';
			WriteLn(IntToStr(recId) + '     ' + mailTo + '    ' + subject);
			
			// FOR TESTING UNCOMMENT THE NEXT LINE!
			//mailTo := 'perry.vandenhondel@ns.nl';
			if boolForReal = True then
				SendMail(mailTo, MAIL_FROM, fileBody, '', subject);
			
			// Next Record in the set
			rs.Next;

			WriteLn;
		end;
	end;
	rs.Free;
	
end;



procedure ProgramUsage();
begin
	WriteLn('Usage:');
	WriteLn('  ' + ParamStr(0) + ' <option>');
	WriteLn;
	WriteLn('Options:');
	WriteLn('   --for-real     Send the mail to the to administrative accounts');
	WriteLn('   --help         This help information');
	WriteLn;
end;



procedure ProgInit();
begin
	ProgramUsage();
	
	if ParamStr(1) = '--help' then 
	begin
		
		Halt(0);
	end;

	if ParamStr(1) = '--for-real' then 
		boolForReal := True
	else
		boolForReal := False;
	
	DatabaseOpen();
end;



procedure ProgRun();
begin
	DoNotifyDisabled(90, 14);
	DoNotifyDisabled(90, 7);
	DoNotifyDisabled(90, 1);
	DoNotifyDelete(180, 14);
	DoNotifyDelete(180, 7);
	DoNotifyDelete(190, 1);
end;



procedure ProgDone();
begin
	DatabaseClose();
end;
	

	
begin
	ProgInit();
	ProgRun();
	ProgDone();
end. // End of program