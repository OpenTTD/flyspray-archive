/*	WmDOT-TEST-GS v.1, r.145 [2011-12-28],
 *		adapted from WmDOT (the AI) v.6, r.118 [2011-04-28]
 *	Copyright © 2011 by W. Minchin. For more info,
 *		please visit http://openttd-noai-wmdot.googlecode.com/
 */

//import("Queue.Binary_Heap","Binary_Heap",1);
//import("util.MinchinWeb","MinchinWeb",2);
 
 class WmDOT_GS_Test extends GSController 
{
	//	SETTINGS
	WmDOTv = 1;
	/*	Version number of GS
	 */	
	WmDOTr = 142;
	/*	Reversion number of GS
	 */
  
	function Start();
}


function WmDOT_GS_Test::Start()
{
	GSLog.Info("Welcome to WmDOT-Test, GameScript Edition, version " + WmDOTv + ", revision " + WmDOTr + " by W. Minchin.");
	GSLog.Info("Copyright © 2011 by W. Minchin. For more info, please visit http://www.tt-forums.net/viewtopic.php?f=65&t=53698")
	GSLog.Info(" ");

	GSLog.Info("Loading Libraries...");	
	
	GSRoad.SetCurrentRoadType(GSRoad.ROADTYPE_ROAD);
		//	Build normal road (no tram tracks)

//	Sleep(1);
//	local comp = GSCompanyMode(0);
	local exec = GSExecMode();

	local x = 50;
	local y = 40;
	GSViewport.ScrollTo(GSMap.GetTileIndex(x,y));
	GSRoad.BuildRoadDepot(GSMap.GetTileIndex(x,y), GSMap.GetTileIndex(x,y+1));
	for (local i=0; i<20; i++){
		for (local j=0; j<20; j++){
			GSRoad.BuildRoad(GSMap.GetTileIndex(x-1+i,y-1+j), GSMap.GetTileIndex(x-1+i,y+j));
		}
	}
	
	// with RemoveRoadFull
	local i = 10
	for (local j=0; j<20; j++){
		GSSign.BuildSign(GSMap.GetTileIndex(x-1+i,y-1+j),"Removed?");
		GSRoad.RemoveRoadFull(GSMap.GetTileIndex(x-1+i,y-1+j), GSMap.GetTileIndex(x-1+i,y+j));
	}
	// with RemoveRoad
	local i = 11
	for (local j=0; j<20; j++){
		GSSign.BuildSign(GSMap.GetTileIndex(x-1+i,y-1+j),"Removed?");
		GSRoad.RemoveRoad(GSMap.GetTileIndex(x-1+i,y-1+j), GSMap.GetTileIndex(x-1+i,y+j));
	}

	GSLog.Info("Road Building Complete");
	
	Sleep(1);
	local now;
	while (true) {
		now = GSDate.GetSystemTime();
		while (GSDate.GetSystemTime() - now < 10) {
			this.Sleep(30);
		}
	}
}