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
	aam_action_new,					// ACTION 1: Create a new account
	aam_action_reset;				// ACTION 2: Reset a password
	
	
const
	STEP_MOD = 					27;
	MAX_USER_NAME_LENGTH = 		20;





procedure ProgTest();
//
//	Program testing procedure
//
begin
	WriteLn(IsAccountLockedOut('CN=NSA_Perry.vdHondel,OU=NSA,OU=Beheer,DC=prod,DC=ns,DC=nl'));
end; // of procedure ProgTest


procedure ProgInit();
begin
	DatabaseOpen();
end;


procedure ProgRun();
begin
	DoActionNew(ACTION_NEW);					// Create new accounts.
	DoActionReset(ACTION_RESET);				// Add new actions to the table AAD for password resets
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
