// Jeremy's AI for OpenTTD: Main file

// Copyright (C) 2010 Jeremy Bennett
// Copyright (C) 2009 OpenTTD NoAI Developers Team

// Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>
// Contributor: Yexo and the NoAI Developers Team <yexo@openttd.org

// This file is part of JeremyAI for OpenTTD

// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3 of the License, or (at your option)
// any later version.

// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.

// You should have received a copy of the GNU General Public License along
// with this program.  If not, see <http://www.gnu.org/licenses/>.           
// ----------------------------------------------------------------------------
// Originally inspired by WriteAI.

// This code is commented throughout for use with Doxygen, although in the
// absence of Squirrel support, Doxygen probably won't process it that well.
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
//! Main class for the JeremyAI
// ----------------------------------------------------------------------------
class JeremyAI extends AIController
{
  // Useful constants. Squirrel as used within OpenTTD does not support
  // "const" or "enum", so these are just static class variables (no point in
  // having a copy for each instance). It's up to the user not to assign
  // values to them!

  //! Initial guess at money needed for new plane
  static INITIAL_PLANE_COST_ESTIMATE = 45000;

  //! Initial guess at lifetime of new plane
  static INITIAL_PLANE_LIFETIME_ESTIMATE = 24;

  //! Initial guess at average speed of new plane.
  
  //! Assumes 4:1 slowdown ratio, but will be corrected after the first plane
  //! is actually built.
  static INITIAL_PLANE_SPEED_ESTIMATE = 100;

  //! Initial guess at money needed for new airport
  static INITIAL_AIRPORT_COST_ESTIMATE = 15000;

  //! Largest value of mimimum distance we'll accept. This means the code will
  //! work for small and larage maps.
  static MIN_ROUTE_DIST_LIMIT = 50;

  //! Minimum acceptance required for an airport. The manual says this should
  //! be at least 8, but we use 10 for safety.
  static MIN_ACCEPTANCE = 10;

  //! Minimum productivity required for an airport (number of tiles within
  //! range which are productive). This is just to reduce the search space for
  //! airports - we already will only build the most productive.

  //! Experience suggests an airport is not really productive enough to
  //! support an aircraft until it has productivity of at least 15 (more
  //! realistically 17-18). However it may be worth building below this, to
  //! allow towns to grow around them. We could set the value to 0 - it just
  //! hugely inflates the cost of searching.

  //! However since we select on the sum of both airports productivity, we
  //! should not allow this too large. It is much better to have two airports
  //! of productivity 18 (both legs productive), than one of productivity 26
  //! and one of 10 (only one leg productive). Particularly early one, when
  //! with small airports we cannot handle the traffic from high capacity
  //! airports.

  //! TODO. This should be dynamic. If we have lots of cash and airports are
  //! hard to build we should relax. Otherwise we should be more demanding.
  static MIN_PRODUCTIVITY = 15;

  //! Time (in ticks) after selling an aircraft when buying new planes on the
  //! route is embargoed.
  static EMBARGO_TIME = 10000;

  //! Reasons why building an airport or aircraft may fail. In the fullness of
  //! time these should be an enum
  static BuildReason = 
    {
      OK                       =  0,
      NO_SUITABLE_AIRPORT      = -1
      AIRPORTS_NOT_FOUND       = -2,
      FIRST_AIRPORT_NOT_BUILT  = -3,
      SECOND_AIRPORT_NOT_BUILT = -4,
      NO_SUITABLE_AIRCRAFT     = -5,
      NO_AFFORDABLE_AIRCRAFT   = -6,
      AIRCRAFT_NOT_BUILT       = -7
    };

  // Reasons why a plane may not be selected. Should be an enum
  static PlaneSelectReason =
    {
      OK                =  0,
      OUT_OF_MONEY      = -1,
      OUT_OF_CARGO      = -2,
      NO_SMALL_PLANES   = -3,
      SELECTION_ERROR   = -4
    };

  // Various intervals
  static Intervals =
    {
      ROUTE_BUILD      =  1000,		//!< Initial time between routes
      ROUTE_BUILD_LONG = 10000,		//!< Time between routes when gets hard
      ROUTE_MANAGE     =  2000,		//!< Time between managing routes
      SLEEPING_TIME    =   100		//!< Time between main loops
    };

  //! The most recently selected plane engine. Can't be relied on to be valid
  //! long term (planes become obsolete, and IDs are reused).
  planeEngine = 0;

  //! Estimated cost of building a new plane
  planeCostEstimate = 0;

  //! Estimated lifetime of a new plane
  planeLifetimeEstimate = 0;

  //! Estimated max speed of a new plane
  planeSpeedEstimate = 0;

  //! Estimated cost of building a new airport
  airportCostEstimate = 0;

  //! Minimum (crow flies) distance of a route. This must be large enough for
  //! routes to be profitable, but not SO large there are not enough routes.
  minRouteDistance = 0;

  //! Mapping of airport tile locations to towns
  townMapping = null;

  //! List of towns connected so far. Maps town ID to airport tile.
  townsUsed = null;

  //! List of route origins for each vehicle
  routeOrigins = null;

  //! List of route destinations for each vehicle
  routeDestinations = null;

  //! List of periods for which buying any more planes on a route is
  //! embargoed. Triggered by selling an aircraft, and indexed off the origin
  routeBuyEmbargoTime = null;

  //! Year a plane was last unprofitable
  planeUnprofitableYear = null;

  //! List of planes heading for hangers
  planesToHanger = null;

  //! List of planes being upgraded
  upgradedPlanes = null;

  //! Time between building new routes. Initialized in constructor
  delayBuildAirportRoute = 0;

  //! ID of the passenger cargo type (or -1 if there are no passengers!)
  passengerCargoID = -1;

  //! Constructor
  constructor ()
    {
      // Initial route cost estimate
      this.planeCostEstimate     = this.INITIAL_PLANE_COST_ESTIMATE;
      this.planeLifetimeEstimate = this.INITIAL_PLANE_LIFETIME_ESTIMATE;
      this.planeSpeedEstimate    = this.INITIAL_PLANE_SPEED_ESTIMATE;
      this.airportCostEstimate   = this.INITIAL_AIRPORT_COST_ESTIMATE;

      // Minimum route distance for now is 5% of the map X + Y, but no more
      // than MIN_ROUTE_DIST_LIMIT.
      // direction.
      this.minRouteDistance = (AIMap.GetMapSizeX () + AIMap.GetMapSizeY ()) /
	                      20;

      if (this.minRouteDistance > MIN_ROUTE_DIST_LIMIT)
	{
	  this.minRouteDistance = MIN_ROUTE_DIST_LIMIT;
	}

      // Initial route delay from constant
      this.delayBuildAirportRoute = this.Intervals.ROUTE_BUILD;

      // Create empty versions of our main lists
      this.townsUsed             = AIList ();
      this.townMapping           = AIList ();
      this.routeOrigins          = AIList ();
      this.routeDestinations     = AIList ();
      this.routeBuyEmbargoTime   = AIList ();
      this.planeUnprofitableYear = AIList ();
      this.planesToHanger        = AIList ();
      this.upgradedPlanes        = AIList ();
      
      // Find the ID used for passenger cargo. If one isn't found, then it
      // will have the ID -1. The Start () function will return with an error
      // if this is detected.
      local list = AICargoList ();
      
      for (local i = list.Begin (); list.HasNext (); i = list.Next ())
	{
	  if (AICargo.HasCargoClass (i, AICargo.CC_PASSENGERS))
	    {
	      this.passengerCargoID = i;
	      break;
	    }
	}
    }	// constructor ()

};	// class NewWriteAI


