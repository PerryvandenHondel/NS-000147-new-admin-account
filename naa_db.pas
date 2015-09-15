{
	UPDATE LOOKUP ACCOUNT TABLE (ULAT)
	
	mysql> describe lookup_account;
	+-------------------+------------------+------+-----+-------------------+-----------------------------+
	| Field             | Type             | Null | Key | Default           | Extra                       |
	+-------------------+------------------+------+-----+-------------------+-----------------------------+
	| rec_id            | int(10) unsigned | NO   | PRI | NULL              | auto_increment              |
	| account_dn        | varchar(255)     | YES  |     | NULL              |                             |
	| account_domain    | varchar(16)      | YES  |     | NULL              |                             |
	| account_upn       | varchar(64)      | YES  |     | NULL              |                             |
	| account_netbios   | varchar(48)      | YES  |     | NULL              |                             |
	| account_object_id | varchar(64)      | YES  | UNI | NULL              |                             |
	| account_username  | varchar(32)      | YES  |     | NULL              |                             |
	| is_active         | bit(1)           | YES  |     | NULL              |                             |
	| rcd               | datetime         | NO   |     | CURRENT_TIMESTAMP |                             |
	| rlu               | datetime         | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
	+-------------------+------------------+------+-----+-------------------+-----------------------------+
	10 rows in set (0.00 sec)


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



unit naa_db;



{$MODE OBJFPC}



interface



uses
	SysUtils,
	USupportLibrary,
	ODBCConn,
	SqlDb;
	
	
	
const
	FNAME_DOMAIN = 			'domain.conf';
	DSN = 					'DSN_ADBEHEER_32';
	
	TBL_LA = 				'lookup_account';
	FLD_LA_ID = 			'rec_id';
	FLD_LA_DN = 			'account_dn';
	FLD_LA_DOM = 			'account_domain';
	FLD_LA_UPN = 			'account_upn';
	FLD_LA_NB = 			'account_netbios';
	FLD_LA_OID = 			'account_object_id';
	FLD_LA_UN = 			'account_username';
	FLD_LA_ISOBSO = 		'is_obsolete';
	FLD_LA_RCD = 			'rcd';
	FLD_LA_RLU = 			'rlu';


	
var
	gConnection: TODBCConnection;               // uses ODBCConn
	gTransaction: TSQLTransaction;  			// Uses SqlDB
	gstrNow: string;

	

function DoesObjectIdExist(strObjectId: string): boolean;
function EncloseSingleQuote(const s: string): string;
function FixNum(const s: string): string;
function FixStr(const s: string): string;
procedure DatabaseClose();
procedure DatabaseOpen();
procedure InsertRecord(strDomainNetbios: string; strDn: string; strSam: string; strObjectId: string; strUpn: string; strRcd: string; strRlu: string);
procedure MarkInactiveRecords(strDomainNetbios: string; strLastRecordUpdated: string);
procedure UpdateRecord(strDomainNetbios: string; strDn: string; strSam: string; strObjectId: string; strUpn: string; strRlu: string);



implementation



function EncloseSingleQuote(const s: string): string;
{
	Enclose the string s with single quotes: s > 's'.
}
var
	r: string;
begin
	if s[1] <> '''' then
		r := '''' + s
	else
		r := s;
		
	if r[Length(r)] <> '''' then
		r := r + '''';

	EncloseSingleQuote := r;
end; // of function EncloseSingleQuote



function FixStr(const s: string): string;
var
	r: string;
begin
	if Length(s) = 0 then
		r := 'Null'
	else
	begin
		// Replace a single quote (') to double quote's ('').
		r := StringReplace(s, '''', '''''', [rfIgnoreCase, rfReplaceAll]);
	
		r := EncloseSingleQuote(r);
	end;

	FixStr := r;
end; // of function FixStr


	
function FixNum(const s: string): string;
var
	r: string;
	i: integer;
	code: integer;
begin
	Val(s, i, code);
	i := 0;
	if code <> 0 then
		r := 'Null'
	else
		r := s;
		
	FixNum := r;
end; // of function FixNum



procedure DatabaseOpen();
{
	Open a DSN connection with name strDsnNew
}
begin
	WriteLn('DatabaseOpen(): Opening database using DSN: ',  DSN);
	
	gConnection := TODBCCOnnection.Create(nil);
	//query := TSQLQuery.Create(nil);
	gTransaction := TSQLTransaction.Create(nil);
	
	gConnection.DatabaseName := DSN; // Data Source Name (DSN)
	gConnection.Transaction := gTransaction;
end;



procedure DatabaseClose();
begin
	//WriteLn('DatabaseClose(): Closing database DSN: ', DSN);
	gTransaction.Free;
	gConnection.Free;
end;



function DoesObjectIdExist(strObjectId: string): boolean;
{
	Search for a record in the table with value strObjectId
	
	if found then return true
	if not found return false
}
var
	rs: TSQLQuery;							// Uses SqlDB
	q: Ansistring;
begin
	q := 'SELECT ' + FLD_LA_ID + ' ';
	q := q + 'FROM ' + TBL_LA + ' ';
	q := q + 'WHERE ' + FLD_LA_OID + '='+ FixStr(strObjectId) + ';';
	
	rs := TSQLQuery.Create(nil);
	rs.Database := gConnection;
	rs.PacketRecords := -1;
	rs.SQL.Text := q;
	rs.Open;

	//WriteLn('Run query: ' + q);
	
	DoesObjectIdExist := rs.Eof;
	{if rs.Eof = false then
		DoesObjectIdExist := false
	else
		DoesObjectIdExist := true;
	}	
	rs.Free;
end; // of function DoesObjectIdExist



procedure InsertRecord(strDomainNetbios: string; strDn: string; strSam: string; strObjectId: string; strUpn: string; strRcd: string; strRlu: string);
//InsertRecord(DOMAIN, DN, SAM, OBJECTID,UPN);
var
	qi: Ansistring;
	q: TSQLQuery;
	t: TSQLTransaction;
begin
	//WriteLn('INSERT NEW RECORD!');
	//WriteLn(strDomainNetbios);
	//WriteLn(strDn);
	//WriteLn(strSam);
	//WriteLn(strObjectId);
	
	qi := 'INSERT INTO ' + TBL_LA + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_LA_DN + '=' + FixStr(strDn) + ',';
	qi := qi + FLD_LA_DOM + '=' + FixStr(strDomainNetbios) + ',';
	qi := qi + FLD_LA_UPN + '=' + FixStr(LowerCase(strUpn)) + ',';
	qi := qi + FLD_LA_NB + '=' + FixStr(strDomainNetbios + '\\' + strSam) + ',';
	qi := qi + FLD_LA_OID + '=' + FixStr(strObjectId) + ',';
	qi := qi + FLD_LA_UN + '=' + FixStr(strSam) + ',';
	qi := qi + FLD_LA_ISOBSO + '=' + FixNum('0') + ',';
	qi := qi + FLD_LA_RCD + '=' + FixStr(strRcd) + ',';			// Record Creation Date
	qi := qi + FLD_LA_RLU + '=' + FixStr(strRlu) + ';';			// Record Last Update
	
	//WriteLn(qi);
	
	t := TSQLTransaction.Create(gConnection);
	t.Database := gConnection;
	q := TSQLQuery.Create(gConnection);
	q.Database := gConnection;
	q.Transaction := t;
	
	q.SQL.Text := qi;
	
	//gConnection.ExecuteDirect(q);
	q.ExecSQL;
	t.Commit;
end; // procedure InsertRecord



procedure UpdateRecord(strDomainNetbios: string; strDn: string; strSam: string; strObjectId: string; strUpn: string; strRlu: string);
//InsertRecord(DOMAIN, DN, SAM, OBJECTID,UPN);
var
	qu: Ansistring;
	q: TSQLQuery;
	t: TSQLTransaction;
begin
	//WriteLn('UPDATE RECORD!');
	//WriteLn(strDomainNetbios);
	//WriteLn(strDn);
	//WriteLn(strSam);
	//WriteLn(strObjectId);
	
	qu := 'UPDATE ' + TBL_LA + ' ';
	qu := qu + 'SET ';
	qu := qu + FLD_LA_DN + '=' + FixStr(strDn) + ',';
	qu := qu + FLD_LA_DOM + '=' + FixStr(strDomainNetbios) + ',';
	qu := qu + FLD_LA_UPN + '=' + FixStr(LowerCase(strUpn)) + ',';
	qu := qu + FLD_LA_NB + '=' + FixStr(strDomainNetbios + '\\' + strSam) + ',';
	qu := qu + FLD_LA_UN + '=' + FixStr(strSam) + ',';
	qu := qu + FLD_LA_ISOBSO + '=' + FixNum('0') + ',';
	qu := qu + FLD_LA_RLU + '=' + FixStr(strRlu) + ' ';
	qu := qu + 'WHERE ' + FLD_LA_OID + '=' + FixStr(strObjectId) + ';';
	
	//WriteLn(qu);
	
	t := TSQLTransaction.Create(gConnection);
	t.Database := gConnection;
	q := TSQLQuery.Create(gConnection);
	q.Database := gConnection;
	q.Transaction := t;
	
	q.SQL.Text := qu;
	
	//gConnection.ExecuteDirect(q);
	q.ExecSQL;
	t.Commit;
end; // procedure UpdateRecord


procedure MarkInactiveRecords(strDomainNetbios: string; strLastRecordUpdated: string);
{
	Change the is_active field to 0 when the last record update 
	for this domain strDomainNetbios was before strLastRecordUpdated.
	
	strDomainNetbios:		DOMAIN
	gstrLastRecordUpdated:	YYYY-MM-DD HH:MM:SS
}
var	
	qu: Ansistring;
	q: TSQLQuery;
	t: TSQLTransaction;
begin
	qu := 'UPDATE ' + TBL_LA + ' ';
	qu := qu + 'SET ';
	// Change the  Obsolete field to 1 when the field is not change during this batch.
	qu := qu + FLD_LA_ISOBSO + '=1 ';
	qu := qu + 'WHERE ' + FLD_LA_DOM + '=' + FixStr(strDomainNetbios) + ' ';
	qu := qu + 'AND ' + FLD_LA_RLU + '<' + FixStr(strLastRecordUpdated) + ';';
	
	//WriteLn('MarkInactiveRecords():');
	//WriteLn(qu);
	WriteLn('Mark inactive accounts for domain ' + strDomainNetbios);
	
	t := TSQLTransaction.Create(gConnection);
	t.Database := gConnection;
	q := TSQLQuery.Create(gConnection);
	q.Database := gConnection;
	q.Transaction := t;
	
	q.SQL.Text := qu;
	
	q.ExecSQL;
	t.Commit;
end; // of procedure MarkInactiveRecords



end.

// end of program
