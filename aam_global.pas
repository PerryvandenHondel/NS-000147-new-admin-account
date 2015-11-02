//
//	Admin Account Management -- Global definitions
//


unit aam_global;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	ODBCConn,
	USupportLibrary,
	SysUtils,
	SqlDb;
	
const	
	DSN = 					'DSN_ADBEHEER_32';
	VALID_ACTIVE = 			9;						// Only process records with _is_active = 9. 0 = inactive, 1 = active, 9 = development records

	ACTION_CREATE = 			1;		// Create a new account
	ACTION_RESET = 				2;		// Reset the password
	ACTION_SAME = 				3;		// Make the group membership the same as a reference account.
	ACTION_UNLOCK = 			4;		// Unlock an account
	ACTION_DISABLE = 			5;		// Disable an account
	ACTION_DELETE = 			6;		// Delete an account

	
	TBL_ACC	=				'account';
	FLD_ACC_ID = 			'account_id';
	FLD_ACC_FULLNAME = 		'full_name';
	FLD_ACC_FNAME = 		'first_name';
	FLD_ACC_MNAME = 		'middle_name';
	FLD_ACC_LNAME = 		'last_name';
	FLD_ACC_SUPP_ID = 		'ref_supplier_id';
	FLD_ACC_TIT_ID = 		'ref_title_id';
	FLD_ACC_MOBILE = 		'mobile';
	FLD_ACC_EMAIL = 		'email';
	FLD_ACC_RCD = 			'rcd';
	FLD_ACC_RLU = 			'rlu';
	
	TBL_ADT = 				'account_detail';
	FLD_ADT_ID = 			'account_detail_id';
	FLD_ADT_ACC_ID =		'ref_account_id';
	FLD_ADT_DOM_ID = 		'ref_domain_id';
	FLD_ADT_REQ_ID = 		'ref_requestor_id';
	FLD_ADT_UN = 			'user_name';
	FLD_ADT_DN = 			'dn';
	FLD_ADT_UPN = 			'upn';
	FLD_ADT_PW =			'init_pw';
	FLD_ADT_DO_UNLOCK =		'do_unlock';
	FLD_ADT_DO_RESET =		'do_reset';
	FLD_ADT_STATUS =		'status';
	FLD_ADT_RCD =			'rcd';
	FLD_ADT_RLU = 			'rlu';

	
	TBL_DOM = 				'account_domain';
	FLD_DOM_ID = 			'domain_id';
	FLD_DOM_UPN = 			'upn';
	FLD_DOM_NT = 			'domain_nt';
	FLD_DOM_OU = 			'org_unit';
	FLD_DOM_USE_OU = 		'use_supplier_ou';
	FLD_DOM_IS_ACTIVE = 	'is_active';
	FLD_DOM_RCD = 			'rcd';
	FLD_DOM_RLU = 			'rlu';
	
	
	VIE_CAA = 				'view_create_admin_account';
	FLD_CAA_DETAIL_ID = 	'account_detail_id';
	FLD_CAA_ACCOUNT_ID = 	'account_id';
	FLD_CAA_FULLNAME = 		'full_name';
	FLD_CAA_DN = 			'dn';
	FLD_CAA_USER_NAME = 	'user_name';
	FLD_CAA_FNAME = 		'first_name';
	FLD_CAA_MNAME = 		'middle_name';
	FLD_CAA_LNAME = 		'last_name';
	FLD_CAA_TITLE = 		'ref_title_id';
	FLD_CAA_MOBILE = 		'mobile';
	FLD_CAA_EMAIL = 		'email';
	FLD_CAA_INIT_PW = 		'init_pw';
	FLD_CAA_UPN = 			'upn';
	FLD_CAA_UPN_SUFF = 		'upn_suffix';
	FLD_CAA_DOM_ID = 		'ref_domain_id';
	FLD_CAA_NT = 			'domain_nt';
	FLD_CAA_OU = 			'org_unit';
	FLD_CAA_USE_SUPP_OU = 	'use_supplier_ou';
	FLD_CAA_SUPP_ID = 		'ref_supplier_id';
	FLD_CAA_SUPP_NAME = 	'name';
	FLD_CAA_STATUS = 	 	'status';

	//
	//	View definition 
	//
	//
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

	//
	//	AAD = Action Account Do table
	//	Table that contain all the actions that are to be done to perform an action. 
	//
	TBL_AAD =				'account_action_do_aad';
	FLD_AAD_ID = 			'aad_id';
	FLD_AAD_IS_ACTIVE = 	'aad_is_active';
	FLD_AAD_ACTION_ID =		'aad_action_id';
	FLD_AAD_ACTION_NR = 	'aad_action_nr';
	FLD_AAD_CMD = 			'aad_command';
	FLD_AAD_EL = 			'aad_error_level';
	//FLD_AAD_STATUS = 		'aad_status';
	FLD_AAD_RCD = 			'aad_rcd';
	FLD_AAD_RLU = 			'aad_rlu';
	

	
	{
	TBL_ACT = 				'account_action_act';
	FLD_ACT_ID = 			'act_id';
	FLD_ACT_ACTIVE = 		'act_is_active';
	FLD_ACT_ACTION_NR = 	'act_action_nr';
	FLD_ACT_DESC = 			'act_description';
	FLD_ACT_STATUS = 		'act_status';
	FLD_ACT_STEP_COUNT = 	'act_step_count';
	FLD_ACT_RCD = 			'act_rcd';
	FLD_ACT_RLU = 			'act_rlu';
	}
	


	
var	
	gConnection: TODBCConnection;               // uses ODBCConn
	gTransaction: TSQLTransaction;  			// Uses SqlDB
	
	
function FixStr(const s: string): string;
function FixNum(const s: string): string;
procedure DatabaseClose();
procedure DatabaseOpen();
procedure RunQuery(qryString: string);

implementation


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


procedure RunQuery(qryString: string);
//
//	Run a query 
//
var
	q: TSQLQuery;
	t: TSQLTransaction;
begin
	t := TSQLTransaction.Create(gConnection);
	t.Database := gConnection;
	q := TSQLQuery.Create(gConnection);
	q.Database := gConnection;
	q.Transaction := t;
	q.SQL.Text := qryString;
	q.ExecSQL;
	t.Commit;
end; // of procedure RunQuery


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


end. // of unit aam_action_reset
