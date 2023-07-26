class WmBasic extends AIInfo 
{
	function GetAuthor()        { return "William Minchin"; }
	function GetName()          { return "WmSea"; }
	function GetDescription()   { return "An AI that shows sea based industries."; }
	function GetVersion()       { return 1; }
	function MinVersionToLoad() { return 1; }
	function GetDate()          { return "2012-01-25"; }
	function GetShortName()     { return "WM01"; }
	function CreateInstance()   { return "WmBasic"; }
	function GetAPIVersion()    { return "1.2"; }

}

/* Tell the core we are an AI */
RegisterAI(WmBasic());