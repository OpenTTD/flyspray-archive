/* g++ test-town-growth-cmd.cpp -I src --std=c++11 */

#include "stdafx.h"
#include "core/bitmath_func.hpp"
#include "core/math_func.hpp"
#include "date_type.h"

#include <iostream>

using std::cout;
using std::endl;

static const uint8 _settings_town_growth_rate = 3;

// static const uint16 TOWN_GROW_RATE_UNDEFINED   = 0x7FFF; ///< Special value for Town::growth_rate to indicate that growth rate is not calcuted yet.
static const uint16 TOWN_GROW_RATE_CUSTOM      = 0x8000; ///< If this mask is applied to Town::growth_rate, the grow_counter will not be calculated by the system (but assumed to be set by scripts)
static const uint16 TOWN_GROW_RATE_NORMAL      = 0xFFFE; ///< Special value for CmdTownGrowthRate to switching to normal growth rate calculation
static const uint16 TOWN_GROW_RATE_CUSTOM_NONE = 0xFFFF; ///< Special value for Town::growth_rate to disable town growth.

enum TownFlags {
	TOWN_IS_GROWING     = 0,   ///< Conditions for town growth are met. Grow according to Town::growth_rate.
	TOWN_HAS_CHURCH     = 1,   ///< There can be only one church by town.
	TOWN_HAS_STADIUM    = 2,   ///< There can be only one stadium by town.
};


struct TownCache {
	uint32 num_houses;                        ///< Amount of houses
};


struct Town {
	byte flags;                    ///< See #TownFlags.

	TownCache cache; ///< Container for all cacheable data.

	uint16 grow_counter;           ///< counter to count when to grow, value is smaller than or equal to growth_rate
	uint16 growth_rate;            ///< town growth rate

	byte fund_buildings_months;    ///< fund buildings program in action?

	bool larger_town;              ///< if this is a larger town and should grow more quickly

	int n_stations;  ///< to emulate amount of active stations
};


static void OldUpdateTownGrowRate(Town *t)
{
	ClrBit(t->flags, TOWN_IS_GROWING);
	// SetWindowDirty(WC_TOWN_VIEW, t->index);
	// SetWindowDirty(WC_CB_TOWN, t->index);

	// if (_settings_game.economy.town_growth_rate == 0 && t->fund_buildings_months == 0) return;

	// if (t->fund_buildings_months == 0) {
	//     /* Check if all goals are reached for this town to grow (given we are not funding it) */
	//     for (int i = TE_BEGIN; i < TE_END; i++) {
	//         switch (t->goal[i]) {
	//             case TOWN_GROWTH_WINTER:
	//                 if (TileHeight(t->xy) >= GetSnowLine() && t->received[i].old_act == 0 && t->cache.population > 90) return;
	//                 break;
	//             case TOWN_GROWTH_DESERT:
	//                 if (GetTropicZone(t->xy) == TROPICZONE_DESERT && t->received[i].old_act == 0 && t->cache.population > 60) return;
	//                 break;
	//             default:
	//                 if (t->goal[i] > t->received[i].old_act) return;
	//                 break;
	//         }
	//     }
	// }

	if ((t->growth_rate & TOWN_GROW_RATE_CUSTOM) != 0) {
		if (t->growth_rate != TOWN_GROW_RATE_CUSTOM_NONE) SetBit(t->flags, TOWN_IS_GROWING);
		// SetWindowDirty(WC_TOWN_VIEW, t->index);
		// SetWindowDirty(WC_CB_TOWN, t->index);
		return;
	}

	/**
	 * Towns are processed every TOWN_GROWTH_TICKS ticks, and this is the
	 * number of times towns are processed before a new building is built.
	 */
	static const uint16 _grow_count_values[2][6] = {
		{ 120, 120, 120, 100,  80,  60 }, // Fund new buildings has been activated
		{ 320, 420, 300, 220, 160, 100 }  // Normal values
	};

	// int n = 0;
	int n = t->n_stations;

	// const Station *st;
	// FOR_ALL_STATIONS(st) {
	//     if (DistanceSquare(st->xy, t->xy) <= t->cache.squared_town_zone_radius[0]) {
	//         if (st->time_since_load <= 20 || st->time_since_unload <= 20) {
	//             n++;
	//         }
	//     }
	// }

	uint16 m;

	if (t->fund_buildings_months != 0) {
		m = _grow_count_values[0][min(n, 5)];
	} else {
		m = _grow_count_values[1][min(n, 5)];
		// if (n == 0 && !Chance16(1, 12)) return;
		if (n == 0) return;
	}

	/* Use the normal growth rate values if new buildings have been funded in
	 * this town and the growth rate is set to none. */
	uint growth_multiplier = _settings_town_growth_rate != 0 ? _settings_town_growth_rate - 1 : 1;

	m >>= growth_multiplier;
	if (t->larger_town) m /= 2;

	t->growth_rate = m / (t->cache.num_houses / 50 + 1);
	t->grow_counter = min(t->growth_rate, t->grow_counter);

	SetBit(t->flags, TOWN_IS_GROWING);
}

