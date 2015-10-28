//
//	Admin Account Management -- Global definitions
//


unit aam_global;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	USupportLibrary,
	SysUtils;
	
const	
	ACTION_CREATE = 			1;		// Create a new account
	ACTION_RESET = 				2;		// Reset the password
	ACTION_SAME = 				3;		// Make the group membership the same as a reference account.
	ACTION_UNLOCK = 			4;		// Unlock an account
	ACTION_DISABLE = 			5;		// Disable an account
	ACTION_DELETE = 			6;		// Delete an account

	TBL_ACT = 				'account_action_act';
	FLD_ACT_ID = 			'act_id';
	FLD_ACT_ACTION_NR = 	'act_action_nr';
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
	
	
function FixStr(const s: string): string;
function FixNum(const s: string): string;
function TableActAdd(desc: string): integer;


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


function TableActAdd(desc: string): integer;
//
//	Insert a record in the table ACT
//
var
	qi: Ansistring;
begin
	qi := 'INSERT INTO ' + TBL_AAD + ' ';
	qi := qi + 'SET ';
	qi := qi + FLD_ACT_ACTION_NR + '=' + IntToStr(ACTION_RESET) + ',';
	qi := qi + FLD_ACT_DESC + '=' + FixStr(desc) + ';';
	RunQuery(qi);
	
	qs :='SELECT TOP 1 ' + FLD_ACT_ID + ' ';
	qs := qs + 'FROM ' + TBL_ACT + ' ';
	qs := qs + 'ORDER BY ' + FLD_ACT_RCD + ' DESC;'
	
	WriteLn(qs);
	
	
end; // of procedure TableAccountActionDetailInsert


end. // of unit aam_action_reset
