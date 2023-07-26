/* $Id: terraform_cmd.cpp 20748 2010-09-05 16:00:36Z yexo $ */

/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <http://www.gnu.org/licenses/>.
 */

/** @file terraform_cmd.cpp Commands related to terraforming. */

#include "stdafx.h"
#include "openttd.h"
#include "command_func.h"
#include "tunnel_map.h"
#include "bridge_map.h"
#include "tunnelbridge.h"
#include "functions.h"
#include "economy_func.h"
#include "genworld.h"
#include "debug.h"

#include "core/alloc_func.hpp"
#include "table/strings.h"

#include <vector>
#include <set>
#include <map>

/** For any tile, the heightlevels which are possible for that tile depend on
 *  its neighbor tiles.  For example, if tile (5,4) has height 7, then tile (4,4)
 *  must have at least height 6 and at most height 8.  If its height would be outside
 *  this range, OpenTTDs assumptions about map geometry would be violated.
 *  An instance of this struct stores one such range of allowed heightlevels.
 */
struct TerraformerTileInfo {
	uint16 min_allowed_height;
	uint16 max_allowed_height;
};

TileIndex _terraform_err_tile; ///< first tile we couldn't terraform

/* Currently not used debug functions that maybe useful at some time in the futura.
   Calls to these functions are outcommented in the code below.
static void GenerateDebugOutputForBounds(std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds)
{
	DEBUG(map, 0, "Number of bounds: %i",
			tile_to_bounds.size());

	for (std::map<TileIndex, TerraformerTileInfo>::iterator tile_iterator = tile_to_bounds.begin();
			tile_iterator != tile_to_bounds.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;
		TerraformerTileInfo info = tile_iterator->second;

	DEBUG(map, 9, "Bounds for tile (%i,%i) are (%i <= h <= %i)",
			TileX(tile), TileY(tile), info.min_allowed_height, info.max_allowed_height);
	}
}

static void GenerateDebugOutputForHeights(std::map<TileIndex, uint16> &tile_to_height)
{
	DEBUG(map, 9, "Number of heights: %i", tile_to_height.size());

	for (std::map<TileIndex, uint16>::iterator tile_iterator = tile_to_height.begin();
			tile_iterator != tile_to_height.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;
		uint16 height = tile_iterator->second;

		DEBUG(map, 9, "New height for tile (%i,%i) is %i",
				TileX(tile), TileY(tile), height);
	}
}
*/

/**
 * Registers a bound (height, height) for the given tile in the given
 * tile_to_bounds map. Useful for building up the map for
 * ComputeTerraformingBounds based on some input data.
 * Note that the given height must be legal in the sense that it must
 * be in the range [0 .. GetMaxTileHeight()].
 *
 * @param tile_to_bounds map from tiles to heightlevel bounds
 * @param tile any tile; if it was already in the tile_to_bounds map, its entry will be overwritten.
 * @param height the bound of the given tile will be (height, height).
 */
void RegisterTerraformerHeight(std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds, TileIndex tile, uint16 height)
{
	TerraformerTileInfo tileInfo;
	tileInfo.min_allowed_height = height;
	tileInfo.max_allowed_height = height;
	tile_to_bounds[tile] = tileInfo;

	DEBUG(map, 5, "Number of bounds: %i", (int)tile_to_bounds.size());
}

/** Registers a bound (height + direction, height + direction) for the
 *  given tile in the given tile_to_bounds map, where height denotes
 *  the current height of the given tile on the map.  Useful for 
 *  building up the map for ComputeTerraformingBounds based on some input data.
 *  Throws an error, if height + direction would lead to an illegal
 *  heightlevel outside [0 .. GetMaxTileHeight()].
 *  @param tile any tile, if it was already in the tile_to_bounds map its entry will be overwritten
 *  @param direction +1 or -1, depending on wether the tile should be raised or lowered
 *  @param tile_to_bounds map from tiles to heightlevel bounds
 *  @return zero cost instance, or an error if height + direction would
 *               lead to an illegal heightlevel
 */
static CommandCost CheckAndRegisterHeightBeforeTerraforming
        (TileIndex tile, int direction,
		 std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds)
{
	uint16 old_height = TileHeight(tile);

	if (old_height == 0 && direction < 0) {
		return_cmd_error(STR_ERROR_ALREADY_AT_SEA_LEVEL);
	}

	if (old_height == GetMaxTileHeight() && direction > 0) {
		return_cmd_error(STR_ERROR_TOO_HIGH);
	}

	uint16 new_height = (uint16)(old_height + direction);
	RegisterTerraformerHeight(tile_to_bounds, tile, new_height);

	CommandCost no_cost_here(EXPENSES_CONSTRUCTION);
	return no_cost_here;
}



