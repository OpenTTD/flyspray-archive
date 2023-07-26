class Gamma extends AIInfo 
{
  function GetAuthor()        { return "OTTDmaster"; }
  function GetName()          { return "Gamma"; }
  function GetDescription()   { return "A modified version of the RoadPathFinder demo AI"; }
  function GetVersion()       { return 1; }
  function MinVersionToLoad() { return 1; }
  function GetDate()          { return "2011-4-28"; }
  function GetShortName()     { return "OM_G"; }
  function CreateInstance()   { return "Gamma"; }
  function GetAPIVersion()    { return "1.1"; }
}

/* Tell the core we are an AI */
RegisterAI(Gamma());
