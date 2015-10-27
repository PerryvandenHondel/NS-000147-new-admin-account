//
//	Admin Account Management -- Password reset
//


unit aam_action_reset;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	SysUtils,
	USupportLibrary,
	ODBCConn,
	SqlDb,
	aam_global,
	aam_database;			// Link all database 
	
	
const
	VIEW_RESET = 			'account_action_view_reset';
	VIEW_RESET_ID = 		'arp_id';
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


procedure DoActionReset();


implementation


procedure DoActionReset();
begin
	WriteLn('DOACTIONRESET()');
	WriteLn(ACTION_RESET);
end; // of procedure DoActionReset


end. // of unit aam_action_reset
