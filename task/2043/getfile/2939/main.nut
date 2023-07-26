class MyNewAI extends AIController {
    stop = false;

    function Start();
    function Stop();
}

function MyNewAI::Start()
{
    this.Sleep(1);  
    if (!AICompany.SetCompanyName("MyNewAI")) {
        local i = 2;
        while (!AICompany.SetCompanyName("MyNewAI #" + i)) {
            i = i + 1;
        }
    }

    while (!this.stop) {
        //AILog.Info("I am a very new AI with a ticker called MyNewAI and I am at tick " + this.GetTick());
        
        local townlist;
        townlist = AITownList();
        townlist.Valuate(AITown.GetPopulation);
        townlist.KeepAboveValue(500);

        for (local i = townlist.Begin(); townlist.HasNext(); i = townlist.Next()) {
            AILog.Info("Town name" + AITown.GetName(i));
            local tl2=AITileList();
			/* for our first town, be sure to use a town without a station */
			tl2.AddRectangle(AITown.GetLocation(i) + AIMap.GetTileIndex(-15,-15),
			   				AITown.GetLocation(i) + AIMap.GetTileIndex(15,15));
                for (local j = tl2.Begin(); tl2.HasNext(); j = tl2.Next()) {
                    AISign.BuildSign(j,  AITown.GetName(i));
                }
        
        }
        
        this.Sleep(10);
    }
}

function MyNewAI::Stop()
{
    this.stop = true;
}