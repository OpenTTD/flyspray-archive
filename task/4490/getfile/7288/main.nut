/*	WmDOT v.1  r.4
 *	Created by William Minchin		w_minchin@hotmail.com		http://blog.minchin.ca
 */
class WmDOT extends AIController 
{
	//	SETTINGS
	WmDOTv = 1;
	/*	Version number of AI
	 */	
	WmDOTr = 4;
	/*	Reversion number of AI
	 */
	 
	SingleLetterOdds = 7;
	/*	Control on single letter companies.  Set this value higher to increase
	 *	the chances of a single letter DOT name (eg. 'CDOT').		
	 */
	 
	MaxAtlasSize = 99;		//  UNUSED
	/*	This sets the maximum number of towns that will printed to the debug
	 *	screen.
	 */
	 
	SleepLength = 50;
	/*	Controls how many ticks the AI sleeps between iterations.
	 */
	 
	LongSleepLength = 1850;
	/*	Controls how many ticks the AI sleeps if there's nothing to do (about 3 months).
	 */
	//	END SETTINGS
  
  function Start();
}

/*	TO DO
	- figure out how to get the version number to show up in Start()
 */

function WmDOT::Start()
{
//	AILog.Info("Welcome to WmDOT, version " + GetVersion() + ", revision " + WmDOTr + " by " + GetAuthor() + ".");
	AILog.Info("Welcome to WmDOT, version " + WmDOTv + ", revision " + WmDOTr + " by William Minchin.");
	AILog.Info("Copyright © 2011 by William Minchin. For more info, please visit http://blog.minchin.ca")
	AILog.Info(" ");
	
/*	NameWmDOT();
	BuildWmHQ();
//	GenerateAtlas();
	local WmAtlas = [];
	local WmTownArray = [];
*/	
	// Keep us going forever
	while (true) {
/*		WmTownArray = GenerateTownList();
		while ( WmTownArray == -1 ) {
			AILog.Warning("     No towns above population threshold. Please lower. Will sleep for ~3 monthsand try again.");
			this.Sleep(LongSleepLength);			// If there's no towns to join up, sleep for three months...
			WmTownArray = GenerateTownList();
		}
		WmAtlas = GenerateAtlas(WmTownArray);
*/
		AILog.Info("Help! I haven't done anything yet and I'm already at tick " + this.GetTick());
		AILog.Info("----------------------------------------------------------------");
		AILog.Info(" ");
/*		local i = this.GetTick();
		i = i % SleepLength;
		this.Sleep(50 - i);
*/
		this.Sleep(50);
	}
}