bool OldCmdTownGrowthRate(Town *t, uint32 p2) {
	// if (_current_company != OWNER_DEITY) return CMD_ERROR;
	if ((p2 & TOWN_GROW_RATE_CUSTOM) != 0 && p2 != TOWN_GROW_RATE_CUSTOM_NONE) return false;
	if (GB(p2, 16, 16) != 0) return false;

	// Town *t = Town::GetIfValid(p1);
	// if (t == NULL) return CMD_ERROR;

	// if (flags & DC_EXEC) {
	if (p2 == 0) {
		/* Clear TOWN_GROW_RATE_CUSTOM, UpdateTownGrowRate will determine a proper value */
		t->growth_rate = 0;
	} else {
		uint old_rate = t->growth_rate & ~TOWN_GROW_RATE_CUSTOM;
		if (t->grow_counter >= old_rate) {
			/* This also catches old_rate == 0 */
			t->grow_counter = p2;
		} else {
			/* Scale grow_counter, so half finished houses stay half finished */
			t->grow_counter = t->grow_counter * p2 / old_rate;
		}
		t->growth_rate = p2 | TOWN_GROW_RATE_CUSTOM;
	}
	OldUpdateTownGrowRate(t);
	// InvalidateWindowData(WC_TOWN_VIEW, p1);
	// InvalidateWindowData(WC_CB_TOWN, p1);
	// }
	return true;
}

bool OldGSCmd(Town *t, uint32 days_between_town_growth) {
	switch (days_between_town_growth) {
		case TOWN_GROW_RATE_NORMAL:
			days_between_town_growth = 0;
			break;

		case TOWN_GROW_RATE_CUSTOM_NONE:
			days_between_town_growth = TOWN_GROW_RATE_CUSTOM_NONE;
			break;

		default:
			days_between_town_growth = days_between_town_growth * DAY_TICKS / TOWN_GROWTH_TICKS;
			// EnforcePrecondition(false, days_between_town_growth < TOWN_GROW_RATE_CUSTOM);
			if (days_between_town_growth == 0) days_between_town_growth = 1; // as fast as possible
			break;
	}

	return OldCmdTownGrowthRate(t, days_between_town_growth);
}