// ----------------------------------------------------------------------------
//! Top level entry point for the AI

//! This function should never return (unless there is an error and the AI
//! must terminate). It drives the functionality of the AI.
// ----------------------------------------------------------------------------
function JeremyAI::Start()
{
  // Allow others an immediate look-in
  Sleep (1);

  // Fail if there is no passenger cargo.
  if (-1 == this.passengerCargoID)
    {
      AILog.Error ("JeremyAI could not find the passenger cargo");
      return;
  }

  // List of possible company names
  local companyNames = 
    ["Lymington Airways",
     "Pennington Airways",
     "Brockenhurst Airways",
     "Lyndhust Airways",
     "Sway Airways",
     "Boldre Airways",
     "Downton Airways",
     "Hordle Airways",
     "Beaulieu Airways",
     "New Milton Airways",
     "Everton Airways",
     "Walhampton Airways",
     "Setley Airways",
     "Keyhaven Airways",
     "Pilley Airways"];

  companyNames = this.RandomizeArray (companyNames);

  // Set the company name. If we don't succeed, then we'll just get an OpenTTD
  // generated name.
  foreach (idx, name in companyNames)
    {
      if (AICompany.SetName (name))
	{
	  break;
	}
    }

  // List of possible President names
  local presidentNames =
    ["Mr Z P Aldwinkle",
     "Dr L G Axelquist",
     "Mr P D Q Bedgegood",
     "Mr L J Bizegar",
     "Mr R P D Clagge",
     "Sir Jeremiah D’Arville",
     "Mr O Deiryme",
     "Dr L Diddams",
     "Mr X V Groutadge",
     "Mr K Y Ingledent",
     "Herr K Koputh",
     "Senor P P Pedzotti",
     "Mr L Pyrkins",
     "Mr L T Titmouse",
     "Herr Dr E I O Vertigans",
     "Mr K L M Walduck"];

  presidentNames = this.RandomizeArray (presidentNames);

  // Set the president name. If we don't succeed, then we'll just get an OpenTTD
  // generated name. All male for now
  foreach (idx, name in presidentNames)
    {
      if (AICompany.SetPresidentName (name))
	{
	  AICompany.SetPresidentGender (AICompany.GENDER_MALE);
	  break;
	}
    }

  // Say hello to the user
  AILog.Info ("Welcome to JeremyAI. " +
	      "I will be building airports all day long.");
  AILog.Info ("  - Minimum Town Size: " + GetSetting ("min_town_size"));

  // We start with no loan. We'll take more loan when we want to build
  // something. This should never fail, but even if it does we don't worry.
  AICompany.SetLoanAmount (0);

  // We need our local ticker, as GetTick() will skip ticks
  local ticker = 0;

  // Loop forever building airports
  while (true)
    {
      // The money we need to build a new route is for two airports and an
      // aircraft, plus we should allow some spare.
      local  routeCashNeeded =
	this.PadVehicle (this.planeCostEstimate) +
	2 * this.PadBuilding (this.airportCostEstimate);

      // Once in a while, with enough money, try to build something
      if ((ticker % this.delayBuildAirportRoute == 0) &&
	  this.HasMoney (routeCashNeeded))
	{
	  local tickCount = this.GetTick ();

	  // Try to build a route.
	  if (this.BuildReason.OK != this.BuildAirportRoute())
	    {
	      // Note if we can't even find a first airport for a route.
	      if (0 == ticker)
		{
		  // The old AI gave up at this stage. However we now have the
		  // potential for routes to appear in time as towns grow, so
		  // note a warning here, but just carry on trying.
		  AILog.Warning ("Failed to build an initial route. " +
				 "Retrying slowly.");
		}

	      // Once we fail to build a route, slow down our attempting.
	      delayBuildAirportRoute = this.Intervals.ROUTE_BUILD_LONG;
	    }

	  local interval = this.GetTick () - tickCount;
	  if (interval > 0)
	    {
	      AILog.Info ("Airport building took " + interval + " ticks.");
	    }
	}

      // Manage the routes once in a while */
      if (0 == (ticker % this.Intervals.ROUTE_MANAGE))
	{
	  local tickCount = this.GetTick ();
	  this.ManageAirRoutes ();
	  local interval = this.GetTick () - tickCount;
	  if (interval > 0)
	    {
	      AILog.Info ("Route management took " + interval + " ticks.");
	    }
	}

      // Check for events each time round the loop
      this.HandleEvents();

      // Pay off loan each time round the loop
      this.PayOffLoan ();

      // Decrement all the embargo times, and remove any which are zero or less
      for (local originTile = this.routeBuyEmbargoTime.Begin ();
	   this.routeBuyEmbargoTime.HasNext ();
	   originTile =this.routeBuyEmbargoTime.Next ())
	{
	  local val = this.routeBuyEmbargoTime.GetValue (originTile)
	  this.routeBuyEmbargoTime.AddItem (originTile,
					    val - this.Intervals.SLEEPING_TIME);
	}

      this.routeBuyEmbargoTime.KeepAboveValue (0);

      // Make sure we do not create infinite loops
      Sleep (this.Intervals.SLEEPING_TIME);
      ticker += this.Intervals.SLEEPING_TIME;
    }
}	// Start ()


// ----------------------------------------------------------------------------
//! Pad an estimated price for building

//! This is a utility function, which allows us to round up building
//! estimates, which tend to be low.

//! @param[in] Value to pad

//! @return  Padded value
// ----------------------------------------------------------------------------
function JeremyAI::PadBuilding (value)
{
  return value * 15 / 10;

}	// PadBuilding ()


// ----------------------------------------------------------------------------
//! Pad an estimated price for a vehicle

//! This is a utility function, which allows us to round up vehicle costs to
//! allow for small changes due to inflation, loan interest etc

//! @param[in] Value to pad

//! @return  Padded value
// ----------------------------------------------------------------------------
function JeremyAI::PadVehicle (value)
{
  return value * 11 / 10;

}	// PadVehicle ()


// ----------------------------------------------------------------------------
//! Randomize the elements in an array

//! A convenience function.

//! @param[in] a  The array whose elements are to be randomized

//! @return  The randomized array
// ----------------------------------------------------------------------------
function JeremyAI::RandomizeArray (a)
{
  local newA = [null];
  local len  = a.len ();

  newA.resize (len);

  for (local i = 0; i < len; i++)
    {
      local ri = AIBase.RandRange (len - i);
      newA[i] = a[ri];

      for (local j = ri; j < len - 1; j++)
	{
	  a[j] = a[j+1];
	}
    }

  return newA;

}	// RandomizeArray ()


// ----------------------------------------------------------------------------
//! Determine if we can raise enough money for a project.

//! @param[in] money  The amount we need

//! @return  TRUE if we have enough money, FALSE otherwise.
// ----------------------------------------------------------------------------
function JeremyAI::HasMoney (money)
{
  return this.MaxMoney () >= money;

}	// HasMoney ()


// ----------------------------------------------------------------------------
//! Determine how much money we could raise

//! This is the total of what we have in the bank and what we can borrow.

//! @return  The amount we could raise
// ----------------------------------------------------------------------------
function JeremyAI::MaxMoney ()
{
  local  maxNewLoan  = AICompany.GetMaxLoanAmount () -
                       AICompany.GetLoanAmount ();
  local  bankBalance = AICompany.GetBankBalance (AICompany.COMPANY_SELF);
  local  totalCash   = maxNewLoan + bankBalance;

  return totalCash;

}	// HasMoney ()


