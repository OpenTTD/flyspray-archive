/*	WmDOT-TEST-GS v.1, r.145 [2011-12-28],
 *		adapted from WmDOT v.6  r.116 [2011-04-27]
 *	Copyright © 2011 by W. Minchin. For more info,
 *		please visit http://openttd-noai-wmdot.googlecode.com/
 *		OR  http://www.tt-forums.net/viewtopic.php?f=65&t=53698
 */

class WmDOT_GS_Test extends GSInfo 
{
	function GetAuthor()        { return "W. Minchin"; }
	function GetName()          { return "WmDOT-Test-GS"; }
	function GetDescription()   { return "An GameScript that tests building and removal of roadtiles by MinchinWeb"; }
	function GetVersion()       { return 1; }
	function MinVersionToLoad() { return 1; }
	function GetDate()          { return "2011-12-28"; }
	function GetShortName()     { return "TEST"; }	//	0x576D7D7E
	function CreateInstance()   { return "WmDOT"; }
	function GetAPIVersion()    { return "1.2"; }
	function UseAsRandomGS()	{ return true; }
	function GetURL()			{ return "http://www.tt-forums.net/viewtopic.php?f=65&t=53698"; }
//	function GetURL()			{ return "http://code.google.com/p/openttd-noai-wmdot/issues/"; }
	function GetEmail()			{ return "w_minchin@hotmail.com"}

	function CreateInstance()	{ return "WmDOT_GS_Test"; }
}

/* Tell the core we are an GS */
RegisterGS(WmDOT_GS_Test());

//	Requires:
//		SuperLib, v.16
//		MinchinWeb's MetaLib, v.2
//		Queue.Fibonacci_Heap v.2