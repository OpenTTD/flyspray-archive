/*	WmBasic v.1  r.1
 *	Created by William Minchin		w_minchin@hotmail.com
 *		See http://openttd-noai-wmdot.googlecode.com/
 */
 
//	require("GNU_FDL.nut");
// import("util.wmarray", "WmArray", 1);
import("util.MinchinWeb", "MetaLib", 3);
import("util.SuperLib", "SuperLib", 19);

class WmBasic extends AIController 
{
	//	SETTINGS
	WmBasicv = 1;
	/*	Version number of AI
	 */	
	WmBasicr = 4;
	/*	Reversion number of AI
	 */
	 
	SleepLength = 5000;
	/*	Controls how many ticks the AI sleeps between iterations.
	 */
	 
	//	END SETTINGS
  
  function Start();
}

function WmBasic::Start()
{
	AILog.Info("Welcome to WmBasic, version " + WmBasicv + ", revision " + WmBasicr + " by William Minchin.");
	AILog.Info("Copyright © 2011 by William Minchin. For more info, please visit http://blog.minchin.ca")
	AILog.Info(" ");
	
	local v = AIController.GetVersion();
	local Revision = v & 0x0007FFFF;
	AILog.Info("  OpenTTD revision: " + Revision);
	
	///	Check that there is oil on the map; put to sleep if not
	//	Actually this checks for industries that include docks
	local MyIndustries = AIIndustryList();
	MyIndustries.Valuate(AIIndustry.HasDock);
	MyIndustries.KeepValue(true.tointeger());
	
	AILog.Info("Keep " + MyIndustries.Count() + " industries.");

	if (MyIndustries.Count() > 0) {
		//	Cycle through MyIndustries and come up with the list of cargos they produce
		local Produced;
		local MyCargos = [];
		MyIndustries.Valuate(SuperLib.Helper.ItemValuator);
		foreach (IndustryNo in MyIndustries) {
			Produced = AICargoList_IndustryProducing(IndustryNo);
			Produced.Valuate(SuperLib.Helper.ItemValuator);
			AILog.Info("Industry " + IndustryNo + " produces " + Produced.Count() + " cargos.   (" + AIIndustry.GetName(IndustryNo) + ")  Dock at " + MetaLib.Array.ToStringTiles1D([AIIndustry.GetDockLocation(IndustryNo)], false) + " : " + MetaLib.Array.ToStringTiles1D([AIIndustry.GetDockLocation(MetaLib.Industry.GetIndustryID(IndustryNo))], false));
			foreach (CargoNo in Produced) {
				if (MetaLib.Array.ContainedIn1D(MyCargos, CargoNo) == false) {
					MyCargos.push(CargoNo);
					AILog.Info("Adding Cargo № " + CargoNo + " (" + AICargo.GetCargoLabel(CargoNo) + ")");
				}
			}
		}
	}
	
	// Keep us going forever
	while (true) {
		AILog.Info("Help! I haven't done anything yet and I'm already at tick " + this.GetTick());
		AILog.Info("-----------------------------------------------------");
		AILog.Info(" ");

		this.Sleep(SleepLength);
	}
}