// ----------------------------------------------------------------------------
//! Convert a tile index to Cartesian coordinates

//! @param[in] tile  The tile as a tile index

//! @return  The tile location as Cartesian coordinates string
// ----------------------------------------------------------------------------
function JeremyAI::CartesianString (tile)
{
  return "(" + AIMap.GetTileX (tile) + "," + AIMap.GetTileY (tile) + ")";

}	// CartesianString ()


// ----------------------------------------------------------------------------
//! Build an airport route.

//! Trawl through all cities (bigger than the minimum) to find the most
//! productive location. Then if finance permits build those two airports and
//! a plane between them.

//! @return  A return code from BuildReason
// ----------------------------------------------------------------------------
function JeremyAI::BuildAirportRoute ()
{
  // See whether what type of airport we can build
  local airportType = this.ChooseAirportType ();
  local sizeName    =
    (AIAirport.AT_INTERCON      == airportType) ? "intercontinental" :
    (AIAirport.AT_INTERNATIONAL == airportType) ? "international" :
    (AIAirport.AT_METROPOLITAN  == airportType) ? "metropolitan" :
    (AIAirport.AT_LARGE         == airportType) ? "large" :
    (AIAirport.AT_COMMUTER      == airportType) ? "commuter" :
    (AIAirport.AT_SMALL         == airportType) ? "small" : "invalid";

  // If we don't have enough money, we won't find any suitable airport.
  if (AIAirport.AT_INVALID == airportType)
    {
      return this.BuildReason.NO_SUITABLE_AIRPORT;
    }
  else
    {
      AILog.Info("Trying to build an airport route with " + sizeName +
		 " airports.");
    }

  // Update our airport cost estimate.
  this.airportCostEstimate = AIAirport.GetPrice (airportType);

  // Get a list of all the possible airport tiles for each town, sorted in
  // order of descending production. Give up if we don't have at least two.
  local originList      = this.FindAllSuitableAirportSpots (airportType);

  if (originList.Count () < 2)
    {
      return this.BuildReason.NO_SUITABLE_AIRPORT;
    }

  // Clone and resort, so we have both source and destination lists.
  local destinationList = AITileList ();

  for (local tile = originList.Begin ();
       originList.HasNext ();
       tile = originList.Next ())
    {
      destinationList.AddTile (tile);
      destinationList.SetValue (tile, originList.GetValue (tile));
    }

  destinationList.Sort (AIAbstractList.SORT_BY_VALUE,
			AIAbstractList.SORT_DESCENDING);

  // Work through the two lists to find the best pair. This is just the sum of
  // their productivities. They must be far enough away, but not too far.
  local bestOrigin;
  local bestDestination;
  local bestProduction = 0;

  for (local originAirport = originList.Begin ();
       originList.HasNext ();
       originAirport = originList.Next ())
    {
      destinationList.RemoveTile (originAirport);

      for (local destinationAirport = destinationList.Begin ();
	   destinationList.HasNext ();
	   destinationAirport = destinationList.Next ())
	{
	  local dist = AITile.GetDistanceSquareToTile (originAirport,
						       destinationAirport);
	  local maxDist = this.MaxRouteDistance ();

	  if ((dist >= (this.minRouteDistance * this.minRouteDistance)) &&
	      (dist <= (maxDist * maxDist)))
	    {
	      local totProd = originList.GetValue (originAirport) +
		              destinationList.GetValue (destinationAirport);

	      if (totProd > bestProduction)
		{
		  bestOrigin      = originAirport;
		  bestDestination = destinationAirport;
		  bestProduction  = totProd;
		}
	    }
	}
    }

  // Did we find an airport pair?
  if (0 == bestProduction)
    {
      AILog.Info ("Failed to find a suitable pair of airports");
      return this.BuildReason.AIRPORTS_NOT_FOUND;
    }
  else
    {
      AILog.Info ("Identified two airport locations at " +
		  this.CartesianString (bestOrigin) + " and " +
		  this.CartesianString (bestDestination) +
		  " with total production " + bestProduction);
    }

  // Build the airports for real. This could still fail in principle if
  // another player had done something between us identifying the town and
  // actually building, or we had lost cash.

  // If it does fail, then tidy up and return a suitable failure code.
  this.GetMoney (this.PadBuilding (this.airportCostEstimate));
  local res = AIAirport.BuildAirport (bestOrigin, airportType,
				      AIStation.STATION_NEW);
  this.PayOffLoan ();

  if (res)
    {
      this.townsUsed.AddItem (this.townMapping.GetValue (bestOrigin),
			      bestOrigin);
    }
  else
    {
      AILog.Warning ("Although the testing told us we could build two " +
		     "airports, it still failed on the first airport at " +
		     this.CartesianString (bestOrigin) + ": " +
		     AIError.GetLastErrorString () + ".");
      return this.BuildReason.FIRST_AIRPORT_NOT_BUILT;
    }

  // Build the destination
  this.GetMoney (this.PadBuilding (this.airportCostEstimate));
  res = AIAirport.BuildAirport (bestDestination, airportType,
				AIStation.STATION_NEW);
  this.PayOffLoan ();

  if (res)
    {
      this.townsUsed.AddItem (this.townMapping.GetValue (bestDestination),
			      bestDestination);
    }
  else
    {
      AILog.Warning ("Although the testing told us we could build two " +
		     "airports, it still failed on the second airport at " +
		     this.CartesianString (bestDestination) + ": " +
		     AIError.GetLastErrorString () + ".");

      return this.BuildReason.SECOND_AIRPORT_NOT_BUILT;
    }

  // Now build an aircraft and apply it to this route. If the build fails for
  // some reason, then tidy up and return the failure code from the aircraft
  // building.
  local ret = this.BuildAircraft (airportType, bestOrigin, bestDestination);

  if (this.BuildReason.OK != ret )
    {
      AILog.Warning ("Failed to build an aircraft for the new route");
      return ret;
    }

  // If we get here everything has worked just fine.
  AILog.Info ("Done building a route from " +
	      AIStation.GetName (AIStation.GetStationID (bestOrigin)) +
	      " to " +
	      AIStation.GetName (AIStation.GetStationID (bestDestination)) +
	      ".");
  return ret;

}	// BuildAirportRoute ()


// ----------------------------------------------------------------------------
//! Determine our preferred airport type

//! This is the largest available. We don't worry about cash at this stage.

//! @return  An aiport type, or AIAirport.AT_INVALID if none is available
// ----------------------------------------------------------------------------
function JeremyAI::ChooseAirportType()
{
  local airportTypes = [
    AIAirport.AT_INTERCON,
    AIAirport.AT_INTERNATIONAL,
    AIAirport.AT_METROPOLITAN,
    AIAirport.AT_LARGE,
    AIAirport.AT_COMMUTER,
    AIAirport.AT_SMALL ];

  foreach (idx, at in airportTypes)
    {
      if (AIAirport.IsValidAirportType (at))
	{
	  return at;
	}
    }

  // If we get here, there is probably a problem, which we should report
  // higher up.
  return AIAirport.AT_INVALID;

}	// ChooseAirportType ()


// ----------------------------------------------------------------------------
//! Get all the money we can.

//! Takes out the maximum possible loan
// ----------------------------------------------------------------------------
function JeremyAI::GetAllMoney ()
{
  AICompany.SetLoanAmount (AICompany.GetMaxLoanAmount ());

}	// GetAllMoney ()


