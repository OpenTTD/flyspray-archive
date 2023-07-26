class bugAI extends AIController
 {
   constructor()
   {
   } 
 }
 
 
 function bugAI::Start()
 {
   AILog.Info("bugAI Started.");
   SetCompanyName();
  
   //set a legal railtype. 
   local types = AIRailTypeList();
   AIRail.SetCurrentRailType(types.Begin());
       
   //Keep running. If Start() exits, the AI dies.
   while (true) {
     this.Sleep(100);
     this.dobug();
   }
 }
 
 function bugAI::Save()
 {
   local table = {};	
   //TODO: Add your save data to the table.
   return table;
 }
 
 function bugAI::Load(version, data)
 {
   AILog.Info(" Loaded");
   //TODO: Add your loading routines.
 }
 
 
 function bugAI::SetCompanyName()
 {
   if(!AICompany.SetName("Testing AI")) {
     local i = 2;
     while(!AICompany.SetName("Testing AI #" + i)) {
       i = i + 1;
       if(i > 255) break;
     }
   }
   AICompany.SetPresidentName("P. Resident");
 }

function bugAI::ShapeTile(tile, wantedHeight)
{
local srcL=AITile.GetMinHeight(tile);
local srcH=AITile.GetMaxHeight(tile);
local slope=AITile.GetSlope(tile);
local compSlope=AITile.GetComplementSlope(slope);
if (srcL == wantedHeight && srcH == wantedHeight)
	{
	// Tile at level
	return true;
	}
AILog.Info("Tile: "+tile+" Slope: "+slope+" compSlope: "+compSlope+" target: "+wantedHeight+" srcL: "+srcL+" srcH: "+srcH+" half:"+AITile.IsHalftileSlope(tile)+" steep:"+AITile.IsSteepSlope(tile));
local error=null;
if (srcL > wantedHeight || srcH > wantedHeight)
	{
	AISign.BuildSign(tile,"v");
	AITile.LowerTile(tile, slope);
	error=AIError.GetLastError();
	AILog.Info("Lowering tile "+AIError.GetLastErrorString());
	if (error == AIError.ERR_NONE)	return true;
				else	return false;
	}
/*
if (srcL < wantedHeight || srcH < wantedHeight)
	{
	PutSign(tile,"^");
	AITile.RaiseTile(tile, compSlope);
	error=AIError.GetLastError();	
	DInfo("Raising tile "+AIError.GetLastErrorString()+" minHeight: "+AITile.GetMinHeight(tile)+" maxheight: "+AITile.GetMaxHeight(tile));
	if (error == AIError.ERR_NONE)	return true;
						else	return false;
	}
*/
}

function bugAI::ClearSigns()
{
local sweeper=AISignList();
foreach (i, dummy in sweeper)	{ AISign.RemoveSign(dummy); AISign.RemoveSign(i); }
}

function bugAI::dobug()
{
local area=AITileList();
local fromTile=2405; // 0965, it's map center
local toTile=1834; // 072a
local error=null;
area.AddRectangle(fromTile,toTile);
AIController.Sleep(20);
this.ClearSigns();
foreach (tile, dummy in area)	AISign.BuildSign(tile, "*");

foreach (tile, dummy in area)
	{
	error=this.ShapeTile(tile, 1); // only handle to lower to level 1 for the tests
	if (error) AILog.Info("No error report");
	}
}
