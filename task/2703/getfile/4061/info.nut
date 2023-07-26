class Anw_AI extends AIInfo
{
  function GetAuthor()      { return "Adam N. Ward"; }
  function GetName()        { return "Anw_AI"; }
  function GetDescription() { return "An example AI created by following the tutorial at wiki.openttd.org"; }
  function GetVersion()     { return 1; }
  function GetDate()        { return "2009-03-05"; }
  function CreateInstance() { return "Anw_AI"; }
  function GetShortName()   { return "Adam"; }
}

RegisterAI(Anw_AI());

