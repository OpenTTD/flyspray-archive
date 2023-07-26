class Anw_AI extends AIController
{
  function Start();
}

function Anw_AI::Start()
{
  while(true)
  {
    AILog.Info("ANW says hi!\n");
    this.Sleep(50);
  }
}

