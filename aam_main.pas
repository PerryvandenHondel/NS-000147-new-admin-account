{
	
	Admin Account Management (AAM)
	
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

		
	FLOW
		ProgInit
			DatabaseOpen
		ProgRun
			FindRecordToCompleteMissingField; 0 > 10
			Check
		ProgDone
			DatabaseClose
		
}


program AdminAccountManagement;


{$MODE OBJFPC}			
{$LONGSTRINGS ON}		// Compile all strings as Ansistrings


uses
	Crt,
	Classes, 
	DateUtils,						// For SecondsBetween
	Process, 
	SysUtils,
	USupportLibrary,
	SqlDB,
	aam_global,
	aam_action01new,				// ACTION 1: Create a new account
	aam_action02reset,				// ACTION 2: Reset a password
	aam_action03same;				// Action 03: Make the groups the same of an account
	
const
	STEP_MOD = 					27;
	MAX_USER_NAME_LENGTH = 		20;





procedure ProgTest();
//
//	Program testing procedure
//
var
	i: integer;
begin
	//WriteLn(IsAccountLockedOut('CN=NSA_Perry.vdHondel,OU=NSA,OU=Beheer,DC=prod,DC=ns,DC=nl'));
	//WriteLn(DoesAccountExist('CN=NSA_Perry.vdHondel,OU=NSA,OU=Beheer,DC=prod,DC=ns,DC=nl'));
	//WriteLn(DoesAccountExist('CN=KPN_Clint.Eastwood,OU=KPN,OU=Beheer,DC=test,DC=ns,DC=nl'));
	//for i := 1 to 100 do
	//begin
	//	WriteLn(GenerateUniqueActionNumber(2));
	//end;
	//TableAadCheckNew('e683e4c327ce4486dc06ef934589668ebf919b00', 994);
end; // of procedure ProgTest


procedure ProgInit();
begin
	DatabaseOpen();
end;


procedure ProgRun();
begin
	DoActionNew(ACTION_NEW);					// Create new accounts.
	DoActionReset(ACTION_RESET);				// Add new actions to the table AAD for password resets
	DoActionSame(ACTION_SAME);					// Make the groups the same from source to target account
end;


procedure ProgDone();
begin
	DatabaseClose();
end;
	
	
begin
	ProgInit();
	//ProgTest();
	ProgRun();
	ProgDone();
end. // of program