/**
 * Constructs the dirty tiles set based on the given map specifying
 * which tile should be terraformed to which height.
 */
std::set<TileIndex> InitializeDirtyTilesVector(std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds)
{
	/* dirty_tiles stores the tiles that will be observed in this step. */
	std::set<TileIndex> dirty_tiles;

	for (std::map<TileIndex, TerraformerTileInfo>::iterator tile_iterator = tile_to_bounds.begin();
			tile_iterator != tile_to_bounds.end();
			tile_iterator++) {
		dirty_tiles.insert(tile_iterator->first);
	}

	return dirty_tiles;
}

/**
 * Returns a new TerraformerTileInfo instance whose bounds equal to the
 * given bounds expanded by one.  If the bounds of base were 0 or 
 * GetMaxTileHeight, we simply copy them.
 * This function is used for getting new bounds based on other bounds.
 * Example: If tile (5,4) has bound (7,7), then tile (5,5) has bounds (6,8)
 * (if we assume the absence of further bounds for the sake of this example).
 * @param base any TerraformerTileInfo instance
 * @return TerraformerTileInfo instance with bounds expanded by one
 */
inline TerraformerTileInfo ExpandBounds(TerraformerTileInfo &base)
{
	TerraformerTileInfo dest;

	if (base.min_allowed_height == 0) {
		dest.min_allowed_height = 0;
	} else {
		dest.min_allowed_height = (uint16)(base.min_allowed_height - 1);
	}

	if (base.max_allowed_height == GetMaxTileHeight()) {
		dest.max_allowed_height = GetMaxTileHeight();
	} else {
		dest.max_allowed_height = (uint16)(base.max_allowed_height + 1);
	}

	return dest;
}

/**
 * Here, given a map storing the new heightlevels we want to reach, for all
 * tiles touched by this, the heightlevel bounds according to those conditions
 * in the map are calculated.
 *
 * Example:
 * You have some tile at height 3, want to rise it to height 4.
 * This means, that afterwards, all four neighbor tiles need to have
 * something between height 3 and height 5.
 * So, initially, you insert a entry (tile, bound(4,4)) into the map.
 * The algorithm then inserts additional entries (tileFoo, bound(3,5))
 * into the map.
 * The map may contain any number of entries. If satisfying all those bounds
 * is impossible, an error is thrown (e.g. if you require the neighbor tile of
 * our (4,4) tile having bounds (17,17)).  However, this case is only
 * theoretically possible as part of the algorithm.  You cannot run into it
 * using the currently available terraforming tools.
 *
 * The algorithm works as follows:
 * We have sets L, L_new of dirty tiles; min(tile) and max(tile) are the lower
 * and upper bounds of some tile, saved in the map mentioned above. Initially,
 * all tiles with bounds (i.e. all that are in the map) are added to L.
 * Then, while L is not empty, we do the following:
 *     for all tiles f_l in L, do:
 *         if the real height of f_l is within min(f_l) .. max(f_l), given the
 *             present information this tile will not need to be terraformed,
 *             so, we do nothing for it. (1)
 *         else for all neighbors f_a of f_l, calculate their new bounds.
 *             We need to intersect the bounds (min(f_l)-1,max(f_l)+1) with
 *             the bounds f_a already has.
 *                 If this intersection is empty,
 *                     terraforming is not possible (2).
 *                 Otherwise, if the bound of f_a changed or is new,
 *                     add it to the dirty tiles.
 *
 * Notes:
 * (1)
 * Maybe we get a bound outside this range later, but then we process it
 * again anyway.
 * Example:
 * We require (32,14) having height 4. Then,
 * (32,12) must have at least height 2. If it already has height 2,
 * everything is fine. But what if we also require (32,9) having
 * height 6? Then, the algorithm will at some later time reach (32,12)
 * from (32,9), requiring height 3.
 *
 * (2)
 * E.g. if we require (65,5) having height 6 and (67,5) height 14.
 *
 * @param tile_to_bounds map from TileIndex to TerraformerTileInfo, will be
 *                        changed during the algorithm, containing all bounds
 *                        resulting out of this terraforming afterwards.
 *                        Initially, this contains the heightlevel information
 *                        we require as a result of terraforming.
 *                        May not contain illegal heightlevels outside a range of
 *                        0 .. GetMaxTileHeight!
 * @return no cost, as we don't calculate costs here, but maybe some error
 */
