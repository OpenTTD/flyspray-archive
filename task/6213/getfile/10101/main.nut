class MyNewAI extends AIController {
}

function MyNewAI::Save()
{
	return {};
}

function MyNewAI::Load()
{

}

function MyNewAI::Freezer(eng_id)
{
	print("Freezer start at "+AIController.GetTick()+" We get "+AIEngine.GetName(eng_id)+":"+eng_id);
	local z = AIEngineList(AIVehicle.VT_RAIL);
	z.Valuate(AIEngine.IsWagon);
	z.KeepValue(1);
	print("Freezer end at "+AIController.GetTick());
	return true;
}

function MyNewAI::Start()
{
	while (true) {
	local b = AIEngineList(AIVehicle.VT_RAIL);
	print("running valuator at "+AIController.GetTick());
	b.Valuate(MyNewAI.Freezer);
	b.KeepValue(1);
	print("after valuator at "+AIController.GetTick());
	}
}

