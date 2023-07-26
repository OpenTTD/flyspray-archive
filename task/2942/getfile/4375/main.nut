class testai extends AIController
{
	a = null;
};

function test() {
	yield 0;
}

function testai::Start()
{
	a = test();
}