static CommandCost ComputeTerraformingBounds(std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds)
{
	std::set<TileIndex> dirty_tiles = InitializeDirtyTilesVector(tile_to_bounds);

	/* Dirty_tiles_next_step stores the tiles that will be observed in the next
	 * step. */
	std::set<TileIndex> dirty_tiles_next_step;

	/* Compute bounds for the height levels of "near" tiles taking the values
	 * from tile_to_bounds into account until they are consistent with each
	 * other and with the existent height levels of the untouched tiles. */
	while(dirty_tiles.size() > 0) {
		/* This still contains the dirty_tiles from the previous step. */
		dirty_tiles_next_step.clear();

		DEBUG(map, 5, "Starting outer loop with %i dirty tiles",
				(int)dirty_tiles.size());

		/* Now have a look on each dirty tiles, checking wether its old height level
		 * is within the calculated bounds. If yes, everything is fine, if no,
		 * we need to have a look on its neighbors. */
		for (std::set<TileIndex>::const_iterator dirty_tiles_iterator = dirty_tiles.begin();
				dirty_tiles_iterator != dirty_tiles.end();
				dirty_tiles_iterator++) {
			TileIndex dirty_tile = *dirty_tiles_iterator;

			DEBUG(map, 5, "Dirty tile is %x (%i, %i)",
					dirty_tile, TileX(dirty_tile), TileY(dirty_tile));

			uint16 dirty_tile_height = TileHeight(dirty_tile);
			TerraformerTileInfo dirty_tile_info = tile_to_bounds[dirty_tile];

			DEBUG(map, 5, "dirty_tile_height is %i, bound is (%i <= h <= %i)",
					dirty_tile_height, dirty_tile_info.min_allowed_height,
					dirty_tile_info.max_allowed_height);

			/* If freeform edges are not allowed, height of the map border may
			 * not be altered. */
			if (!_settings_game.construction.freeform_edges 
					&& IsOnMapEdge(dirty_tile) 
					&& dirty_tile_info.min_allowed_height > 0) {
				_terraform_err_tile = dirty_tile;
				return_cmd_error(STR_ERROR_TOO_CLOSE_TO_EDGE_OF_MAP);
			}

			/* We need the bounds of dirty_tile_info, but expanded by one, later. */
			TerraformerTileInfo expanded_dirty_tile_info = ExpandBounds(dirty_tile_info);

			if (dirty_tile_height < dirty_tile_info.min_allowed_height || dirty_tile_height > dirty_tile_info.max_allowed_height) {
				/* Determine neighbor tiles, but avoid leaving the map (without these checks,
				 * leaving the map would be possible in case of freeform edges allowed, if
				 * not the STR_ERROR_TOO_CLOSE_TO_EDGE_OF_MAP error above would prevent us
				 * from going here when dirty_tile is on the edge of map. */
				std::vector<TileIndex> neighbors;

				if (TileY(dirty_tile) < MapMaxY()) {
					neighbors.push_back(dirty_tile + TileDiffXY(0,1));
				}

				if (TileX(dirty_tile) < MapMaxX()) {
					neighbors.push_back(dirty_tile + TileDiffXY(1,0));
				}

				if (TileY(dirty_tile) > 0) {
					neighbors.push_back(dirty_tile + TileDiffXY(0,-1));
				}

				if (TileX(dirty_tile) > 0) {
					neighbors.push_back(dirty_tile + TileDiffXY(-1,0));
				}

				for (std::vector<TileIndex>::iterator neighbor_iterator = neighbors.begin();
						neighbor_iterator != neighbors.end();
						neighbor_iterator++) {
					TileIndex neighbor = *neighbor_iterator;

					DEBUG(map, 9, "Inspecting neighbor tile %i (%i, %i)",
							neighbor, TileX(neighbor), TileY(neighbor));

					std::map<TileIndex, TerraformerTileInfo>::iterator neighbor_info_iterator = tile_to_bounds.find(neighbor);

					bool no_bounds_before = (neighbor_info_iterator == tile_to_bounds.end());
					bool bounds_changed = true;

					if (no_bounds_before) {
						/* We have not yet inspected that neighbor tile. So we have no bounds for it yet.
						 * So, for its height anything between one height higher and one heightlevel
						 * lower is ok. Compare the discussion in the doc of ExpandBounds. */
						TerraformerTileInfo neighbor_info = ExpandBounds(dirty_tile_info);
						tile_to_bounds[neighbor] = neighbor_info;

						DEBUG(map, 5, "No bounds before, so neighbor bounds are (%i <= h <= %i)",
								neighbor_info.min_allowed_height, neighbor_info.max_allowed_height);
					} else {
						TerraformerTileInfo neighbor_info = neighbor_info_iterator->second;
						TerraformerTileInfo old_neighbor_info;
						old_neighbor_info.min_allowed_height = neighbor_info.min_allowed_height;
						old_neighbor_info.max_allowed_height = neighbor_info.max_allowed_height;
						uint16 dmin = expanded_dirty_tile_info.min_allowed_height;
						uint16 dmax = expanded_dirty_tile_info.max_allowed_height;

						/* We had some bound before for the neighbor tile. However, by being a neighbor
						 * of dirty_tile, there is another bound. So, we have to take the intersection
						 * of both as new bound of the neighbor tile. */
						neighbor_info.min_allowed_height = max(neighbor_info.min_allowed_height, dmin);
						neighbor_info.max_allowed_height = min(neighbor_info.max_allowed_height, dmax);

						/* The intersection is empty! This means, no terraforming satisfying all the
						 * bounds in the input data is possible, so the whole terraforming must fail. */
						if (neighbor_info.min_allowed_height > neighbor_info.max_allowed_height) {
							_terraform_err_tile = neighbor; ///< highlight the tile
							return_cmd_error(STR_ERROR_INCONSISTENT_TERRAFORM_BOUNDARIES);
						}

						DEBUG(map, 5, "We had bounds before, intersection is (%i <= h <= %i)",
								neighbor_info.min_allowed_height, neighbor_info.max_allowed_height);

						bounds_changed = (old_neighbor_info.min_allowed_height != neighbor_info.min_allowed_height)
								|| (old_neighbor_info.max_allowed_height != neighbor_info.max_allowed_height);
					}

					/* If there were no bounds before, we have to insert it in order to check in the
					 * next iteration wether its real height is within the bounds.
					 *
					 * If no, its neighbors will be inspected. If yes, it will remain with this
					 * bounds in the map. This is necessary, because if from some other side,
					 * we ever reach this tile again, we have to know that it has bounds.
					 * (Otherwise, in such a case we might cause inconsistent heightlevels.)
					 *
					 * If there were bounds, and they have changed, this means that we have to
					 * reinspect the neighbors, because this will probably change their bounds too. */
					if (no_bounds_before || bounds_changed) {
						dirty_tiles_next_step.insert(neighbor);

						DEBUG(map, 5, "Inserting neighbor %i (%i, %i) into dirty_tiles_next_step",
								neighbor, TileX(neighbor), TileY(neighbor));
					}
				}
			}
		}

		/* Prepare for the next step. According to http://www.sgi.com/tech/stl/Container.html#9,
		 * we have a fair chance that this operation is O(1). */
		dirty_tiles.swap(dirty_tiles_next_step);
	}

	CommandCost cost(EXPENSES_CONSTRUCTION);
	return cost;
}

