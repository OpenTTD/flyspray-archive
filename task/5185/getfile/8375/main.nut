import("Math.Vector", "Vector", 1);
import("Util.LibGrif", "LibGrif", 1);
import("AILib.EventBase", "MyEventBase", 2);
import("Pathfinder.road", "PathFinder", 3); // works
/* Syntax for import command:
		<arg 1> "<Library Category name>.<Library name>"
				Library Category and Name as specified by GetCategory() and GetName()
				in the library.nut file (not case sensitive)
		<arg 2> "<library name>" (name of library that will be use in your code,
				used to create the class instance
		<arg 3> <version> as specified by GetVersion() in library.nut
	Note that the directories holding the libraries are scanned only at game launch. */

class MTCAI extends AIController {
// Basic references
	base        = null;
	error       = null;
	cargo       = null;
	company     = null;
	industry    = null;
	map         = null;
	tile        = null;
	town        = null;
	road        = null;
	station     = null;
	baseStation = null;
	date        = null;

// Specific references
	vector      = null;
	aux         = null;
	rs          = null;

// Basic AI properties
	CompanyName = "";
	stop        = false; 

/* The following are quasi constants, and will be needed so often, 
		that they should always be easily accessible. */
	xMap             = null; // x size of the map
	yMap             = null; // y size of the map
	TownActivityList = null; // List with all towns in the game and our company's activities in it
	
	constructor() { // Gives access to (external) classes
		this.base = AIBase();
	/* From now on, all functions in the class AIBase can be accessed through
			base.<name of function> */
		this.error = AIError();
		this.cargo = AICargo();
		this.company = AICompany();
		this.industry = AIIndustry();
		this.map = AIMap();
		this.tile = AITile();
		this.town = AITown();
		this.road = AIRoad();
		this.station = AIStation();
		this.baseStation = AIBaseStation();
		this.date        = AIDate();
		
		// Give access to specific classes
		this.vector = Vector();
		this.aux = LibGrif.GriffinAuxiliary();
		this.rs = LibGrif.RoadSpace();

// Initialise quasi constants 
		this.xMap = this.map.GetMapSizeX();
		this.yMap = this.map.GetMapSizeY();
//		TownActivityList = array();
	}

	function Start();
	function Stop();
	function InitTownActivityList();
	function SetCompanyName();
	function GameLoop();

}
 
 
function MTCAI::Start() {
  print("\n");
  AILog.Info("New instance of MTCAI started.");
	InitTownActivityList();
	AILog.Info("Town activity list initialised.");
  SetCompanyName();
  
  //set a legal railtype. 
  local types = AIRailTypeList();
  AIRail.SetCurrentRailType(types.Begin());
       
	//Keep running. If Start() exits, the AI dies.
	while (!this.stop) {
		this.GameLoop();
		this.Sleep(1);
	}
}
 
function MTCAI::Stop() {
}

function MTCAI::InitTownActivityList() {
	// Init town activity list with biggest town first (only biggest 12)
	local CurDate, NumTowns, cnt;
	local NumTownEntries = 11;
	// The town entries are:
	// 0 = Name, 1 = Population, 2 = HouseCount, 3 = TileIndex, 4 = LastMonthPassProd
	// 5 = LastMonthPassSupp, 6 = LastMonthMailProd, 7 = LastMonthPassSupp, 8 = RoadLayout
	// 9 = Rating, 10 = date of this data
	
	CurDate = date.GetCurrentDate();
	NumTowns = aux.Min(12, town.GetTownCount());
	TownActivityList = array(NumTowns);
	for (cnt = 0; cnt < NumTowns; cnt++) {
		TownActivityList[cnt] = array(NumTownEntries);
		TownActivityList[cnt][0] = town.GetName(cnt);
		TownActivityList[cnt][1] = town.GetPopulation(cnt);
		TownActivityList[cnt][2] = town.GetHouseCount(cnt);
		TownActivityList[cnt][3] = town.GetLocation(cnt);
		TownActivityList[cnt][4] = town.GetLastMonthProduction(cnt, cargo.CC_PASSENGERS); // passengers
 		TownActivityList[cnt][5] = town.GetLastMonthTransported(cnt, cargo.CC_PASSENGERS);
		TownActivityList[cnt][6] = town.GetLastMonthProduction(cnt, cargo.CC_MAIL); // mail
		TownActivityList[cnt][7] = town.GetLastMonthSupplied(cnt, cargo.CC_MAIL);
		TownActivityList[cnt][8] = town.GetRoadLayout(cnt); // RoadLayout
		TownActivityList[cnt][9] = town.GetRating(cnt, company.COMPANY_SELF); // TownRating
		TownActivityList[cnt][10] = CurDate; // Current date
	}
}