function WmDOT::NameWmDOT()
{
	/*	This function names the company based on the AI settings.  If the names
	 *	given by the settings is already taken, a default ('WmDOT', for
	 *	'William Department of Transportation') is used.  Failing that, a
	 *	second default ('ZxDOT', chosed becuase I thought it looked cool) is
	 *	tried.  Failing that, a random one or two letter prefix is chosen and
	 *	added to DOT until and unused name is found.
	 */
		
	AILog.Info("Naming Company...");
	
	local tick;
	tick = this.GetTick();
	
	// Get Name Settings and Build Name String
	local Name2 = WmDOT.GetSetting("DOT_name2");
	local NewName = "";
	AILog.Info("     Name settings are " + WmDOT.GetSetting("DOT_name1") + " " + WmDOT.GetSetting("DOT_name2") + ".");
	switch (WmDOT.GetSetting("DOT_name1"))
	{
		case 0: 
			NewName = "Wm";
			break;
		case 1: 
			NewName = "A";
			break;
		case 2: 
			NewName = "B";
			break;
		case 3: 
			NewName = "C";
			break;
		case 4: 
			NewName = "D";
			break;
		case 5: 
			NewName = "E";
			break;
		case 6: 
			NewName = "F";
			break;
		case 7: 
			NewName = "G";
			break;
		case 8: 
			NewName = "H";
			break;
		case 9: 
			NewName = "I";
			break;
		case 10: 
			NewName = "J";
			break;
		case 11: 
			NewName = "K";
			break;
		case 12: 
			NewName = "L";
			break;
		case 13: 
			NewName = "M";
			break;
		case 14: 
			NewName = "N";
			break;
		case 15: 
			NewName = "O";
			break;
		case 16: 
			NewName = "P";
			break;
		case 17: 
			NewName = "Q";
			break;
		case 18: 
			NewName = "R";
			break;
		case 19: 
			NewName = "S";
			break;
		case 20: 
			NewName = "T";
			break;
		case 21: 
			NewName = "U";
			break;
		case 22: 
			NewName = "V";
			break;
		case 23: 
			NewName = "W";
			break;
		case 24: 
			NewName = "X";
			break;
		case 25: 
			NewName = "Y";
			break;
		case 26: 
			NewName = "Z";
			break;
		default:
			AILog.Warning("          Unexpected DOT_name1 parameter");
			break;
	}
	switch (WmDOT.GetSetting("DOT_name2"))
	{
		case 0: 
			break;
		case 1: 
			NewName = NewName + "a";
			break;
		case 2: 
			NewName = NewName + "b";
			break;
		case 3: 
			NewName = NewName + "c";
			break;
		case 4: 
			NewName = NewName + "d";
			break;
		case 5: 
			NewName = NewName + "e";
			break;
		case 6: 
			NewName = NewName + "f";
			break;
		case 7: 
			NewName = NewName + "g";
			break;
		case 8: 
			NewName = NewName + "h";
			break;
		case 9: 
			NewName = NewName + "i";
			break;
		case 10: 
			NewName = NewName + "j";
			break;
		case 11: 
			NewName = NewName + "k";
			break;
		case 12: 
			NewName = NewName + "l";
			break;
		case 13: 
			NewName = NewName + "m";
			break;
		case 14: 
			NewName = NewName + "n";
			break;
		case 15: 
			NewName = NewName + "o";
			break;
		case 16: 
			NewName = NewName + "p";
			break;
		case 17: 
			NewName = NewName + "q";
			break;
		case 18: 
			NewName = NewName + "r";
			break;
		case 19: 
			NewName = NewName + "s";
			break;
		case 20: 
			NewName = NewName + "t";
			break;
		case 21: 
			NewName = NewName + "u";
			break;
		case 22: 
			NewName = NewName + "v";
			break;
		case 23: 
			NewName = NewName + "w";
			break;
		case 24: 
			NewName = NewName + "x";
			break;
		case 25: 
			NewName = NewName + "y";
			break;
		case 26: 
			NewName = NewName + "z";
			break;
		default:
			AILog.Warning("          Unexpected DOT_name2 parameter");
			break;
	}
	NewName = NewName + "DOT"
	if (!AICompany.SetName(NewName))
	{
		AILog.Info("     Setting Company Name failed. Trying default...");
		if (!AICompany.SetName("WmDOT"))
		{
			AILog.Info("     Default failed. Trying backup...")
			if (!AICompany.SetName("ZxDOT"))
			{
				AILog.Info("     Backup failed. Trying random...")
				do
				{
					local c;
					c = AIBase.RandRange(26) + 65;
					NewName = c.tochar();
					c = AIBase.RandRange(26 + SingleLetterOdds) + 97;
					if (c <= 122)
					{
						NewName = NewName + c.tochar();
					}
					NewName = NewName + "DOT";					
				} while (!AICompany.SetName(NewName))
			}
		}
	}
	tick = this.GetTick() - tick;
	AILog.Info("     Company named " + AICompany.GetName(AICompany.COMPANY_SELF) + ". Took " + tick + " tick(s).");
}

function WmDOT::GenerateAtlas(WmTownArray)
{
   /*	Everyone loves the Atlas, right?  Well, the guys at the local DOT
	*	figure it's pretty much essential for their work, so it's one of the
	*	first things they do when they set up shop.
	*
	*	The Atlas is generated in several steps:
	*	  - a list of towns is pulled from the server
	*     - the list is sorted by population
	*     - the location of each town is pulled from the sever
	*     - an array is generated with all of the Manhattan distance pairs
	*     - an array is generated with the existing links
	*	  - an array is generated with the real travel distances along
	*			existing routes
	*	  - an array is generated with the differences between real travel
	*			distances and Manhattan distances
	*	  - the atlas is printed (to the Debug screen)
	*/
	 

	 
	AILog.Info("     Generating distance matrix.");
	AILog.Info("          TOWN NAME - POPULATION - LOCATION");

	// Generate Distance Matrix
	local iTown;
	local WmAtlas=[];
	WmAtlas.resize(WmTownArray.len());
	
	for(local i=0; i < WmTownArray.len(); i++) {
		iTown = WmTownArray[i];
		AILog.Info("          " + iTown + ". " + AITown.GetName(iTown) + " - " + AITown.GetPopulation(iTown) + " - " + AIMap.GetTileX(AITown.GetLocation(iTown)) + ", " + AIMap.GetTileY(AITown.GetLocation(iTown)));
		local TempArray = [];		// Generate the Array one 'line' at a time
		TempArray.resize(WmTownArray.len()+1);
		TempArray[0]=iTown;
		local jTown;
		for (local j = 0; j < WmTownArray.len(); j++) {
			jTown = WmTownArray[j];
			TempArray[j+1] = AIMap.DistanceManhattan(AITown.GetLocation(iTown),AITown.GetLocation(jTown));
		}
		WmAtlas[i]=TempArray;
	}

//	Print2DArray(WmAtlas);
	return WmAtlas;
}


