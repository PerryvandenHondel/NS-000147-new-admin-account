//
//	PROGRAM
//		NAA
//
//	SUB
//		Read AD and fill database tables with the latest account information
//
//


unit naa_read_ad;


{$MODE OBJFPC}
{$LONGSTRINGS ON}		// Compile all strings as Ansistrings


interface


uses
	naa_db,
	SysUtils,
	USupportLibrary,
	ODBCConn,
	SqlDb;
	

const
	TBL_ADM =				'account_domain_adm';
	FLD_ADM_ID = 			'adm_id';
	FLD_ADM_UPN_SUFF = 		'adm_upn_suffix';
	FLD_ADM_DOM_NT = 		'adm_domain_nt';
	FLD_ADM_IS_ACTIVE = 	'adm_is_active';
	FLD_ADM_OU = 			'adm_org_unit';
	
	
procedure ProcessAllAds();


implementation


procedure ProcessAllAds();
var
	qs: string;
begin
	WriteLn('ProcessAllAds()');
	
	qs := 'SELECT ' + FLD_ADM_ID + ',' + FLD_ADM_DOM_NT + ',' + FLD_ADM_OU + ' ';
	qs := qs + 'FROM ' + TBL_ADM + ' ';
	qs := qs + 'WHERE ' + FLD_ADM_IS_ACTIVE + '=1';
	qs := qs + ';';

	WriteLn(qs);
end;



end.  // of unit naa_group
