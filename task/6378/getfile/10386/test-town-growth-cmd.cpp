/* g++ test-towng-growth-cmd.cpp -I src --std=c++11 */

#include "stdafx.h"
#include "core/bitmath_func.hpp"
#include "date_type.h"

#include <iostream>

using namespace std;


static const uint8 _settings_town_growth_rate = 3;

static const uint16 TOWN_GROW_RATE_UNDEFINED   = 0x7FFF; ///< Special value for Town::growth_rate to indicate that growth rate is not calcuted yet.
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


static void UpdateTownGrowRate(Town *t)
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
	UpdateTownGrowRate(t);
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

bool NewCmdTownGrowthRate(Town *t, uint32 p2) {
	// if (_current_company != OWNER_DEITY) return false;
	if ((p2 & TOWN_GROW_RATE_CUSTOM) != 0 && p2 != TOWN_GROW_RATE_CUSTOM_NONE &&
			p2 != TOWN_GROW_RATE_NORMAL) return false;
	if (GB(p2, 16, 16) != 0) return false;

	// Town *t = Town::GetIfValid(p1);
	// if (t == NULL) return CMD_ERROR;

	// if (flags & DC_EXEC) {

	if (p2 == TOWN_GROW_RATE_NORMAL) {
		/* UpdateTownGrowRate will determine a proper value */
		t->growth_rate = TOWN_GROW_RATE_UNDEFINED;
	} else if (p2 == TOWN_GROW_RATE_CUSTOM_NONE) {
		t->growth_rate = p2;
	} else if (t->growth_rate == TOWN_GROW_RATE_CUSTOM_NONE) {
		if (t->grow_counter >= p2) {
			t->grow_counter = p2;
		}
		t->growth_rate = p2 | TOWN_GROW_RATE_CUSTOM;
	} else {
		if (t->growth_rate != TOWN_GROW_RATE_UNDEFINED) {
			uint old_rate = t->growth_rate & ~TOWN_GROW_RATE_CUSTOM;
			if (t->grow_counter >= old_rate) {
				t->grow_counter = p2;
			} else {
				/* Scale grow_counter, so half finished houses stay half finished */
				t->grow_counter = t->grow_counter * p2 / old_rate;
				// t->grow_counter = ((2 * t->grow_counter + 1) * (p2 + 1)) / (2 * (old_rate + 1));
				// if (t->grow_counter > 0) t->grow_counter--;
				// t->grow_counter = ((t->grow_counter + 1) * (p2 + 1) + (old_rate + 1) / 2) / (old_rate + 1);
				// if (t->grow_counter > 0) t->grow_counter--;
			}
		} else if (t->grow_counter >= p2) {
			t->grow_counter = p2;
		}
		t->growth_rate = p2 | TOWN_GROW_RATE_CUSTOM;
		// cout << " [" << t->grow_counter << " " << old_rate << "] ";
	}
	UpdateTownGrowRate(t);

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
			growth_rate = (days_between_town_growth * DAY_TICKS + TOWN_GROWTH_TICKS / 2) / TOWN_GROWTH_TICKS;
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
	else if (growth_rate == TOWN_GROW_RATE_UNDEFINED)
		cout << "UNDEF";
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

void TestCmd(uint16 growth_rate, uint16 grow_counter,
			 uint8 n_stations, bool growth_rate_updated,
			 uint32 growth_arg,
			 uint16 expected_gr, uint16 expected_gc) {
	Town t_old {
		.flags = (byte)(n_stations ? 1 << TOWN_IS_GROWING : 0),
		.cache = {.num_houses = 30},
		.grow_counter = grow_counter,
		.growth_rate = growth_rate,
		.fund_buildings_months = 0,
		.larger_town = true,
		.n_stations = n_stations,
	};
	if (growth_rate_updated) UpdateTownGrowRate(&t_old);
	Town t_new = t_old;
	PrintTownState(t_old);
	if (!growth_rate_updated) cout << "[U]";
	cout << " -> ";
	PrintGrowthRate(growth_arg);
	cout << " | ";
	bool r_old = OldGSCmd(&t_old, growth_arg);
	bool r_new = NewGSCmd(&t_new, growth_arg);
	if (!r_old) cout << "ERROR:";
	PrintTownState(t_old);
	cout << " ";
	if (!r_new) cout << "ERROR:";
	PrintTownState(t_new);
	if (r_new && t_new.growth_rate == expected_gr &&
			t_new.grow_counter == expected_gc){}
		// cout << " OK";
	else {
		cout << " FAIL ";
		PrintGrowthRate(expected_gr);
		cout << ":" << expected_gc;
	}
	cout << endl;
}

int32 NewGetGrowthRate(const Town *t) {
	// if (!IsValidTown(town_id)) return -1;

	// const Town *t = ::Town::Get(town_id);

	if (t->growth_rate == TOWN_GROW_RATE_CUSTOM_NONE) return TOWN_GROW_RATE_CUSTOM_NONE;

	return (((t->growth_rate & ~TOWN_GROW_RATE_CUSTOM) + 1) * TOWN_GROWTH_TICKS + DAY_TICKS / 2) / DAY_TICKS;
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
	UpdateTownGrowRate(&t);
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
	uint16 UNDEF = TOWN_GROW_RATE_UNDEFINED;
	uint16 C = TOWN_GROW_RATE_CUSTOM;
	cout << "state -> new gr | old-state new-state test res" << endl;

	// any -> NONE  => NONE:old_gc
	TestCmd(12, 4, 5, true, NONE, NONE, 4);
	TestCmd(NONE, 4, 5, true, NONE, NONE, 4);
	TestCmd(16|C, 4, 5, true, NONE, NONE, 4);
	TestCmd(UNDEF, 4, 0, true, NONE, NONE, 4);
	cout << endl;

	// any -> NORMAL => updated_gr:old_gc
	TestCmd(32, 4, 5, false, NORMAL, 12, 4);
	TestCmd(12, 4, 5, true, NORMAL, 12, 4);
	TestCmd(32|C, 4, 5, true, NORMAL, 12, 4);
	TestCmd(NONE, 4, 5, true, NORMAL, 12, 4);
	TestCmd(12, 4, 0, true, NORMAL, UNDEF, 4);
	TestCmd(0, 4, 0, true, 12, 12|C, 12);
	TestCmd(UNDEF, 4, 0, true, 12, 12|C, 4);
	TestCmd(UNDEF, 4, 0, true, NORMAL, UNDEF, 4);
	cout << endl;

	// none -> custom => new_gr:old_gc
	TestCmd(NONE, 4, 5, true, 32, 33|C, 4);
	TestCmd(NONE, 21845, 5, true, 11, 12|C, 4);
	cout << endl;

	// normal -> custom => new_gr:scale_gc
	TestCmd(12, 4, 5, true, 32, 33|C, 11);
	cout << endl;

	// custom -> custom => new_gr:scaled_gc
	TestCmd(16|C, 4, 5, true, 0, 0|C, 0);
	TestCmd(16|C, 4, 5, true, 1, 0|C, 0);
	TestCmd(16|C, 4, 5, true, 2, 1|C, 0);
	TestCmd(16|C, 4, 5, true, 8, 7|C, 1);
	TestCmd(16|C, 4, 5, true, 70, 73|C, 18);
	TestCmd(16|C, 4, 5, true, 10700, 11310|C, 2827);
	TestCmd(31713|C, 31713, 5, true, 30000, 31713|C, 31713);
	TestCmd(UNDEF, 20, 0, true, 12, 12|C, 12);
	TestCmd(1|C, 0, 5, true, 96, 100|C, 0);
	TestCmd(2|C, 1, 5, true, 96, 100|C, 50);
	cout << endl;
	// TestCmd(1|C, 0, 5, true, 96, 100|C, 50);

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