/**
 * This method takes the bound information in the given tile_to_bounds map and
 * calculates updated heights based on this and stores the result in the
 * tile_to_heights map.
 * The information in tile_to_bounds is expected to be consistent.
 * For any tile with old height below its lower bound, the new height will be the lower bound,
 * for each tile with old height above its upper bound, the new height will be the upper bound.
 * So, the bounds are expected to be of a type where this is possible without getting an inconsistent
 * map afterwards.
 * Taking ComputeTerraformingBounds into account, this works, because if
 * in ComputeTerraformingBounds we compute a bound outside the current height,
 * we always calculate bounds for all neighbor-tiles as well.
 * So, we have something like the following:
 *
 * XXXXXXX
 * XXIIIIX
 * XIIOOIX
 * XIOOOIX
 * XIOOOIX
 * XIIIIIX
 * XXXXXXX
 *
 * Where X are tiles not in tile_to_bounds,
 * I tiles in tile_to_bounds where the old heightlevel is inside the bounds,
 * and finally O are tiles where the old heightlevel is outside the new bounds.
 * And only the height of tiles in O needs to be updated.
 *
 * @param tile_to_bounds bounds as described.
 * @param tile_to_height the updated heightlevel information will be written here usually,
 *                                         this map will be empty before, but this is not required.
 * @return Costs for the heightlevel changes, but not for things like removing trees,
 *                                                                          terraforming below houses, etc.
 */
