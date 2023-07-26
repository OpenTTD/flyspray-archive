class TestAI extends AIController {
}

function TestAI::BuildBridge(a, b)
{
	AISign.BuildSign(a, "S");
	AISign.BuildSign(b, "E");
	local dist = AIMap.DistanceManhattan(a, b);
	local bridge_list = AIBridgeList_Length(dist);
	if (bridge_list.IsEmpty()) crash_because_no_bridge_is_found();
	local bridge_id = bridge_list.Begin();
	print("bridge_id: " + bridge_id + " " + AIBridge.GetName(bridge_id) + " distance: " + dist);
	//local test = AITestMode();
	local c = AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_id, a, b);
	if (c == false) print("ERROR cannot build bridge " + AIError.GetLastErrorString());
}

function TestAI::Start()
{
	local RT = AIRailTypeList();
	if (RT.IsEmpty())	{ print("no railtype"); crash_no_railtype(); }
	AIRail.SetCurrentRailType(RT.Begin());
	local a, b;
	print("test1");
	a = 1506;
	b = 1698;
	this.BuildBridge(a, b);

	print(" ");
	print("test2");
	a = 1443;
	b = 1699;
	this.BuildBridge(a, b);

	print(" ");
	print("test3");
	a = 1444;
	b = 1700;
	this.BuildBridge(a, b);
}