function WmDOT::GenerateTownList()
{
   /*	Generates a list of towns above the population threshold.
	*		If at least one town is found, an 1D array of the TownID's is returned.
	*		If no towns are above the threshold, -1 is returned.
	*/
 
	AILog.Info("Generating Atlas...");
	// Generate TownList
	local WmTownList = AITownList();
	WmTownList.Valuate(AITown.GetPopulation);
	local PopLimit = WmDOT.GetSetting("MinTownSize");
	WmTownList.KeepAboveValue(PopLimit);				// cuts under the pop limit
	AILog.Info("     Ignoring towns with population under " + PopLimit + ". " + WmTownList.Count() + " of " + AITown.GetTownCount() + " towns left.");
	
	if (WmTownList.Count()==0) {
		return -1;
	}
	else {
		local WmTownArray = [];
		WmTownArray.resize(WmTownList.Count());
		local iTown = WmTownList.Begin();
		for(local i=0; i < WmTownList.Count(); i++) {
	//		AILog.Info("          " + iTown + ". " + AITown.GetName(iTown) + " - " + AITown.GetPopulation(iTown) + " - " + AIMap.GetTileX(AITown.GetLocation(iTown)) + ", " + AIMap.GetTileY(AITown.GetLocation(iTown)));
			WmTownArray[i]=iTown;
			iTown = WmTownList.Next();
		}
	
		return WmTownArray;
	}
}

function WmDOT::Print1DArray(InArray)
{
	local Length = InArray.len();
//	AILog.Info("The array is " + Length + " long.");
	local i = 0;
	local Temp = "";
	while (i < InArray.len() ) {
		Temp = Temp + "  " + InArray[i];
		i++;
	}
	AILog.Info("The array is " + Length + " long.  " + Temp + " ");
}

function WmDOT::Print2DArray(InArray)
{
	local Length = InArray.len();
//	AILog.Info("The array is " + Length + " long.");
	local i = 0;
	local Temp = "";
	while (i < InArray.len() ) {
		local InnerArray = [];
		InnerArray = InArray[i];
		local InnerLength = InnerArray.len();
//		AILog.Info("     The inner array is " + InnerLength + " long.");
		local j = 0;
		while (j < InnerArray.len() ) {
			Temp = Temp + "  " + InnerArray[j];
			j++;
		}
		Temp = Temp + "  /  ";
		i++;
	}
	AILog.Info("The array is " + Length + " long." + Temp + " ");
}

function WmDOT::BuildWmHQ()
{
	//  TO-DO
	//	- create other options for where to build HQ (random, setting?)
	//	- check for other DOT HQ's
	
	//	There is no check to keep the map co-ordinates from wrapping around the edge of the map
	
	AILog.Info("Building Headquarters...")
	
	local tick;
	tick = this.GetTick();
	
//	AICompany.BuildCompanyHQ(0xA284);
	
	local HQBuilt = false;
	// Check for exisiting HQ
	if (AICompany.GetCompanyHQ(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)) != -1) {
		HQBuilt = true;
		AILog.Info("     What are you trying to pull?!? HQ are already established at " + AIMap.GetTileX(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF)) + ", " +  AIMap.GetTileY(AICompany.GetCompanyHQ(AICompany.COMPANY_SELF)) + ".");
	}
	
	// If no HQ, build them!
	if (HQBuilt == false) {
		// Gets a list of the towns and picks the one with the highest populaiton	
		local WmTownList = AITownList();
		WmTownList.Valuate(AITown.GetPopulation);
		local HQTown = AITown();
		HQTown = WmTownList.Begin();
		
		// Get tile index of the centre of town
		local HQx;
		local HQy;
		HQx = AIMap.GetTileX(AITown.GetLocation(HQTown));
		HQy = AIMap.GetTileY(AITown.GetLocation(HQTown));
		AILog.Info("     HQ will be build in " + AITown.GetName(HQTown) + " at " + HQx + ", " + HQy + ".");
		
		// Starts a spiral out from the centre of town, trying to build the HQ until it works!
		local dx = -1;
		local dy =  0;
		local Steps = 0;
		local Stage = 1;
		local StageSteps = 0;
		
		while (HQBuilt == false) {
			HQx += dx;
			HQy += dy;
//			AILog.Info("          Trying at "+ HQx + ", " + HQy + ".");
			HQBuilt = AICompany.BuildCompanyHQ(AIMap.GetTileIndex(HQx,HQy));
			Steps ++;
			StageSteps ++;
			
			AILog.Info(StageSteps + " / (" + Stage + " / 2) ) % 2 = " ((StageSteps / (Stage / 2) ) % 2) );
			
			// Check if it's time to turn
			if ((StageSteps / (Stage / 2) ) % 2 == 0) {
				StageSteps = 0;
				Stage ++;
				
				// Turn Clockwise
				switch (dx) {
					case 0:
						switch (dy) {
							case -1:
								dx = -1;
								dy =  0;
								break;
							case 1:
								dx = 1;
								dy = 0;
								break;
						}
						break;
					case -1:
						dx = 0;
						dy = 1;
						break;
					case 1:
						dx =  0;
						dy = -1;
						break;
				}
			}
			

		}
		AILog.Info("          HQ built at "+ HQx + ", " + HQy + ". Took " + Steps + " tries.");
	}
	
	tick = this.GetTick() - tick;
	AILog.Info("     HQ built. Took " + tick + " tick(s).");
}