static CommandCost CalculateNewHeights(std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds, std::map<TileIndex, uint16> &tile_to_height)
{
	CommandCost cost(EXPENSES_CONSTRUCTION);

	for (std::map<TileIndex, TerraformerTileInfo>::iterator tile_iterator = tile_to_bounds.begin();
			tile_iterator != tile_to_bounds.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;
		TerraformerTileInfo bounds = tile_iterator->second;

		DEBUG(map, 9, "CalculateNewHeights: Processing tile (%i,%i) with index %i, having bounds (%i,%i); MapSize = %i",
				TileX(tile), TileY(tile), (int)tile, bounds.min_allowed_height, bounds.max_allowed_height, MapSize());

		uint16 old_height = TileHeight(tile);

		if (old_height < bounds.min_allowed_height) {
			cost.AddCost(_price[PR_TERRAFORM] * (bounds.min_allowed_height - old_height));
			tile_to_height[tile] = bounds.min_allowed_height;
		}

		if (old_height > bounds.max_allowed_height) {
			cost.AddCost(_price[PR_TERRAFORM] * (old_height - bounds.max_allowed_height));
			tile_to_height[tile] = bounds.max_allowed_height;
		}

		DEBUG(map, 9, "CalculateNewHeights: Done with index %i", (int)tile);
	}

	return cost;
}

/**
 * Returns the height of the given tile, based both on the map of future
 * heightlevels and on reality. The former overwrites the latter.
 *
 * @param tile_to_height the tile to heightlevels map, contains all heights that will have changed as result of terraforming.
 * @param tile Tile.
 */
static uint16 GetHeightFromMapOrReality(std::map<TileIndex, uint16> &tile_to_height, TileIndex tile)
{
	std::map<TileIndex, uint16>::iterator tile_iterator = tile_to_height.find(tile);

	if (tile_iterator == tile_to_height.end()) {
		return TileHeight(tile);
	} else {
		return tile_iterator->second;
	}
}

/**
 * Adds all tiles northeast, northwest or north to tiles already
 * in the tile_to_height map to the tile_to_height map. Needed because 
 * otherwise, certain necessary callback functions wouldn't be called.
 *
 * @param tile_to_height the tile_to_height map.
 */
static void AddTilesAroundToMap(std::map<TileIndex, uint16> &tile_to_height)
{
	std::set<TileIndex> new_tiles;

	for (std::map<TileIndex, uint16>::iterator tile_iterator = tile_to_height.begin();
			tile_iterator != tile_to_height.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;

		if (TileX(tile) > 0) {
			TileIndex nw_tile = tile + TileDiffXY(-1,0);

			if (tile_to_height.find(nw_tile) == tile_to_height.end()) {
				new_tiles.insert(nw_tile);
			}
		}

		if (TileY(tile) > 0) {
			TileIndex ne_tile = tile + TileDiffXY(0,-1);

			if (tile_to_height.find(ne_tile) == tile_to_height.end()) {
				new_tiles.insert(ne_tile);
			}
		}

		if (TileX(tile) > 0 && TileY(tile) > 0) {
			TileIndex n_tile = tile + TileDiffXY(-1,-1);

			if (tile_to_height.find(n_tile) == tile_to_height.end()) {
				new_tiles.insert(n_tile);
			}
		}
	}

	for (std::set<TileIndex>::iterator new_tiles_iterator = new_tiles.begin();
			new_tiles_iterator != new_tiles.end();
			new_tiles_iterator++) {
		TileIndex tile = *new_tiles_iterator;
		/* We only select tiles that were not in the tile_to_height map before.
		 * So calling GetHeightFromMapOrReality would not make sense. */
		uint16 height = TileHeight(tile);
		tile_to_height[tile] = height;
	}
}