static void UpdateTownGrowCounter(Town *t, uint prev_growth_rate) {
	if (t->growth_rate == TOWN_GROW_RATE_CUSTOM_NONE)
		return;
	if (prev_growth_rate == TOWN_GROW_RATE_CUSTOM_NONE) {
		t->grow_counter = min(t->growth_rate & ~TOWN_GROW_RATE_CUSTOM, t->grow_counter);
		return;
	}
	// t->grow_counter = RoundDivSU((t->grow_counter + 1) * ((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1), (prev_growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1); // right + round
	// if (t->grow_counter > 0) t->grow_counter--;
	t->grow_counter = RoundDivSU(t->grow_counter * ((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1), (prev_growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1); // left + round
	//
	// t->grow_counter = (t->grow_counter * ((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1)) / ((prev_growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1); // left + round

	// t->grow_counter = (t->grow_counter * ((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1) + (prev_growth_rate & ~TOWN_GROW_RATE_CUSTOM)) / ((prev_growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1); // left + round
	// t->grow_counter = min(t->grow_counter, t->growth_rate &  ~TOWN_GROW_RATE_CUSTOM);
}

static int CountActiveStations(Town *t) {
	return t->n_stations;

	// int n = 0;
	// const Station *st;
	// FOR_ALL_STATIONS(st) {
	//     if (DistanceSquare(st->xy, t->xy) <= t->cache.squared_town_zone_radius[0]) {
	//         if (st->time_since_load <= 20 || st->time_since_unload <= 20) {
	//             n++;
	//         }
	//     }
	// }
	// return n;
}

static uint GetNormalGrowthRate(Town *t) {
	/**
	 * Towns are processed every TOWN_GROWTH_TICKS ticks, and this is the
	 * number of times towns are processed before a new building is built.
	 */
	static const uint16 _grow_count_values[2][6] = {
		{ 120, 120, 120, 100,  80,  60 }, // Fund new buildings has been activated
		{ 320, 420, 300, 220, 160, 100 }  // Normal values
	};

	int n = CountActiveStations(t);
	uint16 m = _grow_count_values[t->fund_buildings_months != 0 ? 0 : 1][min(n, 5)];

	/* Use the normal growth rate values if new buildings have been funded in
	 * this town and the growth rate is set to none. */
	uint growth_multiplier = _settings_town_growth_rate != 0 ? _settings_town_growth_rate - 1 : 1;

	m >>= growth_multiplier;
	if (t->larger_town) m /= 2;

	return m / (t->cache.num_houses / 50 + 1);
}

static void UpdateTownGrowthRate(Town *t) {
	if ((t->growth_rate & TOWN_GROW_RATE_CUSTOM) != 0)
		return;
	uint old_rate = t->growth_rate;
	t->growth_rate = GetNormalGrowthRate(t);
	UpdateTownGrowCounter(t, old_rate);
}

static void UpdateTownGrowth(Town *t)
{
	ClrBit(t->flags, TOWN_IS_GROWING);
	// SetWindowDirty(WC_TOWN_VIEW, t->index);

	UpdateTownGrowthRate(t);

	// if (_settings_game.economy.town_growth_rate == 0 && t->fund_buildings_months == 0) return;

	// if (t->fund_buildings_months == 0) {
	//     /* Check if all goals are reached for this town to grow (given we are not funding it) */
	//     for (int i = TE_BEGIN; i < TE_END; i++) {
	//         switch (t->goal[i]) {
	//             case TOWN_GROWTH_WINTER:
	//                 if (TileHeight(t->xy) >= GetSnowLine() && t->received[i].old_act == 0 && t->cache.population > 90) return;
	//                 break;
	//             case TOWN_GROWTH_DESERT:
	//                 if (GetTropicZone(t->xy) == TROPICZONE_DESERT && t->received[i].old_act == 0 && t->cache.population > 60) return;
	//                 break;
	//             default:
	//                 if (t->goal[i] > t->received[i].old_act) return;
	//                 break;
	//         }
	//     }
	// }

	if ((t->growth_rate & TOWN_GROW_RATE_CUSTOM) != 0) {
		if (t->growth_rate != TOWN_GROW_RATE_CUSTOM_NONE) SetBit(t->flags, TOWN_IS_GROWING);
		return;
	}

	if (t->fund_buildings_months == 0 && CountActiveStations(t) == 0) {
		// if (!Chance16(1, 12)) return;
		return;
	}

	SetBit(t->flags, TOWN_IS_GROWING);
}

// /* Scale grow_counter, so half finished houses stay half finished */
// static void UpdateTownGrowthCounter(Town *t, uint old_rate, uint new_rate) {
// /*	if (old_rate == TOWN_GROW_RATE_CUSTOM_NONE)
// 		t->grow_counter = min(t->grow_counter, new_rate);
// 	if (t->grow_counter > old_rate)
// 		t->grow_counter = new_rate;
// */	if (old_rate = 0) t->grow_counter = new_rate;
// 	else t->grow_counter = t->grow_counter * new_rate / old_rate;
// 	// t->grow_counter = ((2 * t->grow_counter + 1) * (p2 + 1)) / (2 * (old_rate + 1));
// 	// if (t->grow_counter > 0) t->grow_counter--;
// 	// t->grow_counter = ((t->grow_counter + 1) * (p2 + 1) + (old_rate + 1) / 2) / (old_rate + 1);
// 	// if (t->grow_counter > 0) t->grow_counter--;
// }

bool NewCmdTownGrowthRate(Town *t, uint32 p2) {
	// if (_current_company != OWNER_DEITY) return false;
	if ((p2 & TOWN_GROW_RATE_CUSTOM) != 0 && p2 != TOWN_GROW_RATE_CUSTOM_NONE &&
			p2 != TOWN_GROW_RATE_NORMAL) return false;
	if (GB(p2, 16, 16) != 0) return false;

	// Town *t = Town::GetIfValid(p1);
	// if (t == NULL) return CMD_ERROR;

	// if (flags & DC_EXEC) {

	uint old_rate = t->growth_rate;
	if (p2 == TOWN_GROW_RATE_NORMAL)
		t->growth_rate = GetNormalGrowthRate(t);
	else
		t->growth_rate = p2 | TOWN_GROW_RATE_CUSTOM;
	UpdateTownGrowCounter(t, old_rate);
	if (old_rate == TOWN_GROW_RATE_CUSTOM_NONE ||
	    	t->growth_rate == TOWN_GROW_RATE_CUSTOM_NONE)
		UpdateTownGrowth(t);

	// FIXME setwindowdirty?

	// InvalidateWindowData(WC_TOWN_VIEW, p1);
	// InvalidateWindowData(WC_CB_TOWN, p1);
	// }

	return true;
}

bool NewGSCmd(Town *t, uint32 days_between_town_growth) {
	uint16 growth_rate;
	switch (days_between_town_growth) {
		case TOWN_GROW_RATE_NORMAL:
		case TOWN_GROW_RATE_CUSTOM_NONE:
			growth_rate = days_between_town_growth;
			break;

		default:
			// We are asked for days_between_town_growth * DAY_TICKS,
			// but town expands every (t->growth_rate + 1) * TOWN_GROWTH_TICKS
			// Thus selecting growth_rate to make it as close as possible
			growth_rate = RoundDivSU(days_between_town_growth * DAY_TICKS, TOWN_GROWTH_TICKS);
			if (growth_rate > 0) growth_rate -= 1;
			break;
	}
	return NewCmdTownGrowthRate(t, growth_rate);
}

void PrintGrowthRate(uint32 growth_rate) {
	if (growth_rate == TOWN_GROW_RATE_NORMAL)
		cout << "NORMAL";
	else if (growth_rate == TOWN_GROW_RATE_CUSTOM_NONE)
		cout << "NONE";
	// else if (growth_rate == TOWN_GROW_RATE_UNDEFINED)
	// 	cout << "UNDEF";
	else if (growth_rate & TOWN_GROW_RATE_CUSTOM)
		cout << (growth_rate & ~TOWN_GROW_RATE_CUSTOM) << "*";
	else
		cout << growth_rate;
}

void PrintTownState(const Town &t) {
	PrintGrowthRate(t.growth_rate);
	cout << ":" << t.grow_counter;
	if (!HasBit(t.flags,TOWN_IS_GROWING)) cout << "[N]";
}

bool TestCmd(uint16 growth_rate, uint16 grow_counter,
			 uint8 n_stations, bool is_growing,
			 bool growth_rate_updated,
			 uint32 growth_arg,
			 uint16 expected_gr, uint16 expected_gc,
			 bool silent=false,
			 uint32 growth_arg_2=0) {
	Town t_old {
		.flags = (byte)(is_growing ? 1 << TOWN_IS_GROWING : 0),
		.cache = {.num_houses = 30},
		.grow_counter = grow_counter,
		.growth_rate = growth_rate,
		.fund_buildings_months = 0,
		.larger_town = true,
		.n_stations = n_stations,
	};
	if (growth_rate_updated) OldUpdateTownGrowRate(&t_old);
	Town t_new = t_old;
	if (!silent) {
		PrintTownState(t_old);
		if (!growth_rate_updated) cout << "[U]";
		cout << " -> ";
		PrintGrowthRate(growth_arg);
		if (growth_arg_2) {
			cout << " -> ";
			PrintGrowthRate(growth_arg_2);
		}
		cout << " | ";
	}
	bool r_old = OldGSCmd(&t_old, growth_arg);
	bool r_new = NewGSCmd(&t_new, growth_arg);
	if (growth_arg_2) {
		if (!silent) {
			if (!r_old) cout << "ERROR:";
			PrintTownState(t_old);
			cout << " ";
			if (!r_new) cout << "ERROR:";
			PrintTownState(t_new);
			cout << " | ";
		}
		r_old = OldGSCmd(&t_old, growth_arg_2);
		r_new = NewGSCmd(&t_new, growth_arg_2);
	}
	if (!silent) {
		if (!r_old) cout << "ERROR:";
		PrintTownState(t_old);
		cout << " ";
		if (!r_new) cout << "ERROR:";
		PrintTownState(t_new);
	}

	bool passed = (r_new && t_new.growth_rate == expected_gr &&
				   t_new.grow_counter == expected_gc);
	if (!silent) {
		if (passed) {}
			// cout << " OK";
		else {
			cout << " FAIL ";
			PrintGrowthRate(expected_gr);
			cout << ":" << expected_gc;
		}
		cout << endl;
	}
	return passed;
}

int32 NewGetGrowthRate(const Town *t) {
	// if (!IsValidTown(town_id)) return -1;

	// const Town *t = ::Town::Get(town_id);

	if (t->growth_rate == TOWN_GROW_RATE_CUSTOM_NONE) return TOWN_GROW_RATE_CUSTOM_NONE;

	return RoundDivSU(((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1) * TOWN_GROWTH_TICKS, DAY_TICKS);
}

int32 OldGetGrowthRate(const Town *t) {
	// if (!IsValidTown(town_id)) return -1;

	// const Town *t = ::Town::Get(town_id);

	if (t->growth_rate == TOWN_GROW_RATE_CUSTOM_NONE) return TOWN_GROW_RATE_CUSTOM_NONE;

	return ((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) * TOWN_GROWTH_TICKS + DAY_TICKS) / DAY_TICKS;
}

bool TestGet(uint32 growth_arg, bool use_new) {
	Town t {
		.flags = 0,
		.cache = {.num_houses = 30},
		.grow_counter = 4,
		.growth_rate = 12,
		.fund_buildings_months = 0,
		.larger_town = true,
		.n_stations = 5
	};
	OldUpdateTownGrowRate(&t);
	int32 gr;
	if (use_new) {
		NewGSCmd(&t, growth_arg);
		gr = NewGetGrowthRate(&t);
	} else {
		OldGSCmd(&t, growth_arg);
		gr = OldGetGrowthRate(&t);
	}
	if (gr != growth_arg) {
		if (!use_new) cout << "OLD ";
		cout << "GET FAIL " << gr << " expected " << growth_arg << endl;
		return false;
	}
	return true;
}


void Test() {
	uint16 NONE = TOWN_GROW_RATE_CUSTOM_NONE;
	uint16 NORMAL = TOWN_GROW_RATE_NORMAL;
	// uint16 UNDEF = TOWN_GROW_RATE_UNDEFINED;
	uint16 C = TOWN_GROW_RATE_CUSTOM;
	cout << "state -> new gr | old-state new-state test res" << endl;

	// any -> NONE  => NONE:old_gc
	TestCmd(12, 4, 5, true, true, NONE, NONE, 4);
	TestCmd(NONE, 4, 5, true, true, NONE, NONE, 4);
	TestCmd(16|C, 4, 5, true, true, NONE, NONE, 4);
	// TestCmd(UNDEF, 4, 5, false, true, NONE, NONE, 4);
	cout << endl;

	// any -> NORMAL => updated_gr:old_gc
	TestCmd(32, 4, 5, true, false, NORMAL, 12, 2);
	TestCmd(12, 4, 5, true, true, NORMAL, 12, 4);
	TestCmd(32|C, 4, 5, true, true, NORMAL, 12, 2);
	TestCmd(NONE, 4, 5, true, true, NORMAL, 12, 4);
	TestCmd(12, 4, 5, false, true, NORMAL, 12, 4);
	TestCmd(0, 4, 5, false, true, 12, 12|C, 4);
	TestCmd(0, 0, 5, true, true, NORMAL, 12, 0);
	// TestCmd(UNDEF, 4, 5, false, true, 12, 12|C, 4);
	// TestCmd(UNDEF, 4, 5, false, true, NORMAL, 12, 4);
	cout << endl;

	// none -> custom => new_gr:old_gc
	TestCmd(NONE, 4, 5, true, true, 32, 33|C, 4);
	TestCmd(NONE, 21845, 5, true, true, 11, 11|C, 11);
	cout << endl;

	// normal -> custom => new_gr:scale_gc
	TestCmd(12, 4, 5, true, true, 32, 33|C, 10);
	cout << endl;

	// custom -> custom => new_gr:scaled_gc
	TestCmd(16|C, 4, 5, true, true, 0, 0|C, 0);
	TestCmd(16|C, 4, 5, true, true, 1, 0|C, 0);
	TestCmd(16|C, 4, 5, true, true, 2, 1|C, 0);
	TestCmd(16|C, 4, 5, true, true, 8, 7|C, 2);
	TestCmd(16|C, 4, 5, true, true, 70, 73|C, 17);
	TestCmd(16|C, 4, 5, true, true, 10700, 11310|C, 2661);
	TestCmd(31713|C, 31713, 5, true, true, 30000, 31713|C, 31713);
	// TestCmd(UNDEF, 20, 0, false, true, 12, 12|C, 12);
	TestCmd(1|C, 0, 5, true, true, 96, 100|C, 0);
	TestCmd(2|C, 1, 5, true, true, 96, 100|C, 34);
	TestCmd(2|C, 2, 5, true, true, 96, 100|C, 67);
	cout << endl;
	// TestCmd(1|C, 0, 5, true, 96, 100|C, 50);
	// TestCmd(1|C, 1, 5, true, true, 10, 1|C, 1, false, 2);
	TestCmd(2|C, 1, 5, true, true, 4, 2|C, 1, false, 3);
	TestCmd(2|C, 2, 5, true, true, 4, 2|C, 2, false, 3);
	TestCmd(4|C, 2, 5, true, true, 10, 4|C, 2, false, 5);
	cout << endl;

	int cfails = 0;
	for (int i = 1; i < 100; i++) {
		int gr = ((i * DAY_TICKS + TOWN_GROWTH_TICKS / 2) / TOWN_GROWTH_TICKS - 1);
		for (int ii = 0; ii <= gr; ii++)
		for (int j = i; j < 500; j++) {
			if (TestCmd(gr|C, ii, 5, true, true, j, gr|C, ii, true, i))
				continue;
			// cout << "Chain fail: " << gr << ":" << ii << " -> " << j << " -> " << i << "   ";
			cout << "Chain fail: ";
			TestCmd(gr|C, ii, 5, true, true, j, gr|C, ii, !true, i);
			if (++cfails > 5) goto ctestend;
		}
	}
	ctestend:
	if (!cfails) cout << "Chains test passed" << endl;
	cout << endl;

	// return;

	for (uint16 i = 1, e = 0; i <= 30000 && e < 5; i++) {
		if (!TestGet(i, false)) e++;
	}
	for (uint16 i = 1, e = 0; i <= 30000 && e < 5; i++) {
		if (!TestGet(i, true)) e++;
	}
}

int main() {
	Test();

	return 0;
}


/* V1 test results
12:4 -> NONE | NONE:21845[N] NONE:4[N]
NONE:4[N] -> NONE | NONE:8[N] NONE:4[N]
16*:4 -> NONE | NONE:16383[N] NONE:4[N]
UNDEF:4[N] -> NONE | NONE:8[N] NONE:4[N]

32:4[U] -> NORMAL | 12:4 12:4
12:4 -> NORMAL | 12:4 12:4
32*:4 -> NORMAL | 12:4 12:4
NONE:4[N] -> NORMAL | 12:4 12:4
12:4[N] -> NORMAL | 0:4[N] UNDEF:4[N]
0:4[N] -> 12 | 12*:12 12*:12
UNDEF:4[N] -> 12 | 12*:0 12*:4
UNDEF:4[N] -> NORMAL | 0:4[N] UNDEF:4[N]

NONE:4[N] -> 32 | 33*:0 33*:4
NONE:21845[N] -> 11 | 11*:7 11*:11 FAIL 12*:4

12:4 -> 32 | 33*:11 33*:11

16*:4 -> 0 | 1*:0 0*:0
16*:4 -> 1 | 1*:0 0*:0
16*:4 -> 2 | 2*:0 1*:0
16*:4 -> 8 | 8*:2 7*:1
16*:4 -> 70 | 74*:18 73*:18
16*:4 -> 10700 | 11311*:2827 11310*:2827
31713*:31713 -> 30000 | 31714*:31714 31713*:31713
UNDEF:20[N] -> 12 | 12*:0 12*:12
1*:0 -> 96 | 101*:0 100*:0
2*:1 -> 96 | 101*:50 100*:50

OLD GET FAIL 36 expected 35
OLD GET FAIL 71 expected 70
OLD GET FAIL 106 expected 105
OLD GET FAIL 141 expected 140
OLD GET FAIL 176 expected 175
*/
