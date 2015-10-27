//
//	Admin Account Management -- Global definitions
//


unit aam_global;


{$MODE OBJFPC}
{$H+}			// Large string support


interface


uses
	SysUtils;
	
const	
	ACTION_CREATE = 			1;		// Create a new account
	ACTION_RESET = 				2;		// Reset the password
	ACTION_SAME = 				3;		// Make the group membership the same as a reference account.
	ACTION_UNLOCK = 			4;		// Unlock an account
	ACTION_DISABLE = 			5;		// Disable an account
	ACTION_DELETE = 			6;		// Delete an account


implementation


end. // of unit aam_action_reset
