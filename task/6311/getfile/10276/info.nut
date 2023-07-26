class TestAI extends AIInfo
 {
	function GetAuthor()      	{ return "Krinn"; }
	function GetName()        	{ return "TestAI"; }
	function GetDescription() 	{ return "A test"; }
	function GetVersion()     	{ return 1; }
	function GetDate()        	{ return "2014-11-08"; }
	function CreateInstance()	{ return "TestAI"; }
	function UseAsRandomAI()	{ return false; }
	function GetShortName()		{ return "TST1"; }
	function GetURL()			{ return ""; }
 }

 RegisterAI(TestAI());

