class TestAI extends AIInfo {
  function GetAuthor()      { return "TestAI"; }
  function GetName()        { return "TestAI"; }
  function GetDescription() { return "An example AI by following the tutorial at http://wiki.openttd.org/"; }
  function GetVersion()     { return 1; }
  function GetDate()        { return "2007-03-17"; }
  function CreateInstance() { return "TestAI"; }
}

/* Tell the core we are an AI */
RegisterAI(TestAI());