//
//	PROGRAM
//		NAA
//
//	SUB
//		Sync group membership
//
//


unit naa_group;


{$MODE OBJFPC}
{$LONGSTRINGS ON}		// Compile all strings as Ansistrings


interface


uses
	naa_db,
	naa_main,
	SysUtils,
	USupportLibrary,
	ODBCConn,
	SqlDb;
	
	
{	
const
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

	TBL_ACT = 				'account_action_act';
	FLD_ACT_ID = 			'act_id';
	FLD_ACT_DESC = 			'act_description';
	FLD_ACT_RCD = 			'act_rcd';
	FLD_ACT_RLU = 			'act_rlu';
	
	TBL_AAD =				'account_action_detail_aad';
	FLD_AAD_ID = 			'aad_id';
	FLD_AAD_ACT_ID =		'aad_act_id';
	FLD_AAD_CMD = 			'aad_command';
	FLD_AAD_EL = 			'aad_error_level';
	FLD_AAD_RCD = 			'aad_rcd';
	FLD_AAD_RLU = 			'aad_rlu';
	
	
var
	gConnection: TODBCConnection;               // uses ODBCConn
	gTransaction: TSQLTransaction;  			// Uses SqlDB
	
	

//function DoesObjectIdExist(strObjectId: string): boolean;
function FixNum(const s: string): string;
function FixStr(const s: string): string;
procedure DatabaseClose();
procedure DatabaseOpen();
//procedure InsertRecord(strDomainNetbios: string; strDn: string; strSam: string; strObjectId: string; strUpn: string; strRcd: string; strRlu: string);
//procedure MarkInactiveRecords(strDomainNetbios: string; strLastRecordUpdated: string);
//procedure UpdateRecord(strDomainNetbios: string; strDn: string; strSam: string; strObjectId: string; strUpn: string; strRlu: string);

}

implementation



end.  // of unit naa_group