function MTCAI::SetCompanyName() {
	local BaseName = "MTC ";
  if(!AICompany.SetName(BaseName)) {
    local i = 2;
    while(!AICompany.SetName(BaseName + " " + i)) {
      i = i + 1;
      if(i > 255) break;
     }
   }
   AICompany.SetPresidentName("Philip Deacon");
}

function MTCAI::GameLoop() {
	local t = this.GetTick();
	local BuildingTicks = [15, 30, 60];
	local bt;
	local DB = DEBUGGING_FUNCTIONS();
	local PCBS_test=[ 
			[ [302, 798], [275, 770] ], //0  Prunnden Castle - Sommerfield
			[ [181,  32], [173,  26] ], //10 superkronkel
										]; // Test routes for Griffin_test; * = end at left
	local PCBS=[]; // Potential Connection Bus Stops
	local PCNum=0; // route number to build

	local	vStart, vEnd; // Vectors of start and end of route
	local vTest = Vector();
	local tmp; // general temporary variable
	local res; // temporary result variable
	local RouteStart, RouteEnd; // indices of start and end of route
	local RouteStartXY, RouteEndXY; // co-ordinates of start and end of route
	local StatDirStartXY, StatDirEndXY; // entry of start and end stations

	road.SetCurrentRoadType(road.ROADTYPE_ROAD);
// Set RoadType to Road (MUST be defined, invalid by default)

	switch(t) {
	case BuildingTicks[0]: // Seek best town and check whether it's big enough
		print ("\n"); print ("--- Building tick " + BuildingTicks[0] + "---");
		print ("Seeking largest town without Municipal Transport Company");
		break;

	case BuildingTicks[1]:
		print("\n"); print ("--- Building tick " + BuildingTicks[1] + "---");
		print ("Doing nothing");
		break;

	case BuildingTicks[2]: // Remove road pieces from BuildingTicks[0]
		print("\n"); print ("--- Building tick " + BuildingTicks[2] + "---");
		print ("Doing nothing");
		break;

	default:
		// not a tick in BuildingTicks[]
	} /* End of for loop for BuildingTicks. */
}



class DEBUGGING_FUNCTIONS {
/* Class for debugging functions. */
	error = AIError();
	road = AIRoad();
	
	function _tostring() {
		/* called if this class is used as string */
		return("DEBUGGING_FUNCTIONS");
	}

	function printErrIf(result, ...) {
	/* Prints an error is result is false */
	
		local userErrMsg; // vargv[0] if supplied
		local errCat; // vargv[1] if supplied
		
		if (!result) {
	  	if (vargc > 0) userErrMsg = " " + vargv[0]; else userErrMsg = "";
			if (vargc > 1) {
				if (vargv[1]) {
					errCat = " from category: " + error.GetErrorCategory();
				}
				else {
					errCat = "";
				}
			}
			print("Error"+userErrMsg+": "+error.GetLastErrorString()+errCat);
		}
	}
	
	function printBuildRoadErors() {
		print (error.ERR_ALREADY_BUILT + " ERR_ALREADY_BUILT");
		print (error.ERR_LAND_SLOPED_WRONG + " ERR_LAND_SLOPED_WRONG");
		print (error.ERR_AREA_NOT_CLEAR + " ERR_AREA_NOT_CLEAR");
		print (road.ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS+ " ERR_ROAD_ONE_WAY_ROADS_CANNOT_HAVE_JUNCTIONS");
		print (road.ERR_ROAD_WORKS_IN_PROGRESS + " ERR_ROAD_WORKS_IN_PROGRESS");
		print (error.ERR_VEHICLE_IN_THE_WAY + " ERR_VEHICLE_IN_THE_WAY");
	}
}