// ----------------------------------------------------------------------------
//! Get a specified amount of money.

//! Adjust the loan amount as necessary.

//! @param[in] amt  The amount required.

//! @return  TRUE if we got the required amount, FALSE otherwise (and any loan
//!          is paid off)
// ----------------------------------------------------------------------------
function JeremyAI::GetMoney (amt)
{
  local maxLoanAmount = AICompany.GetMaxLoanAmount ();
  local loanInterval  = AICompany.GetLoanInterval();

  local balance       = AICompany.GetBankBalance (AICompany.COMPANY_SELF);
  local currentLoan   = AICompany.GetLoanAmount ();

  local newLoan       = this.RoundUp (amt - balance, loanInterval);
  local totLoan       = currentLoan + newLoan;

  if (totLoan > maxLoanAmount)
    {
      this.PayOffLoan ();
      return false;		// Not enough available
    }
  else
    {
      AICompany.SetLoanAmount ((totLoan < 0) ? 0 : totLoan);
      return  true;
    }
}	// GetMoney ()


// ----------------------------------------------------------------------------
//! Round a value up.

//! Rounding on integer division is towards zero.

//! So rounding up happens automatically for negative values. For positive
//! values we must add prec - 1 before doing the rounding.

//! @param[in] value  The value to round
//! @param[in] prec   Round up to a multiple of this.

//! @return  The rounded value.
// ----------------------------------------------------------------------------
function JeremyAI::RoundUp (value, prec)
{
  value += (value > 0) ? prec - 1 : 0;

  return  value / prec * prec;

}	// RoundUp ()


// ----------------------------------------------------------------------------
//! Pay back as much of our loan as we can.

//! However early on we can find that we are perpetually having negative
//! amounts of cash. Four consecutive quarters of this and we are declared
//! bankrupt. So modify to keep the bank balance at a minimum of 5% of the
//! maximum possible loan
// ----------------------------------------------------------------------------
function JeremyAI::PayOffLoan ()
{
  local maxLoanAmount     = AICompany.GetMaxLoanAmount ();
  local loanInterval      = AICompany.GetLoanInterval();

  local balance           = AICompany.GetBankBalance (AICompany.COMPANY_SELF);
  local currentLoan       = AICompany.GetLoanAmount ();

  local minWantedBalance  = maxLoanAmount / 20;	// 5%
  local loanNeeded        = this.RoundUp (minWantedBalance - balance,
					  loanInterval);

  // AILog.Info ( "------");
  // AILog.Info ( "balance:             " + balance);
  // AILog.Info ( "currentLoan:         " + currentLoan);
  // AILog.Info ( "minWantedBalance:    " + minWantedBalance);
  // AILog.Info ( "loanNeeded:          " + loanNeeded);

  local newLoanTotal      = currentLoan + loanNeeded;
  local actualLoanTotal   = newLoanTotal < 0             ? 0             :
			    newLoanTotal > maxLoanAmount ? maxLoanAmount :
			                                   newLoanTotal

  // AILog.Info ( "newLoanTotal:        " + newLoanTotal);
  // AILog.Info ( "actualLoanTotal:     " + actualLoanTotal);
  // AILog.Info ( "");

  AICompany.SetLoanAmount (actualLoanTotal);

}	// PayOffLoan ()


// ----------------------------------------------------------------------------
//! Find all suitable spots for an airport

//! Walk all towns larger than the minimum size that have not already been
//! used.

//! The distance we search from the town depends on its size and the size of
//! the airport.

//! Suitable spots must accept cargo and offer sufficient cargo supply. The
//! airport must be buildable for the price needed.

//! The final list is ordered by cargo supply.

//! Nothing is actually built, since we use AITestMode at that point. However
//! we can't use AITestMode for the entire function, or getting and paying off
//! loands will not work.

//! @param[in] airportType  The type of airport to search for
//! @param[in] otherEnd     The location of the other end of the route, or
//!                         AIMap.TILE_INVALID if this is the first end.

