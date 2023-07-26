//
// C++ Implementation: probabilities
//
// Description: 
//
//
// Author: Rafał Rzepecki <divided.mind@gmail.com>, (C) 2007
//
// Public domain

#include <stdlib.h>
#include <iostream>
#include <string>

using namespace std;

#define CHANCE16(a, b) ((unsigned short)rand() < (unsigned short)((65536 * (a)) / (b)))

inline bool CHANCE16I(const unsigned int a, const unsigned int b, const unsigned int r)
{
	return (unsigned short)r < (unsigned short)((65536 * a) / b);
}

#define CHANCE_IP(a, b, r, k) (r & ((1 << (k)) - 1)) < (((1 << (k)) * (a)) / (b))

long long int _chance_1_8 = 0, _chance_1_80 = 0, _chance_1_1280 = 0, _chance_1_24 = 0;

void divideTest(unsigned long long int i)
{
	for (; i > 0; i--) {
		unsigned int r = rand();

		if (CHANCE_IP(1, 8, r, 3)) {
			_chance_1_8++;
//			CommandCost res = CMD_ERROR;
			if (/* !_generating_world && */CHANCE_IP(1, 10, r >> 3, 13)) {
				/* Note: Do not replace " ^ 0xF" with ComplementSlope(). The slope might be steep. */
				_chance_1_80++;
				if (/*res = DoCommand(tile, */CHANCE_IP(1, 16, r >> 16, 4))// ? cur_slope : cur_slope ^ 0xF, 0,
//						DC_EXEC | DC_AUTO | DC_NO_WATER, CMD_TERRAFORM_LAND);
					_chance_1_1280++;
			}
			if (/* CmdFailed(res) && */CHANCE_IP(1, 3, r >> 20, 11)) {
				/* We can consider building on the slope, though. */
				_chance_1_24++;
//				goto no_slope;
			}
		}
	}
}

void naiveTest(long long int i)
{
	for (; i > 0; i--) {
		if (CHANCE16(1, 8)) {
			_chance_1_8++;
//			CommandCost res = CMD_ERROR;
			if (/* !_generating_world && */CHANCE16(1, 10)) {
				/* Note: Do not replace " ^ 0xF" with ComplementSlope(). The slope might be steep. */
				_chance_1_80++;
				if (/*res = DoCommand(tile, */CHANCE16(1, 16))// ? cur_slope : cur_slope ^ 0xF, 0,
//						DC_EXEC | DC_AUTO | DC_NO_WATER, CMD_TERRAFORM_LAND);
					_chance_1_1280++;
			}
			if (/* CmdFailed(res) && */CHANCE16(1, 3)) {
				/* We can consider building on the slope, though. */
				_chance_1_24++;
//				goto no_slope;
			}
		}
	}
}

void skidd13Test(long long int i)
{
	for (; i > 0; i--) {
		unsigned int r = rand();

		if (CHANCE16I(1, 8, r)) {
			_chance_1_8++;
//			CommandCost res = CMD_ERROR;
			if (/* !_generating_world && */CHANCE16I(1, 10, r >> 4)) {
				/* Note: Do not replace " ^ 0xF" with ComplementSlope(). The slope might be steep. */
				_chance_1_80++;
				if (/*res = DoCommand(tile, */CHANCE16I(1, 16, r >> 8))// ? cur_slope : cur_slope ^ 0xF, 0,
//						DC_EXEC | DC_AUTO | DC_NO_WATER, CMD_TERRAFORM_LAND);
					_chance_1_1280++;
			}
			if (/* CmdFailed(res) && */CHANCE16I(1, 3, r >> 16)) {
				/* We can consider building on the slope, though. */
				_chance_1_24++;
//				goto no_slope;
			}
		}
	}
}

void printResults(long long int iters)
{
#define RESULTS(i) "Hit 1/" #i ": " << _chance_1_##i << ", delta " << _chance_1_##i - (iters/i) << " (" << (_chance_1_##i - (iters/i)) * i * 1000 / iters << " per thousand)" << endl
	cout << "Total iterations: " << iters << endl
		 << RESULTS(8) << RESULTS(80) << RESULTS(1280) << RESULTS(24);
}

void usage()
{
	cout << "Usage:\n\tprobabilities divide|naive|skidd13 <iterations>\n";
	exit(1);
}

int main(int argc, char ** argv)
{
	if (argc < 3)
		usage();

	string type = argv[1];
	long long int iterations = atoll(argv[2]);
	if (type == "naive")
		naiveTest(iterations);
	if (type == "skidd13")
		skidd13Test(iterations);
	if (type == "divide")
		divideTest(iterations);

	printResults(iterations);
	return 0;
}