static CommandCost CheckAndUpdateObjectsAfterTerraforming(std::map<TileIndex, uint16> &tile_to_height, DoCommandFlag flags)
{
	CommandCost total_update_cost(EXPENSES_CONSTRUCTION);

	for (std::map<TileIndex, uint16>::iterator tile_iterator = tile_to_height.begin();
			tile_iterator != tile_to_height.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;
		uint16 height = tile_iterator->second;

		DEBUG(map, 9, "CheckAndUpdateObj: Inspecting tile %i", tile);

		/* Find new heights of tile corners. If the tile is on the edge of map,
		 * the other tile corners have the same height as the north corner. */
		uint z_N = height;
		uint z_W, z_S, z_E;

		if (TileX(tile) < MapMaxX()) {
			z_W = GetHeightFromMapOrReality(tile_to_height, tile + TileDiffXY(1, 0));
		} else {
			z_W = z_N;
		}

		if (TileX(tile) < MapMaxX() && TileY(tile) < MapMaxY()) {
			z_S = GetHeightFromMapOrReality(tile_to_height, tile + TileDiffXY(1, 1));
		} else {
			z_S = z_N;
		}

		if (TileY(tile) < MapMaxY()) {
			z_E = GetHeightFromMapOrReality(tile_to_height, tile + TileDiffXY(0, 1));
		} else {
			z_E = z_N;
		}

		/* Find min and max height of tile. */
		uint z_min = min(min(z_N, z_W), min(z_S, z_E));
		uint z_max = max(max(z_N, z_W), max(z_S, z_E));

		/* Compute tile slope. */
		Slope tileh = (z_max > z_min + 1 ? SLOPE_STEEP : SLOPE_FLAT);

		if (z_W > z_min) {
			tileh |= SLOPE_W;
		}

		if (z_S > z_min) {
			tileh |= SLOPE_S;
		}

		if (z_E > z_min) {
			tileh |= SLOPE_E;
		}

		if (z_N > z_min) {
			tileh |= SLOPE_N;
		}

		/* Check if bridge would take damage. */
		if (MayHaveBridgeAbove(tile) && IsBridgeAbove(tile)) {
			uint bridge_height = GetBridgeHeight(GetSouthernBridgeEnd(tile));

			if (bridge_height <= z_max * TILE_HEIGHT) {
				_terraform_err_tile = tile; ///< highlight the tile under the bridge
				return_cmd_error(STR_ERROR_MUST_DEMOLISH_BRIDGE_FIRST);
			}

			/* Is the bridge above not too high afterwards?
			 * @see tunnelbridge_cmd.cpp for a detailed discussion. */
			if (bridge_height > (z_min + MAX_BRIDGE_HEIGHT) * TILE_HEIGHT) {
				_terraform_err_tile = tile;
				return_cmd_error(STR_ERROR_BRIDGE_TOO_HIGH_AFTER_LOWER_LAND);
			}
		}

		/* Check if tunnel would take damage. */
		if (IsTunnelInWay(tile, z_min * TILE_HEIGHT)) {
			_terraform_err_tile = tile; ///< highlight the tile above the tunnel
			return_cmd_error(STR_ERROR_EXCAVATION_WOULD_DAMAGE);
		}

		/* Check tiletype-specific things, and add extra-cost. */
		const bool curr_gen = _generating_world;

		if (_game_mode == GM_EDITOR) {
			_generating_world = true; ///< used to create green terraformed land.
		}

		CommandCost update_cost = _tile_type_procs[GetTileType(tile)]->terraform_tile_proc(tile, flags | DC_AUTO, z_min * TILE_HEIGHT, tileh);

		DEBUG(map, 9, "CheckAndUpdateObj: Update cost for tile %i is %lld",
				tile, (int64)update_cost.GetCost());

		_generating_world = curr_gen;

		if (update_cost.Failed()) {
		_terraform_err_tile = tile;
		return update_cost;
		}

		total_update_cost.AddCost(update_cost);
	}

	return total_update_cost;
}

/** Executes terraforming, i.e. sets the heights of all tiles in the given map as
 *  specified in the map, and then takes care about repainting.
 *  @param tile_to_height map from tiles to intended heightlevels
 */