//! @return  The tileindex (positive) of the airport, or a AIMap.TILE_INVALID
//           if no airport can be found.
// ----------------------------------------------------------------------------
function JeremyAI::FindAllSuitableAirportSpots (airportType)
{
  // Clear the current town ID to airport tile mapping
  townMapping.Clear ();

  // Get info about this type of airport
  local airportX   = AIAirport.GetAirportWidth (airportType);
  local airportY   = AIAirport.GetAirportHeight (airportType);
  local airportRad = AIAirport.GetAirportCoverageRadius (airportType);

  // Padded cost of the airport
  local paddedCost = this.PadBuilding (this.airportCostEstimate);

  // Get a list of all towns.
  local townList = AITownList();

  /* Remove all the towns we already used */
  townList.RemoveList (this.townsUsed);

  // Evaluate the population for each element in the list and keep all those
  // above the minimum size
  townList.Valuate (AITown.GetPopulation);
  townList.KeepAboveValue (GetSetting ("min_town_size"));

  // The list we will build up, and the list of tiles we have already looked
  // at.
  local spotList = AITileList ();
  local doneList = AITileList ();

  // Now search round each town
  for (local town = townList.Begin();
       townList.HasNext();
       town = townList.Next())
    {
      // Find where this town is (center tile?)
      local tile = AITown.GetLocation(town);

      // Population is used to determine the search radius
      local searchRadius = this.SearchRadius (AITown.GetPopulation (town));

      // Create a grid around the core of the town where we will search for an
      // airport.

      // We can't just add and subtract the search grid rectangle, since we
      // could hit a border. We have to explicitly work with X and Y
      // coordinates.
      local grid = AITileList();

      local townX = AIMap.GetTileX (tile);
      local townY = AIMap.GetTileY (tile);

      local maxX = AIMap.GetMapSizeX () - 1;
      local maxY = AIMap.GetMapSizeY () - 1;

      local topX    = townX - searchRadius;
      local topY    = townY - searchRadius;
      local bottomX = townX + searchRadius;
      local bottomY = townY + searchRadius;

      topX    = topX < 0 ? 0 : topX;
      topY    = topY < 0 ? 0 : topY;
      bottomX = bottomX > maxX  ? maxX : bottomX;
      bottomY = bottomY > maxY  ? maxY : bottomY;

      grid.AddRectangle (AIMap.GetTileIndex (topX,    topY),
			 AIMap.GetTileIndex (bottomX, bottomY));

      // Remove all the locations we've already looked at (due to overlapping
      // towns). Then add ourself to the doneList
      grid.RemoveList (doneList);
      doneList.AddList (grid);

      // Keep all the locations where we could build.
      grid.Valuate (AITile.IsBuildableRectangle, airportX, airportY);
      grid.KeepValue (1);

      // If we couldn't find a suitable place for this town, skip to the next
      if (0 == grid.Count ())
	{
	  continue;
	}

      // Keep all the locations which are flat.

      // TODO. This is computationally demanding - we may be more efficient
      // placing this later.
      grid.Valuate (this.IsFlatRectangle, airportX, airportY);
      grid.KeepValue (1);

      // If we couldn't find a suitable place for this town, skip to the next
      if (0 == grid.Count ())
	{
	  continue;
	}

      // Remove places that don't have sufficient acceptance. We require at
      // least MIN_ACCEPTANCE.
      grid.Valuate (AITile.GetCargoAcceptance, this.passengerCargoID,
		    airportX, airportY, airportRad);
      grid.RemoveBelowValue(this.MIN_ACCEPTANCE);

      // If we couldn't find a suitable place for this town, skip to the next
      if (0 == grid.Count ())
	{
	  continue;
	}

      // We don't bother with airports whose production is less than
      // MIN_PRODUCTIVITY (we know they won't be productive enough).
      grid.Valuate (AITile.GetCargoProduction, this.passengerCargoID,
		    airportX, airportY, airportRad);
      grid.RemoveBelowValue (this.MIN_PRODUCTIVITY);

      // If we couldn't find a suitable place for this town, skip to the next
      if (0 == grid.Count ())
	{
	  continue;
	}

      // Sort on production. We want the most productive airport. 
      grid.Sort (AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

      // We now have left a list of all the tiles within the search radius in
      // any direction of the center of town, which are buildable, flat and
      // which can accept cargo, ordered by descending production.

      // Walk all the tiles to find the first one where we can build an
      // airport (since we are sorted that will be the most productive).

      // We are in test mode (see above, so nothing is actually built.
      for (tile = grid.Begin(); grid.HasNext(); tile = grid.Next())
	{
	  if (!this.GetMoney (paddedCost))
	    {
	      // Give up if we can't build airports with an empty tilelist.
	      AILog.Info ("Couldn't get money to try building airports");
	      return AITileList ();
	    }
	  else
	    {
	      local test = AITestMode ();	// Just checking

	      if (AIAirport.BuildAirport (tile, airportType,
					  AIStation.STATION_NEW))
		{
		  // AILog.Info ("Found a good spot for an airport in " +
		  // 	      AITown.GetName (town) + " at " +
		  // 	      this.CartesianString (tile) +
		  // 	      " with production " +
		  // 	      AITile.GetCargoProduction (tile,
		  // 					 this.passengerCargoID,
		  // 					 airportX, airportY,
		  // 					 airportRad) + ".");

		  spotList.AddTile (tile);
		  this.townMapping.AddItem (tile, town);
		}
	    }

	  this.PayOffLoan ();
	}

      // Couldn't build an airport on any tile - try the next town.
    }

  // Sort the final list on production. We want the most productive airport. 
  spotList.Valuate (AITile.GetCargoProduction, this.passengerCargoID,
		    airportX, airportY, airportRad);
  spotList.Sort (AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

  return spotList;

}	// FindAllSuitableAirportSpots ()


// ----------------------------------------------------------------------------
//! Recommend a search radius for this town population

//! Based by observation on size of towns. Basically we want to ensure that
//! the same amount of free space is search around whatever the town size.

//! That observation is that towns population is about 13 times the rectangle
//! containing their housing. We search 10 squares beyond this.

//! In the absence of a sqrt function, we use a table lookup.

//! @param[in] pop  Population of the town

//! @return  Recommended search radius
// ----------------------------------------------------------------------------
function JeremyAI::SearchRadius (pop)
{
  local townRadius = pop <    300 ?  0 :
                     pop <   1500 ?  5 :
                     pop <   3000 ? 10 :
                     pop <   5000 ? 15 :
                     pop <   8000 ? 20 :
                     pop <  12000 ? 25 :
                     pop <  16000 ? 30 :
                     pop <  21000 ? 35 :
                     pop <  26000 ? 40 :
                     pop <  33000 ? 45 :
                     pop <  39000 ? 50 :
                     pop <  47000 ? 55 :
                     pop <  55000 ? 60 :
                     pop <  64000 ? 65 :
                     pop <  73000 ? 70 :
                     pop <  83000 ? 75 :
                     pop <  94000 ? 80 :
                     pop < 105000 ? 85 :
                     pop < 120000 ? 90 : 95;

  return  townRadius + 10;

}	// SearchRadius ()


// ----------------------------------------------------------------------------
//! Valuator for flat land

//! This checks that land is flat in a rectangle. It is very likely that if
//! land is flat and buildable it will be possible to build an airport. Doing
//! this will greatly improve our performance, since we will only try to build
//! airports on plausible sites.

//! We are flat if all the squares are at the same level, except we are
//! allowed corners one lower, so long as either their adjancent X or Y axis
//! corners are high (ignoring points off the edge).

//! @param[in] tile   The northern (top left) tile
//! @param[in] xSize  The X size of the rectangle
//! @param[in] ySize  The Y size of the rectangle

//! @return  1 if we are flat, 0 otherwise (we must have an integer result)
// ----------------------------------------------------------------------------
function JeremyAI::IsFlatRectangle (tile, xSize, ySize)
{
  local tileX = AIMap.GetTileX (tile);
  local tileY = AIMap.GetTileY (tile);

  // Take the maximum height of the first tile as the level height
  local level = AITile.GetMaxHeight (tile);

  // Enumerate each corner in turn (as the north point of each tile).

  // Note. This is a fence post problem - we must look at the tiles round the
  // far edges.
  local xLast = tileX + xSize;
  local yLast = tileY + ySize;

  // For a convenience, we can add/subtrace tile indexes
  local xStep = AIMap.GetTileIndex (1, 0);
  local yStep = AIMap.GetTileIndex (0, 1);

  for (local x = tileX; x <= xLast; x++)
    {
      for (local y = tileY; y <= yLast; y++)
	{
	  local t = AIMap.GetTileIndex (x, y);

	  if (AITile.GetHeight (t) == level)
	    {
	      continue;			// Corner is OK
	    }

	  // Always fail if a tile corner is high
	  if (AITile.GetHeight (t) > level)
	    {
	      return 0;
	    }

	  // Tile corner is low For corners of the rectangle, we don't care
	  if (((x <= tileX) || (x >= xLast)) &&
	      ((y <= tileY) || (y >= yLast)))
	    {
	      continue;
	    }

	  // Tile corner is low. Try X axis
	  if (((x <= tileX) || (AITile.GetHeight (t - xStep) == level)) &&
	      ((x >= xLast) || (AITile.GetHeight (t + xStep) == level)))
	    {
	      continue;
	    }

	  // Tile corner is low. Try Y axis
	  if (((y <= tileY) || (AITile.GetHeight (t - yStep) == level)) &&
	      ((y >= yLast) || (AITile.GetHeight (t + yStep) == level)))
	    {
	      continue;
	    }

	  return  0;
	}
    }

  // All OK
  return  1;

}	// IsFlatRectangle ()


// ----------------------------------------------------------------------------
//! Compute the maximum route distance

//! We don't want the route to be too long, or the value of returns drops
//! off. On the other hand, if it's too short we won't get a route at all.

//! For now it's a simple ratio based on the estimated speed of our current
//! aircraft, but we do ensure it is at least twice the minimum distance.

//! @return  The maximum route distance
// ----------------------------------------------------------------------------
function JeremyAI::MaxRouteDistance ()
{
  local maxDist = this.planeSpeedEstimate;

  return maxDist < (minRouteDistance * 2) ? (minRouteDistance * 2) : maxDist;

}	// MaxRouteDistance ();


// ----------------------------------------------------------------------------
//! Build an aircraft with orders from tile1 to tile2.

//! The best available aircraft of that time will be bought.

//! @param[in] airportType  The type of airport to fly between.
//! @param[in] tile1        The origin tile
//! @param[in] tile2        The destination tile

//! @return  A result code indicating success (BuildReason.OK) or the reason
//           for failure.
// ----------------------------------------------------------------------------
function JeremyAI::BuildAircraft (airportType, tile1, tile2)
{
  // Select a suitable aircraft. We may not be able to afford it, but we want
  // to wait for the best.
  if (PlaneSelectReason.OK != this.SelectAircraft (airportType))
    {
      return this.BuildReason.NO_SUITABLE_AIRCRAFT;
    }

  // Can't afford it.
  if (!HasMoney (AIEngine.GetPrice (this.planeEngine)))
    {
      return this.BuildReason.NO_SUITABLE_AIRCRAFT;
    }

  // Build the plane, getting all our cash first, then paying off as much loan
  // as possible afterwards.
  this.GetAllMoney ();
  local plane = AIVehicle.BuildVehicle (AIAirport.GetHangarOfAirport (tile1),
					this.planeEngine);
  local errStr = AIError.GetLastErrorString ();
  this.PayOffLoan ();
  
  if (!AIVehicle.IsValidVehicle (plane))
    {
      AILog.Warning("Couldn't build the aircraft: " + errStr + ".");
      return this.BuildReason.AIRCRAFT_NOT_BUILT;
    }

  // Specify the route
  AIOrder.AppendOrder (plane, tile1, AIOrder.AIOF_NONE);
  AIOrder.AppendOrder (plane, tile2, AIOrder.AIOF_NONE);
  AIVehicle.StartStopVehicle (plane);

  // Record the route details
  this.routeOrigins.AddItem (plane, tile1);
  this.routeDestinations.AddItem (plane, tile2);

  AILog.Info ("Done building a " + AIEngine.GetName (this.planeEngine) + 
	      " flying at " + this.planeSpeedEstimate + " km/h.");
  return this.BuildReason.OK;

}	// BuildAircraft


// ----------------------------------------------------------------------------
//! Select the best aircraft

//! For this exercised we are not limited by money. We want to encourage
//! selection of the best plane, not the cheapest one!

//! @param[in] airportType  The type of airport to use the route

//! @return  A return code. If we succeeded, then the plane chosen is in
//!          this.planeEngine.
// ----------------------------------------------------------------------------
function JeremyAI::SelectAircraft (airportType)
{
  // All possible planes
  local planeList = AIEngineList (AIVehicle.VT_AIR);

  // Only want passenger planes
  planeList.Valuate (AIEngine.GetCargoType);
  planeList.KeepValue (this.passengerCargoID);

  if (planeList.IsEmpty ())
    {
      return this.PlaneSelectReason.OUT_OF_CARGO_TYPE;
    }

  // If we have a small airport, then we want only small planes
  if ((AIAirport.AT_SMALL    == airportType) ||
      (AIAirport.AT_COMMUTER == airportType))
    {
      planeList.Valuate (AIEngine.GetPlaneType);
      planeList.KeepValue (AIAirport.PT_SMALL_PLANE);
      
      if (planeList.IsEmpty ())
	{
	  return this.PlaneSelectReason.NO_SMALL_PLANES;
	}
    }

  // Want the most suitable capacity. This is a combination of speed (we can
  // use the capacity more effectively), raw capacity and reliability (affects
  // effective speed). Note that we should not have an empty list after this!
  planeList.Valuate(this.GetEffectiveCapacity);
  planeList.KeepTop(1);

  if (planeList.IsEmpty ())
    {
      AILog.Error ("Unexpected empty plane selection list");
      return this.PlaneSelectReason.SELECTION_ERROR;
    }

  local engine = planeList.Begin();

  // Update our plane estimates, based on this aircraft.
  this.planeEngine           = engine;
  this.planeCostEstimate     = AIEngine.GetPrice (engine);
  this.planeLifetimeEstimate = AIEngine.GetMaxAge (engine);
  this.planeSpeedEstimate    = this.GetEffectiveSpeed (engine);

  return this.PlaneSelectReason.OK;

}	// SelectAircraft


// ----------------------------------------------------------------------------
//! Work out the effective capacity of the plane

//! Modified by speed (we can deliver more in the time) and reliability
//! (reduces the effective speed)

//! @param[in] engineID  The ID of the engine to evaluate

//! @return  The effective capacity.
// ----------------------------------------------------------------------------
function JeremyAI::GetEffectiveCapacity (engineID)
{
  if (!AIEngine.IsValidEngine (engineID))
    {
      // Invalid engine has no capacity!
      return  0;
    }

  // Used in a Valuator, so must use the static reference
  return AIEngine.GetCapacity (engineID) *
         JeremyAI.GetEffectiveSpeed (engineID);

}	// GetEffectiveCapacity ()


// ----------------------------------------------------------------------------
//! Work out the effective speed of the plane

//! Modified by speed by the reliability

//! @param[in] engineID  The ID of the engine to evaluate

//! @return  The effective speed.
// ----------------------------------------------------------------------------
function JeremyAI::GetEffectiveSpeed (engineID)
{
  if (!AIEngine.IsValidEngine (engineID))
    {
      // Invalid engine has no speed!
      return  0;
    }

  local speed       = AIEngine.GetMaxSpeed (engineID);
  local reliability = AIEngine.GetReliability (engineID);

  // Used in a Valuator, so must use the static reference
  return ((speed * reliability) +
	  (JeremyAI.BrokenDownSpeed (engineID) * (100 - reliability))) / 100;

}	// GetEffectiveSpeed ()


// ----------------------------------------------------------------------------
//! Work out the broken down speed of an aircraft

//! This depends on the aircraft speed multiplication factor. It's a shame we
//! can't get this from the API.

//! TODO. Extend the API to report the broken down speed of an engine.

//! @param[in] engineID  The engine of interest. Not currently used, but may
//!                      be useful in the future.

//! @return  The broken down speed
// ----------------------------------------------------------------------------
function JeremyAI::BrokenDownSpeed (engineID)
{
  local speedFactor;			// Multiplier for aircraft speed

  // Allow for this ceasing to be a valid setting
  if (AIGameSettings.IsValid ("vehicle.plane_speed"))
    {
      speedFactor = AIGameSettings.GetValue ("vehicle.plane_speed");
    }
  else
    {
      speedFactor = 1;
    }

  // Speed when broken down is 325 km/h. Pity we can't extract this from the
  // API.
  return  325 / speedFactor;

}	// BrokenDownSpeed ()


// ----------------------------------------------------------------------------
//! Manage existing air routes

//! Sell any aircraft that are not profitable enough after two years. If
//! routes are left with no aircraft, then sell the airports

//! If we have some cash add aircraft to routes with passengers waiting.

//! Finally purge any airports waiting to be sold.
// ----------------------------------------------------------------------------
function JeremyAI::ManageAirRoutes()
{
  this.SellUnprofitableAircraft ();
  this.AddAircraftToRoutes ();
  this.RestoreEmptyRoutes ();
  this.UpgradeAircraft ();

}	// ManageAirRoutes ()


// ----------------------------------------------------------------------------
//! Sell unprofitable aircraft

//! Sell any aircraft that are not profitable enough after two years.

//! A route may have two many aircraft if it has become congested. This can
//! lead to an oscilation with planes being sold, removing the congestion,
//! leading to more planes being built. To prevent this we institute a
//! per-route embargo whenever a plane is sold, to damp down this oscilation.
// ----------------------------------------------------------------------------
function JeremyAI::SellUnprofitableAircraft()
{
  local thisYear  = AIDate.GetYear (AIDate.GetCurrentDate ());
  local planeList = AIVehicleList();
  planeList.Valuate(AIVehicle.GetAge);

  // Give the plane at least 2 years to make a difference
  planeList.KeepAboveValue (365 * 2);

  // Check that each plane (over 2 years old) made sufficient profit in either
  // of the last two years. Don't worry if we sell off all our planes. If
  // any passengers gather, we'll replace them later.
  for (local plane = planeList.Begin();
       planeList.HasNext();
       plane = planeList.Next())
    {
      // Try to sell the plane if it has already made it to a hanger.
      if (planesToHanger.HasItem (plane) &&
	  AIVehicle.IsStoppedInDepot (plane))
	{
	  // Get the plane name now, since it won't be valid once sold.
	  local planeName = AIVehicle.GetName (plane);

	  // Sell the plane
	  AIVehicle.SellVehicle (plane);
	  planesToHanger.RemoveItem (plane);
	  planeUnprofitableYear.RemoveItem (plane);
	  AILog.Info("Sold " + planeName + " as it finally reached a hanger.");

	  continue;		// Nothing more to do with this plane
	}

      // Just continue if the plane is already on its way to a hanger
      if (planesToHanger.HasItem (plane))
	{
	  continue;
	}

      // Not profitable last year? Sell the aircraft if it was also
      // unprofitable the previous year.
      if (!this.IsProfitableAircraft (plane))
	{
	  if (this.planeUnprofitableYear.HasItem (plane) &&
	      (this.planeUnprofitableYear.GetValue (plane) == (thisYear - 1)))
	    {
	      // Send the vehicle to depot (we only get here if we haven't
	      // already done this).
	      AILog.Info ("Sending " + AIVehicle.GetName (plane) +
			  " to depot. Profit last year was: " +
			  AIVehicle.GetProfitLastYear (plane) + "." );
	      AIVehicle.SendVehicleToDepot (plane);
	      planesToHanger.AddItem (plane, 0);

	      // Place an embargo on buying extra planes on this route for a
	      // time.
	      local origin = this.routeOrigins.GetValue (plane);

	      if (this.routeBuyEmbargoTime.HasItem (origin))
		{
		  this.routeBuyEmbargoTime.SetValue (origin,
						     this.EMBARGO_TIME);
		}
	      else
		{
		  this.routeBuyEmbargoTime.AddItem (origin,
						    this.EMBARGO_TIME);
		}
	    }
	  else
	    {
	      // We weren't unprofitable two years ago. Mark this as the first
	      // unprofitable year.
	      if (this.planeUnprofitableYear.HasItem (plane))
		{
		  this.planeUnprofitableYear.SetValue (plane, thisYear);
		}
	      else
		{
		  this.planeUnprofitableYear.AddItem (plane, thisYear);
		}
	    }
	}
    }
}	// SellUnprofitableAircraft ()


// ----------------------------------------------------------------------------
//! Is an aircraft profitable?

//! We need to ensure the profit is large enough to cover the replacement cost
//! of an aircraft, based on our current estimates

//! @param[in] plane  Aircraft to check

//! @return  TRUE if we are profitable, FALSE otherwise
// ----------------------------------------------------------------------------
function JeremyAI::IsProfitableAircraft (plane)
{
  local profit = AIVehicle.GetProfitLastYear (plane);

  return profit > this.AircraftDepreciation (plane);

}	// IsProfitableAircraft ()


// ----------------------------------------------------------------------------
//! What is the annual depreciation cost per year of an aircraft

//! Divide the new cost by maximum age. We ignore stuff about inflation etc.

//! @param[in] plane  Aircraft to check

//! @return  Annual deprecation
// ----------------------------------------------------------------------------
function JeremyAI::AircraftDepreciation (plane)
{
  // Avoid divide by zero
  if (0 == this.planeLifetimeEstimate)
    {
      // Probably we've tried to get depreciation of a non-existent plane
      AILog.Warning ("Aircraft lifetime estimate of zero, resetting");
      this.planeLifetimeEstimate = INITIAL_PLANE_LIFETIME_ESTIMATE;
    }

  return this.planeCostEstimate / this.planeLifetimeEstimate

}	// AircraftDepreciation ()


// ----------------------------------------------------------------------------
//! Add aircraft to busy routes.

//! If we have some cash add aircraft to routes where the aircraft is "very"
//! profitable.
// ----------------------------------------------------------------------------
function JeremyAI::AddAircraftToRoutes()
{
  // Try to add a plane to a route with a planes that are already very
  // profitable.
  local airportList = AIStationList (AIStation.STATION_AIRPORT);

  // Try to add an aircraft to each very profitable route.
  for (local airport = airportList.Begin();
       airportList.HasNext();
       airport = airportList.Next())
    {
      // Don't try to add any more planes when we are short on cash. Allow a
      // bit spare
      if (!this.HasMoney (this.PadVehicle (this.planeCostEstimate)))
	{
	  return;
	}

      local planeList = AIVehicleList_Station (airport);
      local tile      = AIStation.GetLocation (airport);

      // No vehicles going to this airport. This can happen for a number of
      // reasons:
      // 1. We ran out of cash before building the plane when the route was
      // created
      // 2. The only aircraft crashed and could not be rebuilt at the time.
      // 3. We sold all the aircraft because the route was unprofitable.

      // We don't do anything here, since we can't tell if the route is
      // profitable. Instead we'll deal with this when restoring routes.
      if (0 == planeList.Count())
	{
	  continue;
	};

      // Don't try to add any more planes to a route which has recently sold
      // one (and has a buy embargo)
      local plane = planeList.Begin ();
      local origin = routeOrigins.GetValue (plane);

      if (this.routeBuyEmbargoTime.HasItem (origin) &&
	  (this.routeBuyEmbargoTime.GetValue (origin) > 0))
	{
	  continue;
	}

      // See if the route is profitable, and if so duplicate one of the planes
      if (this.IsVeryProfitableRoute (planeList))
	{
	  // Try to build the aircraft.
	  local destination = routeDestinations.GetValue (plane);

	  AILog.Info (AIStation.GetName (airport) + " very profitable," +
		      " need to add a new aircraft for the route.");

	  if (this.BuildReason.OK !=
	      this.BuildAircraft (AIAirport.GetAirportType (tile),
				  origin, destination))
	    {
	      AILog.Info ("Unable to add a new aircraft at the present time");

	      // We stop here on failure, since it is probably due to reasons
	      // that will stop any other aircraft building!
	      return;
	    }
	}
    }
}	// AddAircraftToRoutes ()


// ----------------------------------------------------------------------------
//! Is a route very profitable?

//! We check if it would still be profitable if the profits were shared
//! amongst additional aircraft. Is every individual aircraft profitable as
//! well?

//! @param[in] planeList  Aircraft on the route

//! @return  TRUE if we are very profitable, FALSE otherwise
// ----------------------------------------------------------------------------
function JeremyAI::IsVeryProfitableRoute (planeList)
{
  local totalProfit       = 0;
    
  for (local plane = planeList.Begin ();
       planeList.HasNext ();
       plane = planeList.Next ())
    {
      if (!this.IsProfitableAircraft (plane))
	{
	  // Fail if any one plane is not profitable.
	  return false;
	}

      totalProfit       += AIVehicle.GetProfitLastYear (plane);
    }

  // Depreciation for one more aircraft than we have.
  local totalDepreciation = this.AircraftDepreciation (planeList.Begin()) *
                            (planeList.Count () + 1);

  // Allow for making a return of 200%
  return totalProfit > (totalDepreciation * 300 / 100);

}	// IsVeryProfitableRoute ()


// ----------------------------------------------------------------------------
//! Restore empty routes

//! This can happen for a number of reasons:
//! 1. We ran out of cash before building the plane when the route was
//! created
//! 2. The only aircraft crashed and could not be rebuilt at the time.
//! 3. We sold all the aircraft because the route was unprofitable.

//! @todo We don't deal with the case when a single airport was created in the
//!       beginning. Hopefully that will be a rare occurrence.

//! We restore empty routes when we have cash. We find all the empty airports
//! and order them by waiting passengers. We pair them up in order.
// ----------------------------------------------------------------------------
function JeremyAI::RestoreEmptyRoutes ()
{
  // List of all the empty airports that could be origins
  local originList = AIStationList (AIStation.STATION_AIRPORT);

  originList.Valuate (this.PlaneCount);
  originList.KeepValue (0);

  if (originList.Count () < 2)
    {
      return;				// No empty routes
    }

  // Order by cargo amount
  originList.Valuate (AIStation.GetCargoWaiting, this.passengerCargoID);
  originList.Sort (AIAbstractList.SORT_BY_VALUE,
		   AIAbstractList.SORT_DESCENDING);

  // Duplicate for possible destinations
  local destinationList = AIStationList (AIStation.STATION_AIRPORT);

  destinationList.Valuate (this.PlaneCount);
  destinationList.KeepValue (0);

  // Order by cargo amount
  destinationList.Valuate (AIStation.GetCargoWaiting, this.passengerCargoID);
  destinationList.Sort (AIAbstractList.SORT_BY_VALUE,
			AIAbstractList.SORT_DESCENDING);

  // Create routes while we can
  for (local origin = originList.Begin ();
       originList.HasNext ();
       origin = originList.Next ())
    {
      destinationList.RemoveTop (1);	// Should be the origin!

      for (local destination = destinationList.Begin ();
	   destinationList.HasNext ();
	   destination = destinationList.Next ())
	{
	  // Don't try to add any more planes when we are short on cash. Allow
	  // a bit spare
	  if (!this.HasMoney (this.PadVehicle (this.planeCostEstimate)))
	    {
	      return;
	    }

	  local tile = AIStation.GetLocation (origin);

	  if (this.BuildReason.OK ==
	      this.BuildAircraft (AIAirport.GetAirportType (tile),
				  origin, destination))
	    {
	      AILog.Info ("Restored empty route from " +
			  AIStation.GetName (origin) + " to " +
			  AIStation.GetName (destination) + ".");
	      break;
	    }
	  else
	    {
	      // Give up if we couldn't restore the route - we'll try
	      // again later.
	      AILog.Warning ("Failed to restore empty route from " +
			     AIStation.GetName (origin) + " to " +
			     AIStation.GetName (destination) + ".");
	      return;
	    }
	}
    }
}	// RestoreEmptyRoutes ()


// ----------------------------------------------------------------------------
//! Valuator function to count aircraft using an aiport

//! @param[in] airport  Station ID of an airport

//! @return  Number of planes using that airport
// ----------------------------------------------------------------------------
function JeremyAI::PlaneCount (airport)
{
  local planeList = AIVehicleList_Station (airport);

  return planeList.Count ();

}	// PlaneCount ()


// ----------------------------------------------------------------------------
//! Upgrade aircraft

//! We start an autoreplace program on any aircraft which is obsolete, or has
//! a more efficient alternative.
//! ----------------------------------------------------------------------------
function JeremyAI::UpgradeAircraft ()
{
  // Remember the currently used planeEngine. We may need to restore this if
  // we end up replacing small airport engines, but this is a large airport
  // engine.
  local currentEngine = this.planeEngine;

  // Get all the planes and iterate through the engine types
  local allPlanes = AIVehicleList ();

  allPlanes.Valuate (AIVehicle.GetEngineType);

  for (local plane = allPlanes.Begin ();
       allPlanes.HasNext ();
       plane = allPlanes.Next ())
    {
      local airportType =
	AIAirport.GetAirportType (this.routeOrigins.GetValue (plane));

      // Determine the engine type and remove all other instances from the
      // list.
      local engine = AIVehicle.GetEngineType (plane);
      allPlanes.RemoveValue (engine);

      // Give up if we are already upgrading
      if (upgradedPlanes.HasItem (engine))
	{
	  continue;
	}

      // Determine the new engine type
      if (this.PlaneSelectReason.OK != this.SelectAircraft (airportType))
	{
	  // If we can't determine the engine type give up on this plane.
	  continue;
	}

      if (AIEngine.IsValidEngine (engine) &&
	  (this.GetEffectiveCapacity (engine) >=
	   this.GetEffectiveCapacity (this.planeEngine)))
	{
	  // Current engine is OK - nothing more to do on this plane.
	  continue;
	}

      // If we get here, the current engine is either too low capacity or
      // obsolete, so set up a replacement program. Note that this engine is
      // being replaced.
      AILog.Info ("Upgrading " + AIEngine.GetName (engine) + " to " +
		  AIEngine.GetName (this.planeEngine) + ".");
      AIGroup.SetAutoReplace (AIGroup.GROUP_ALL, engine, this.planeEngine);
      upgradedPlanes.AddItem (engine, 0);
    }

  // It's just possible we last replaced an aircraft for a small airport, when
  // the currently selected engine was a for a large airport. We fix this by
  // explicitly selecting for the correct airport size.
  if (AIAirport.PT_BIG_PLANE == AIEngine.GetPlaneType (currentEngine))
    {
      this.SelectAircraft (AIAirport.AT_LARGE);
    }
  else
    {
      this.SelectAircraft (AIAirport.AT_SMALL);
    }
}	// UpgradeAircraft () 


// ----------------------------------------------------------------------------
//! Handle any events of interest

//! The only event which interests us is an aircraft crashing, in which case
//! we should replace it.
// ----------------------------------------------------------------------------
function JeremyAI::HandleEvents()
{
  // Process each waiting event in turn
  while (AIEventController.IsEventWaiting())
    {
      local e = AIEventController.GetNextEvent();
      
      switch (e.GetEventType())
	{
	case AIEvent.AI_ET_VEHICLE_CRASHED:
	  {
	    local ec = AIEventVehicleCrashed.Convert(e);
	    local v  = ec.GetVehicleID();

	    AILog.Info ("We have a crashed aircraft (" +
			AIVehicle.GetName (v) +
			"), attempting to buy a new one as replacement");

	    // Build a new aircraft for the route
	    local tile1 = this.routeOrigins.GetValue (v);
	    local tile2 = this.routeDestinations.GetValue (v);

	    if (this.BuildReason.OK !=
		this.BuildAircraft (AIAirport.GetAirportType (tile1),
				    tile1, tile2))
	      {
		// TODO. We ought to give up if we end up with no aircraft,
		// since we'll likely never get enough money to replace it (OK
		// there's a small chance that we just missed, and the max
		// loan amount goes up soon, so we can then buy it).
		AILog.Warning ("Unable to replace crashed aircraft");
	      }

	    // Remove our record of the old aircraft
	    this.routeOrigins.RemoveItem (v);
	    this.routeDestinations.RemoveItem (v);
	  }

	  break;
	  
	default:

	  // All other events are ignored
	  break;
	}
    }
}	// HandleEvents ()


// ----------------------------------------------------------------------------
//! Save the current AI state

//! @todo  Currently a dummmy function

//! @return  A table of data to save
// ----------------------------------------------------------------------------
function JeremyAI::Save()
{
  return  {};

}	// Save ()


// ----------------------------------------------------------------------------
//! Load the AI state

//! @todo  Currently a dummmy function

//! @param[in] version  Version number of the AI being restored (must match)
//! @param[in] data     A table of data for reloading
// ----------------------------------------------------------------------------
function JeremyAI::Load(version, data)
{

}	// Load ()
