

class TestAI extends AIController {
    stop = false;
    passenger_cargo_id=0;
    townArray = [];
    company=null;

    constructor() {
		this.company  = AICompany();
	}


    function Start();
    function Stop();
}

function TestAI::Start()
{
    this.Sleep(1);  
    if (!AICompany.SetCompanyName("TestAI")) {
        local i = 2;
        while (!AICompany.SetCompanyName("TestAI #" + i)) {
            i = i + 1;
        }
    }

    AISign.BuildSign(1010, "I am here");

    AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_TRAM);
    AIRoad.BuildRoad(3020, 3020 - AIMap.GetTileIndex(1,0));
    //can build this because there is now tram depot in place
    AIRoad.BuildRoadDepot(3020, 3020 - AIMap.GetTileIndex(1,0));

    AIRoad.BuildRoadDepot(3021, 3021 - AIMap.GetTileIndex(-1,0));



}

function TestAI::Stop()
{
    this.stop = true;
}