static void ExecuteTerraforming(std::map<TileIndex, uint16> &tile_to_height)
{
	for (std::map<TileIndex, uint16>::iterator tile_iterator = tile_to_height.begin();
			tile_iterator != tile_to_height.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;
		uint16 height = tile_iterator->second;

		SetTileHeight(tile, height);
	}

	/* Finally mark the dirty tiles dirty.
	 * I don't know wether I have to fear some thread synchronization problems
	 * if I do this in the previous loop, so I do it here separately afterwards. */
	for (std::map<TileIndex, uint16>::iterator tile_iterator = tile_to_height.begin();
			tile_iterator != tile_to_height.end();
			tile_iterator++) {
		TileIndex tile = tile_iterator->first;
		uint16 height = tile_iterator->second;

		MarkTileDirtyByTile(tile);
		/* Now, if we alter the height of the map edge, we need to take care
		 * about repainting the affected areas outside map as well.
		 * Remember:
		 * Outside map, we assume that our landscape descends to
		 * height zero as fast as possible.
		 * Those simulated tiles (they don't exist as datastructure,
		 * only as concept in code) need to be repainted properly,
		 * otherwise we will get ugly glitches.
		 *
		 * Furthermore, note that we have to take care about the possibility,
		 * that landscape was higher before the change,
		 * so also tiles a bit outside need to be repainted. */
		int x = TileX(tile);
		int y = TileY(tile);

		if (x == 0) {

			if (y == 0) {
				/* Height of the northern corner is altered. */
				for (int cx = 0; cx >= -height - 1; cx--) {
					for (int cy = 0; cy >= -height - 1; cy--) {
						/* This means, tiles in the sector north of that
						 * corner need to be repainted. */

						if (cx + cy >= -height - 2) {
							/* But only tiles that actually might have changed. */
							MarkTileDirtyByTileOutsideMap(cx, cy);
						}
					}
				}
			} else if (y < (int)MapMaxY()) {
				for (int cx = 0; cx >= -height - 1; cx--) {
					MarkTileDirtyByTileOutsideMap(cx, y);
				}
			} else {
				for (int cx = 0; cx >= -height - 1; cx--) {
					for (int cy = (int)MapMaxY(); cy <= (int)MapMaxY() + height + 1; cy++) {

						if (cx + ((int)MapMaxY() - cy) >= -height - 2) {
							MarkTileDirtyByTileOutsideMap(cx, cy);
						}
					}
				}
			}

		} else if (x < (int)MapMaxX()) {

			if (y == 0) {
				for (int cy = 0; cy >= -height - 1; cy--) {
					MarkTileDirtyByTileOutsideMap(x, cy);
				}
			} else if (y < (int)MapMaxY()) {
				/* Nothing to be done here, we are inside the map. */
			} else {
				for (int cy = (int)MapMaxY(); cy <= (int)MapMaxY() + height + 1; cy++) {
					MarkTileDirtyByTileOutsideMap(x, cy);
				}
			}

		} else {

			if (y == 0) {
				/* Height of the northern corner is altered. */
				for (int cx = (int)MapMaxX(); cx <= (int)MapMaxX() + height + 1; cx++) {
					for (int cy = 0; cy >= -height - 1; cy--) {
						if (((int)MapMaxX() - cx) + cy >= -height - 2) {
							MarkTileDirtyByTileOutsideMap(cx, cy);
						}
					}
				}
			} else if (y < (int)MapMaxY()) {
				for (int cx = (int)MapMaxX(); cx <= (int)MapMaxX() + height + 1; cx++) {
					MarkTileDirtyByTileOutsideMap(cx, y);
				}
			} else {
				for (int cx = (int)MapMaxX(); cx <= (int)MapMaxX() + height + 1; cx++) {
					for (int cy = (int)MapMaxY(); cy <= (int)MapMaxY() + height + 1; cy++) {

						if (((int)MapMaxX() - cx) + ((int)MapMaxY() - cy) >= -height - 2) {
							MarkTileDirtyByTileOutsideMap(cx, cy);
						}
					}
				}
			}
		}
	}
}

static CommandCost Terraform(std::map<TileIndex, TerraformerTileInfo> &tile_to_bounds, DoCommandFlag flags)
{
	CommandCost total_cost(EXPENSES_CONSTRUCTION);
	_terraform_err_tile = INVALID_TILE;

	/* First calculate bounds.
	 * See: Documentation of ComputeTerraformingBounds() for more information. */
	//std::map<TileIndex, TerraformerTileInfo> tile_to_bounds;
	//RegisterTerraformerHeight(tile_to_bounds, tile, (uint16)height);
	CommandCost bound_cost = ComputeTerraformingBounds(tile_to_bounds);

	//GenerateDebugOutputForBounds(tile_to_bounds);

	if (bound_cost.Failed()) {
		return bound_cost;
	} else {
		total_cost.AddCost(bound_cost);
	}

	DEBUG(map, 9, "beforeCalcNewHeights: total_cost = %lld", (int64)total_cost.GetCost());

	/* Then calculate updated heightlevels. */
	std::map<TileIndex, uint16> tile_to_height;
	CommandCost height_change_cost = CalculateNewHeights(tile_to_bounds, tile_to_height);

	//GenerateDebugOutputForHeights(tile_to_height);

	if (height_change_cost.Failed()) {
		return height_change_cost;
	} else {
		total_cost.AddCost(height_change_cost);
	}

	AddTilesAroundToMap(tile_to_height);

	DEBUG(map, 9, "beforeObjects: total_cost = %lld", (int64)total_cost.GetCost());

	/* Finally do stuff like checking for bridges and tunnels in the way,
	 * applying foundations, etc. */
	CommandCost update_cost = CheckAndUpdateObjectsAfterTerraforming(tile_to_height, flags);

	if (update_cost.Failed()) {
		return update_cost;
	} else {
		total_cost.AddCost(update_cost);
	}

	DEBUG(map, 9, "beforeExec: total_cost = %lld", (int64)total_cost.GetCost());

	/* And, don't forget, execute... (although things like foundations seem to be executed in the previous block.) */
	if (flags & DC_EXEC) {
		ExecuteTerraforming(tile_to_height);
	}

	DEBUG(map, 9, "beforeEnd: total_cost = %lld", (int64)total_cost.GetCost());

	return total_cost;
}

