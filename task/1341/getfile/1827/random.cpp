/* $Id$ */

#include "stdafx.h"
#include "openttd.h"
#include "functions.h"

/**
 * =======================
 * Abstract Random class
 *  Why a abstract class:
 *  There are IIRC ATM 4 Random generators in the code:
 *  @li the current Random()
 *  @li the RandomDebug Random()
 *  @li the unused mersenne twister
 *  @li the original tile randomiser
 *  All these ones can now be unified trough the abstract interface.
 *
 *  The abstract interface has the additional advantage that if the
 *  mersenne twister proves to be unsyncable we can implement another
 *  pseudo random number generator without changing the code that much.
 * =======================
 */
struct Randomiser {
	protected:
		uint32 last_seed;

	public:
		virtual void Seed(uint32 seed);
		virtual uint32 GetRandom();
		uint32 RandomRange(uint max);

		virtual uint32 GetSync(uint8 p0)

		uint32 operator() ();
		uint32 operator() (uint max);
};

uint32 Randomiser::RandomRange(uint max)
{
	return GB(this->GetRandom(), 0, 16) * max >> 16;
}

uint32 Randomiser::operator() ()
{
	return this->GetRandom();
}

uint32 Randomiser::operator() (uint max)
{
	return this->RandomRange(max);
}

/**
 * =======================
 * Original random
 * =======================
 */
struct BasicRandom : Randomiser {
	protected:
		uint32 seeds[3];
	public:
		/* virtual */ void Seed(uint32 seed);
		/* virtual */ uint32 GetRandom();

		/* virtual */ uint32 GetSync(uint8 p0)
		BasicRandom();
};

BasicRandom::BasicRandom()
{
	this->Seed(GetTickCount()); // win32; unix uses time(null)
}

/**
 * Seed the random values
 * @note code ripped from win32.cpp
 * @note unix implementation is a bit different
 * @note but it should be unified IMO
 *
 * @param seed The given seed
 */
void BasicRandom::Seed(uint32 seed)
{
	this->last_seed = seed;            // _random_seeds[0][0]
	this->seeds[0] = seed;             // _random_seeds[0][1]
	this->seeds[1] = seed * 0x1234567; // _random_seeds[1][1]
	this->seeds[2] = this->seeds[1];   // _random_seeds[1][0]
}

/**
 * Get a random number
 *
 * @return a 32bit random number
 */
uint32 BasicRandom::GetRandom()
{
	register uint32 s = this->last_seed;
	register uint32 t = this->seeds[0];

	this->last_seed = s + ROR(t ^ 0x1234567F, 7) + 1;
	t = ROR(s, 3) - 1;
	this->seeds[0] = t;

	return t;
}

/**
 * Get the values needed to sync the randomiser
 * in a network.
 *
 * @param p0 The state witch we want to check for sync
 * @return The value of the requested state
 *
 * @todo: We probably need a SetSync() to sync things like mersenne
 */
/* virtual */ uint32 BasicRandom::GetSync(uint8 p0)
{
	switch (p0) {
		default:
			return 0;
			break;
		case 0:
			return this->last_seed;
			break;
		case 1:
			return this->seeds[0];
			break;
		case 2:
			return this->seeds[1];
			break;
		case 3:
			return this->seeds[2];
			break;
	}
}

/**
 * =======================
 * Source code for Mersenne Twister.
 * A Random number generator with much higher
 * quality random numbers.
 * =======================
 */
#define N                            (624)   // length of state array
#define M                            (397)   // a period parameter
#define K                    (0x9908B0DFU)   // a magic constant
#define hiBit(u)       ((u) & 0x80000000U)   // mask all but highest   bit of u
#define loBit(u)       ((u) & 0x00000001U)   // mask all but lowest    bit of u
#define loBits(u)      ((u) & 0x7FFFFFFFU)   // mask     the highest   bit of u
#define mixBits(u, v)  (hiBit(u)|loBits(v))  // move hi bit of u to hi bit of v

struct MersenneRandom : Randomiser {
	protected:
		uint32 state[N+1]; // state vector + 1 extra to not violate ANSI C
		uint32 *pos;       // pointer to the current state
		int16 left;        // remaining states

		void Reload();

	public:
		/* virtual */ void Seed(register uint32 seed);
		/* virtual */ uint32 GetRandom();

//		/* virtual */ uint32 GetSync
		MersenneRandom();
};

MersenneRandom::MersenneRandom()
{
	this->last_seed = time(NULL);
	this->Seed(this->last_seed);
	this->pos = this->state;
}

void MersenneRandom::Seed(register uint32 seed)
{
	this->last_seed = seed;
	this->left = 0;
	seed = (seed | 1U) & UINT32_MAX;

	register uint32 *insert = this->state;

	/* Fill the state vector with new values */
	*insert = seed;
	*insert++;
	for (register uint16 i = N; i != 0; i--) {
		seed *= 69069U;
		insert = seed & UINT32_MAX;
		*insert++;
	}
}

void MersenneRandom::Reload()
{
	if (this->left < -1)
		this->Seed(4357U);

	this->left = N-1;
	this->pos = this-state + 1;

	register uint32 *p0, *p2, *pM, s0, s1;
	s0 = this->state[0];
	s1 = this->state[1];
	*p0 = this->state;
	*p2 = this->state + 2;
	*pM = this->state + M;

	for (register uint16 i = N - M + 1; i != 0; i--) {
		s0 = s1;
		s1 = *p2;
		p0 = *pM ^ (mixBits(s0, s1) >> 1) ^ (loBit(s1) ? K : 0U);
		*p0++;
		*p2++;
		*pM++;
	}

	pM = this->state;

	for (register uint16 i = M; i != 0; i--) {
		s0 = s1;
		s1 = *p2;
		p0 = *pM ^ (mixBits(s0, s1) >> 1) ^ (loBit(s1) ? K : 0U);
		*p0++;
		*p2++;
		*pM++;
	}

	s1 = this->state[0];
	*p0 = *pM ^ (mixBits(s0, s1) >> 1) ^ (loBit(s1) ? K : 0U);
}

uint32 MersenneRandom::GetRandom()
{
	uint32 value;
	if (--this->left < 0) {
		this->Reload();
		value = this->state[0];
	} else {
		value = *this->pos++;
	}

	value ^= (value >> 11);
	value ^= (value <<  7) & 0x9D2C5680U;
	value ^= (value << 15) & 0xEFC60000U;
	return value ^ (value >> 18);
}

