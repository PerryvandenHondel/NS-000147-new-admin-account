{
	
	New Admin Account (NAA)
	
	PROCEDURES AND FUNCTIONS
	
		procedure ProcessDomain
		procedure MarkInactiveRecords
		procedure UpdateRecord
		procedure InsertRecord
		function DoesObjectIdExist
		procedure DatabaseOpen
		procedure DatabaseClose
		function FixNum
		function FixStr
		function EncloseSingleQuote
		procedure ProgInit
		procedure ProgRun
		procedure ProgDone

}



program NewAdminAccount;



{$MODE OBJFPC}



uses
	Crt,
	Classes, 
	DateUtils,						// For SecondsBetween
	Process, 
	SysUtils,
	USupportLibrary,
	naa_db;
	//UTextFile;
	
	
	
const
	FNAME_DOMAIN = 			'domain.conf';
	//DSN = 					'DSN_ADBEHEER_32';
	
	//TBL_LA = 				'lookup_account';
	//FLD_LA_ID = 			'rec_id';
//	FLD_LA_DN = 			'account_dn';
	//FLD_LA_DOM = 			'account_domain';
	//FLD_LA_UPN = 			'account_upn';
	//FLD_LA_NB = 			'account_netbios';
	//FLD_LA_OID = 			'account_object_id';
	//FLD_LA_UN = 			'account_username';
	//FLD_LA_ACTIVE = 		'is_active';
	//FLD_LA_RCD = 			'rcd';
	//FLD_LA_RLU = 			'rlu';
	
	STEP_MOD = 				27;


//var
	//gConnection: TODBCConnection;               // uses ODBCConn
	//gTransaction: TSQLTransaction;  			// Uses SqlDB
	//gstrNow: string;
	
	
{

procedure ProcessDomain(strRootDn: string; strDomainNetbios: string);
var
	f: TextFile;
	p: TProcess;
	c: string;
	fn: string;
	r: integer;
	strLine: Ansistring;
	arrLine: TStringArray;
	intLine: integer;
begin
	WriteLn;
	WriteLn('PROCESSDOMAIN(' + strDomainNetbios + ')');
	//WriteLn('  RootDse: ', strRootDn, '   NetBIOS: ', strDomainNetbios);
	
	// Set the date time of the update for the specific domain.
	gstrNow := DateTimeToStr(Now);
	//WriteLn('Set current update date time to ' + gstrNow + ' for domain ' + strDomainNetbios);
	
	// Buil the file name for the domain export.
	fn := strDomainNetbios + '.tmp';
	
	// Build the command line.
	// adfind -b dc=test,dc=ns,dc=nl -f "(&(objectCategory=Person)(objectClass=User))" sAMAccountName ObjectSid userPrincipalName -csv -nocsvq > TEST.tmp
	c := 'adfind.exe ';
	c := c + '-b ' + strRootDn + ' ';
	c := c + '-f "(&(objectCategory=Person)(objectClass=User))" ';
	c := c + 'sAMAccountName ObjectSid userPrincipalName ';
	c := c + '-csv -nocsvq -csvdelim "|" ';
	c := c + '>' + fn;
	
	WriteLn('Running: ' + c);
	
	// Setup the process to be executed.
	p := TProcess.Create(nil);
	p.Executable := 'cmd.exe'; 
	p.Parameters.Add('/c ' + c);
	//p.Options := [poWaitOnExit];
	p.Options := [poWaitOnExit, poUsePipes];
	
	WriteLn('Exporting all account info from domain '+ strDomainNetbios + ', please wait...');
	
	// Run the sub process.
	p.Execute;
	
	// Get the return code from the process.
	r := p.ExitStatus;
	
	if r = 0 then
	begin
		WriteLn('Importing ' + fn + ' into table ' + TBL_LA + ' for domain ' + strDomainNetbios + ', please wait...');
		
		intLine := 0;
		
		AssignFile(f, fn);}
		{I+}
		{
		try 
			Reset(f);
			repeat
				// Process  every line in the export tmp file.
				ReadLn(f, strLine);
				Inc(intLine);
				if (Length(strLine) > 0) and (intLine > 1) then
				begin
					// Only process valid lines with content.
					arrLine := SplitString(strLine, '|');
					//ProcessDomain(FNAME_ACCOUNT, arrLine[0], arrLine[1] + ',' + arrLine[0], arrLine[2]);
					// Display processed line, remove for speedier processing.
					//WriteLn(intLine:6, ' LINE: ', strLine);
					//WriteLn('   - DN:                ', arrLine[0]);
					//WriteLn('   - sAMAccountName:    ', arrLine[1]);
					//WriteLn('   - ObjectSid:         ', arrLine[2]);
					//WriteLn('   - userPrincipalName: ', arrLine[3]);
					//WriteLn;
					
					if DoesObjectIdExist(arrLine[2]) = true then
						InsertRecord(strDomainNetbios, arrLine[0], arrLine[1], arrLine[2], arrLine[3], gstrNow, gstrNow)
					else
						UpdateRecord(strDomainNetbios, arrLine[0], arrLine[1], arrLine[2], arrLine[3], gstrNow);
					
					WriteMod(intLine, STEP_MOD)
					
				end;
			until Eof(f);
			CloseFile(f);
		except
			on E: EInOutError do
				WriteLn('File ', fn, ' handeling error occurred, Details: ', E.ClassName, '/', E.Message);
		end;
	end
	else
	begin
		WriteLn('ERROR ', r, ' while exporting accounts from domain ' + strDomainNetbios);
	end;
	
	WriteLn;
	//WriteLn('Set inactive all records of ' + strDomainNetbios + ' where RLU = ' + gstrNow);
	MarkInactiveRecords(strDomainNetbios, gstrNow);
end; // of procedure ProcessDomain
}


procedure ProgInit();
begin
	DatabaseOpen();
end;



procedure ProgRun();
var
	qs: Ansistring;
begin
	
	qs := 'SELECT ';
	qs := qs + FLD_ACC_ID + ',';
	qs := qs + FLD_ACC_FULLNAME + ',';
	qs := qs + FLD_ACC_FNAME + ',';
	qs := qs + FLD_ACC_MNAME + ',';
	qs := qs + FLD_ACC_LNAME + ',';
	qs := qs + FLD_ACC_FNAME + ',';
	qs := qs + FLD_ACC_FNAME + ',';
	
	
	WriteLn(qs);

{	
	SELECT
account.account_id,
account.full_name,
account.first_name,
account.middle_name,
account.last_name,
account.ref_supplier_id,
account_supplier.`name`,
account.ref_title_id,
account_detail.ref_account_id,
account_detail.ref_domain_id,
account_domain.upn,
account_domain.domain_nt,
account_domain.org_unit,
account_domain.use_supplier_ou,
account_detail.status_is_created
FROM
account
INNER JOIN account_detail ON account_detail.account_detail_id = account.account_id
INNER JOIN account_supplier ON account.ref_supplier_id = account_supplier.supplier_id
INNER JOIN account_domain ON account_domain.domain_id = account_detail.ref_domain_id
WHERE
account_detail.status_is_created = 0
}	
end;



procedure ProgDone();
begin
	DatabaseClose();
end;

	
	
begin
	ProgInit();
	ProgRun();
	ProgDone();
end.

// end of program