/**
 * Terraform land
 * @param tile tile to terraform
 * @param flags for this command type
 * @param p1 corners to terraform (SLOPE_xxx)
 * @param p2 direction; eg up (non-zero) or down (zero)
 * @param text unused
 * @return the cost of this operation or an error
 */
CommandCost CmdTerraformLand(TileIndex tile, DoCommandFlag flags, uint32 p1, uint32 p2, const char *text)
{
	std::map<TileIndex, TerraformerTileInfo> tile_to_bounds;

	/* Decode... */
	int direction = (p2 != 0 ? 1 : -1);

	/* Register wanted height changes. */
	if ((p1 & SLOPE_W) != 0) {
		TileIndex t = tile + TileDiffXY(1, 0);
		CommandCost cost = CheckAndRegisterHeightBeforeTerraforming(t, direction, tile_to_bounds);

		if (cost.Failed()) {
			return cost;
		}
	}

	if ((p1 & SLOPE_S) != 0) {
		TileIndex t = tile + TileDiffXY(1, 1);
		CommandCost cost = CheckAndRegisterHeightBeforeTerraforming(t, direction, tile_to_bounds);

		if (cost.Failed()) {
			return cost;
		}
	}

	if ((p1 & SLOPE_E) != 0) {
		TileIndex t = tile + TileDiffXY(0, 1);
		CommandCost cost = CheckAndRegisterHeightBeforeTerraforming(t, direction, tile_to_bounds);

		if (cost.Failed()) {
			return cost;
		}
	}

	if ((p1 & SLOPE_N) != 0) {
		TileIndex t = tile + TileDiffXY(0, 0);
		CommandCost cost = CheckAndRegisterHeightBeforeTerraforming(t, direction, tile_to_bounds);

		if (cost.Failed()) {
			return cost;
		}
	}

	return Terraform(tile_to_bounds, flags);
}

/**
 * Levels a selected (rectangle) area of land
 *
 * @param tile end tile of area-drag
 * @param flags for this command type
 * @param p1 start tile of area drag
 * @param p2 height difference; eg raise (+1), lower (-1) or level (0)
 * @param text unused
 * @return execute this operation or an error (no costs here)
 */
CommandCost CmdLevelLand(TileIndex tile, DoCommandFlag flags, uint32 p1, uint32 p2, const char *text)
{
	/* Remember level height. */
	uint oldh = TileHeight(p1);
	int direction = p2;

	/* Check range of destination height. */
	if (oldh == 0 && direction < 0) {
		return_cmd_error(STR_ERROR_ALREADY_AT_SEA_LEVEL);
	}

	if (oldh >= GetMaxTileHeight() && direction > 0) {
		return_cmd_error(STR_ERROR_TOO_HIGH);
	}

	/* Compute new height. */
	uint16 new_height = (uint16)(oldh + p2);

	std::map<TileIndex, TerraformerTileInfo> tile_to_bounds;
	TileArea ta(tile, p1);
	TILE_AREA_LOOP(tile, ta) {
		RegisterTerraformerHeight(tile_to_bounds, tile, new_height);
	}

	CommandCost overallCost = Terraform(tile_to_bounds, flags);
	if (!overallCost.Failed() && overallCost.GetCost() == 0) {
		return_cmd_error(STR_ERROR_ALREADY_LEVELLED);
	} else {
		// Failed: Return cost instance with error information
		// Not failed: Return cost instance with cost information
		return overallCost;
	}
}
