class testai extends AIController
{
};

function test() {
	AIController.Sleep(1);
}

function testai::Start()
{
	test.acall([this]);
}
