class Foobar extends AIController {
    // {{{ bool stop
    /**
     * Indicator for ending the thread
     *
     * To avoid some deadlocks the thread is stopped with this flag.
     * This is set to true if the endless-loop should stop.
     */
    stop = false;
    // }}}

    // {{{ table startpoint
    /**
     * holds a list of industries which are marked as startpoint of
     * connection between to industries. Its something like
     * [IndustryID][CargoID] = int, with the number of trucks
     * used for the connection.
     *
     * @Note: use rawset and rawget as the keys are unsorted IndustryIDs and CargoIDs
     */
    startpoint = {};
    // }}}

    // {{{ void AddConnectionBetweenIndustries()
    /**
     * Connect two industries by a truck line.
     *
     * This method tries to connect two industries by a truck line.
     * It uses the startpoint table to store which industries are
     * used for the start of the connection (like coal mine, farm, forest, ...)
     */
    function AddConnectionBetweenIndustries() {
        // okay, lets go
        local industry_start = {}; // note, use rawset/rawget
        // usage: industry_start[IndustryID][CargoID] = production
        // get all industries which are producing something {{{
        local cargolist = AICargoList();
        for (local i = cargolist.Begin(); cargolist.HasNext(); i = cargolist.Next()) {
            local tmp = AIIndustryList_CargoProducing(i);
            tmp.Valuate(AIIndustryList_vProduction(i));
            tmp.RemoveValue(0); // I dont care about industries which doesn't produce sth.
            for (local j = tmp.Begin(); tmp.HasNext(); j = tmp.Next()) {
                if (!industry_start.rawin(j)) {
                    industry_start.rawset(j, {});
                }
                industry_start.rawget(j).rawset(i, tmp.GetValue(j));
            }
        }
        // }}}
        // filter the one which dont have a target {{{
        foreach (key, value in industry_start) {
            local to_delete = true;
            foreach (key2, value2 in value) {
                local tmp = AIIndustryList_CargoAccepting(key2);
                if (tmp.Count()) {
                    to_delete = false;
                }
            }
            if (to_delete) {
                industry_start.rawdelete(key);
            }
        }
        // }}}
        local industry_end = {};
        // usage: industry_end[CargoID][IndustryID] = TileIndex
        // get all industry end points of possible connections {{{
        foreach (industry, cargolist in industry_start) {
            foreach (cargoid, production in cargolist) {
                if (industry_end.rawin(cargoid)) {
                    continue;
                }
                industry_end.rawset(cargoid, {});
                local tmp = AIIndustryList_CargoAccepting(cargoid);
                for (local i = tmp.Begin(); tmp.HasNext(); i = tmp.Next()) {
                    industry_end.rawget(cargoid).rawset(i, AIIndustry.GetLocation(i));
                }
            }
        }
        // }}}
        local possible_connections = {};
        // usage: possible_connections[{start = IndustryID_start, end = IndustryID_end, cargo = CargoID}] = square-distance (the one from the API)
        // create distance table {{{
        foreach (industry_begin, cargos in industry_start) {
            foreach (cargoid, production in cargos) {
                foreach (target, index in industry_end.rawget(cargoid)) {
                    if (this.startpoint.rawin(industry_begin) && this.startpoint.rawget(industry_begin).rawin(cargoid)) {
                        //skip, already serviced
                        continue;
                    }
                    possible_connections.rawset({start = industry_begin, end= target, cargo = cargoid}, AIMap.DistanceSquare(
                                                                                    AIIndustry.GetLocation(industry_begin),
                                                                                    AIIndustry.GetLocation(target)));
                }
            }
        }
        // }}}
        // sort the distance table? not at the moment, maybe later
        // try to build a connection between two industries {{{
        /*
         * Okay, I iterate throught all possible connections and save the result in a boolean.
         * If the connection was sucessfully build the loop is of course stopped. This loop
         * ends at last at the end of the list.
         *
         * A 'try' is designed at trying some possible connections between two industries. The
         * start and end tiles for the connections are the outer most tiles of the 'can receive
         * cargo from industry', and only the one which are pointed to the targets industry.
         * Same goes for the target industry. If its not possible to build the line (AITestMode or
         * even AITransactionMode), the next pair of industries is tried.
         */
        local connection = false;
        // usage: bool(false) or {start = IndustryID, end = IndustryID, cargo = CargoID,
        //                        start_station = TileIndex, end_station = TileIndex,
        //                        depot_tile = TileIndex, vehicle = VehicleID}
        foreach (pair, dist in possible_connections) {
            this.Sleep(1);
            // find the borders of the accept/produce-tiles of the industries
            local engines = AIEngineList(AIVehicle.VEHICLE_ROAD);
            engines.Valuate(AIEngineList_vCargoType());
            engines.KeepValue(pair.cargo);
            if (!engines.Count()) {
                continue;
            }
            local coverage = { start = null, end = null};
            coverage.start = AITileList_IndustryProducing(pair.start, AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
            coverage.end   = AITileList_IndustryAccepting(pair.end  , AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP));
            coverage.start.Valuate(AITileList_vBuildable());
            coverage.start.KeepValue(1);
            coverage.end.Valuate(AITileList_vBuildable());
            coverage.end.KeepValue(1);
            local build = false;
            // try to build a road, truck stops and a depot
            for (local i = coverage.start.Begin(); coverage.start.HasNext() && !build; i = coverage.start.Next()) {
                local end_tiles = coverage.end; // hope it doesn't remove them in the coverage.end list too
                end_tiles.RemoveRectangle(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1),
                                          AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1));
                for (local j = end_tiles.Begin(); end_tiles.HasNext() && !build; j = end_tiles.Next()) {
                    // try 2 ways, either first x-axis, then y-axis and first y-axis then x-axis
                    // check if straight
                    if (AIMap.GetTileX(i) == AIMap.GetTileX(j) || AIMap.GetTileY(i) == AIMap.GetTileY(j)) {
                        // {{{
                        // straight                D
                        // S-----------------------+S
                        if (AICompany.GetBankBalance(AICompany.MY_COMPANY) <= AICompany.GetMaxLoanAmount()) {
                            AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
                        }
                        local transaction = AITransactionMode();
                        // build the road {{{
                        local check = AIRoad.BuildRoad(i, j);
                        if (!check) {
                            transaction.Stop();
                            transaction = null;
                            break;
                        }
                        // }}}
                        print("road valid");
                        // build the stations {{{
                        local check1 = false, check2 = false;
                        if (AIMap.GetTileX(i) == AIMap.GetTileX(j)) {
                            // along the y-axis
                            if (AIMap.GetTileY(i) > AIMap.GetTileY(j)) {
                                check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)-1), true, false);
                                check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j), AIMap.GetTileY(j)+1), true, false);
                            } else {
                                check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)+1), true, false);
                                check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j), AIMap.GetTileY(j)-1), true, false);
                            }
                        } else {
                            // along the x-axis
                            if (AIMap.GetTileX(i) > AIMap.GetTileX(j)) {
                                check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)), true, false);
                                check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j)+1, AIMap.GetTileY(j)), true, false);
                            } else {
                                check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)), true, false);
                                check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j)-1, AIMap.GetTileY(j)), true, false);
                            }
                        }
                        if (!check1 || !check2) {
                            // failed
                            transaction.Stop();
                            transaction = null;
                            break;
                        }
                        // }}}
                        print("station valid");

                        check1 = false;
                        check2 = false;
                        // build a depot {{{
                        local depottile;
                        // build the depot near the start, check only one side
                        if (AIMap.GetTileX(i) == AIMap.GetTileX(j)) {
                            if (AIMap.GetTileY(i) > AIMap.GetTileY(j)) {
                                check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)-1),
                                                          AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1));
                                if (!check1) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1),
                                                               AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)-1));
                                if (!check2) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1);
                            } else {
                                check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)+1),
                                                          AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1));
                                if (!check1) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1),
                                                               AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)+1));
                                if (!check2) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1);
                            }
                        } else {
                            // AIMap.GetTileY(i) == AIMap.GetTileY(j)
                            if (AIMap.GetTileX(i) > AIMap.GetTileX(j)) {
                                check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)),
                                                          AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1));
                                if (!check1) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1),
                                                               AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)));
                                if (!check2) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1);
                            } else {
                                check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)),
                                                          AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1));
                                if (!check1) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1),
                                                               AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)));
                                if (!check2) {
                                    transaction.Stop();
                                    transaction = null;
                                    break;
                                }
                                depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1);
                            }
                        }
                        // }}}
                        print("depot valid");
                        print("okay, lets build it");
                        check = transaction.Execute();
                        print("build status:"+check);
                        if (check) {
                            transaction = null; // if this enought?...
                            // okay, build the vehicle
                            local eng = engines.Begin();
                            print("depot: "+AIRoad.IsRoadDepotTile(depottile));
                            print("eng: "+AIEngine.IsValidEngine(eng));
                            print("cargo: "+AIEngine.GetCargoType(eng));
                            print("cargo2: "+pair.cargo);
                            local veh = AIVehicle.BuildVehicle(depottile, eng);
                            if (!AIVehicle.IsValidVehicle(veh)) {
                                print("could not build vehicle "+eng+"|"+veh);
                            }
                            AIOrder.AppendOrder(veh, i, AIOrder.AIOF_FULL_LOAD);
                            AIOrder.AppendOrder(veh, j, AIOrder.AIOF_UNLOAD);
                            AIVehicle.StartStopVehicle(veh);
                            // all done, save it
                            connection = {start = pair.start, end = pair.end, cargo = pair.cargo,
                                          start_station = i, end_station = j,
                                          depot_tile = depottile, vehicle = veh};
                            build = true;
                        } else {
                            transaction.Rollback(); // doesn't work as written (check the docs)
                        }
                        transaction = null; // if this enought?...
                        // }}}
                    } else {
                        // {{{
                        // not straight
                        /*
                         * okay, we got 2 possible ways,
                         * +------------E
                         * |            |
                         * |            |
                         * S------------+
                         * check both
                         */
                        if (AICompany.GetBankBalance(AICompany.MY_COMPANY) <= AICompany.GetMaxLoanAmount()) {
                            AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
                        }
                        local point = [AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(j)),
                                       AIMap.GetTileIndex(AIMap.GetTileX(j), AIMap.GetTileY(i))];
                        local valid_point = false;
                        for (local k = 0; k<2 && !build; k++) {
                            local transaction = AITransactionMode();
                            // build the road {{{
                            local check = AIRoad.BuildRoad(i, point[k]);
                            if (!check) {
                                transaction.Stop();
                                transaction = null;
                                continue;
                            }
                            check = AIRoad.BuildRoad(j, point[k]);
                            if (!check) {
                                transaction.Stop();
                                transaction = null;
                                continue;
                            }
                            // }}}
                            valid_point = point[k];
                            print("road valid (c,"+k+")");
                            // build the stations {{{
                            local check1 = false, check2 = false;
                            if (AIMap.GetTileX(i) == AIMap.GetTileX(valid_point)) {
                                // facing to y-axis
                                if (AIMap.GetTileY(i) > AIMap.GetTileY(valid_point)) {
                                    check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)-1), true, false);
                                } else {
                                    check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)+1), true, false);
                                }
                            } else {
                                // facing to x-axis
                                if (AIMap.GetTileX(i) > AIMap.GetTileX(valid_point)) {
                                    check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)), true, false);
                                } else {
                                    check1 = AIRoad.BuildRoadStation(i, AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)), true, false);
                                }
                            }
                            if (!check1) {
                                transaction.Stop();
                                transaction = null;
                                continue;
                            }
                            print("Execute: "+transaction.Execute());
                            continue;
                            if (AIMap.GetTileX(j) == AIMap.GetTileX(valid_point)) {
                                // facing to y-axis
                                if (AIMap.GetTileY(j) > AIMap.GetTileY(valid_point)) {
                                    check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j), AIMap.GetTileY(j)-1), true, false);
                                } else {
                                    check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j), AIMap.GetTileY(j)+1), true, false);
                                }
                            } else {
                                // facing to x-axis
                                if (AIMap.GetTileX(j) > AIMap.GetTileX(valid_point)) {
                                    check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j)-1, AIMap.GetTileY(j)), true, false);
                                } else {
                                    check2 = AIRoad.BuildRoadStation(j, AIMap.GetTileIndex(AIMap.GetTileX(j)+1, AIMap.GetTileY(j)), true, false);
                                }
                            }
                            if (!check2) {
                                transaction.Stop();
                                transaction = null;
                                continue;
                            }
                            // }}}
                            print("stations: "+check1+"|"+check2);
                            print("stations valid (c,"+k+")");
                            // build a depot {{{
                            local depottile;
                            // build the depot near the start, check only one side
                            if (AIMap.GetTileX(i) == AIMap.GetTileX(valid_point)) {
                                if (AIMap.GetTileY(i) > AIMap.GetTileY(valid_point)) {
                                    check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)-1),
                                                              AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1));
                                    if (!check1) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1),
                                                                   AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)-1));
                                    if (!check2) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1);
                                } else {
                                    check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)+1),
                                                              AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1));
                                    if (!check1) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1),
                                                                   AIMap.GetTileIndex(AIMap.GetTileX(i), AIMap.GetTileY(i)+1));
                                    if (!check2) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1);
                                }
                            } else {
                                // AIMap.GetTileY(i) == AIMap.GetTileY(valid_point)
                                if (AIMap.GetTileX(i) > AIMap.GetTileX(valid_point)) {
                                    check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)),
                                                              AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1));
                                    if (!check1) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1),
                                                                   AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)));
                                    if (!check2) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)-1, AIMap.GetTileY(i)-1);
                                } else {
                                    check1 = AIRoad.BuildRoad(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)),
                                                              AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1));
                                    if (!check1) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    check2 = AIRoad.BuildRoadDepot(AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1),
                                                                   AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)));
                                    if (!check2) {
                                        transaction.Stop();
                                        transaction = null;
                                        continue;
                                    }
                                    depottile = AIMap.GetTileIndex(AIMap.GetTileX(i)+1, AIMap.GetTileY(i)+1);
                                }
                            }
                            // }}}
                            print("road: "+check1+", depot: "+check2+" (c)");
                            print("okay, lets build it (c,"+k+")");
                            check = transaction.Execute();
                            transaction.Stop();
                            print("build status:"+check+" (c,"+k+")");
                            if (check) {
                                transaction = null; // if this enought?...
                                // okay, build the vehicle
                                local eng = engines.Begin();
                                print("depot: "+AIRoad.IsRoadDepotTile(depottile)+"("+depottile+")");
                                print("eng: "+AIEngine.IsValidEngine(eng)+"("+eng+")");
                                print("cargo: "+AIEngine.GetCargoType(eng));
                                print("cargo2: "+pair.cargo);
                                local veh = AIVehicle.BuildVehicle(depottile, eng);
                                if (!AIVehicle.IsValidVehicle(veh)) {
                                    print("could not build vehicle "+eng+"|"+veh);
                                    print("error, but why?");
                                }
                                AIOrder.AppendOrder(veh, i, AIOrder.AIOF_FULL_LOAD);
                                AIOrder.AppendOrder(veh, j, AIOrder.AIOF_UNLOAD);
                                AIVehicle.StartStopVehicle(veh);
                                // all done, save it
                                connection = {start = pair.start, end = pair.end, cargo = pair.cargo,
                                              start_station = i, end_station = j,
                                              depot_tile = depottile, vehicle = veh};
                                build = true;
                            } else {
                                transaction.Rollback(); // doesn't work as written (check the docs)
                            }
                            transaction = null;
                            print("passed index "+k);
                        }
                        print("passed (c) loop");
                        // }}}
                    }
                    print("end_tiles.HasNext() "+end_tiles.HasNext());
                }
                print("coverage.start.HasNext() "+coverage.start.HasNext());
            }
            if (typeof connection == "table") {
                // found one, quit
                break;
            }
        }
        // }}}
        // save result
        if (typeof connection == "table") {
            if (!this.startpoint.rawin(connection.start)) {
                this.startpoint.rawset(connection.start, {});
            }
            this.startpoint.rawget(connection.start).rawset(connection.cargo, 1);
        }
    }
    // }}}

    // {{{ Start()
    /**
     * Called by the NoAI system to start the bot.
     */
    function Start() {
        this.print("AI loaded");
        this.Sleep(1); // tick 0 is not useable
        //AICompany.SetLoanAmount(0); // starts clean
        local tick = 0;
        do {
            if (AICompany.GetLoanAmount() && AICompany.GetBankBalance(AICompany.MY_COMPANY)) {
                local bank = AICompany.GetBankBalance(AICompany.MY_COMPANY);
                local loan = AICompany.GetLoanAmount();
                local tmp = bank / AICompany.GetLoanInterval();
                local tmp2 = loan / AICompany.GetLoanInterval();
                if (tmp > tmp2) {
                    AICompany.SetLoanAmount(0);
                } else {
                    AICompany.SetLoanAmount((tmp2-tmp)*AICompany.GetLoanInterval());
                }
            }
            if (0 == tick%100) {
                this.AddConnectionBetweenIndustries();
            }
            tick++;
            this.Sleep(1); // let other AIs (and openttd) a chance to get scheduled
        } while(!this.stop);
    }
    // }}}

    // {{{ Stop()
    /**
     * Called by the NoAI system to stop the bot.
     */
    function Stop() {
        this.stop = true;
    }
    // }}}
}

class FFoobar extends AIFactory {
    function GetAuthor()      { return "Progman"; }
    function GetName()        { return "Foobar"; }
    function GetDescription() { return "Da tru haxx"; }
    function GetVersion()     { return 1; }
    function GetDate()        { return "2008-02-23"; }
    function CreateInstance() { return "Foobar"; }
}
/* Tell the core we are an AI */
iFFoobar <- FFoobar();
/* vim: set filetype=squirrel: */
