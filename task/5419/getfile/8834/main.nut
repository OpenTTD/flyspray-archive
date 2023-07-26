/*
 * This file is part of MinimalGS, which is a GameScript for OpenTTD
 * Copyright (C) 2012  Leif Linse
 *
 * MinimalGS is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * MinimalGS is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MinimalGS; If not, see <http://www.gnu.org/licenses/> or
 * write to the Free Software Foundation, Inc., 51 Franklin Street, 
 * Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

/* Import SuperLib for GameScript */
import("util.superlib", "SuperLib", 26);
Result <- SuperLib.Result;
Log <- SuperLib.Log;
Helper <- SuperLib.Helper;
ScoreList <- SuperLib.ScoreList;
Tile <- SuperLib.Tile;
Direction <- SuperLib.Direction;
Town <- SuperLib.Town;
Industry <- SuperLib.Industry;


class MainClass extends GSController 
{
	_per_company = null;
	_load_data = null;
	_mycompany = null;
	_equity = null;
	_current_date = null;
	_current_year = 0;
	_previous_year = 0;
	_goal = null;
	_goal2 = null;
	_goal3 = null;
	_goal4 = null;
	negstart = null;
	newsbox = null;
	pval = 0;
	profit = 0;
	pprofit = 0;
	constructor()
	{
		_per_company = [];
		newsbox = GSNews();
	}
}

function MainClass::Start()
{
	this.Init();

	// Wait for the game to start
	this.Sleep(1);

	// Welcome human player
	local HUMAN_COMPANY = 0;
	_equity = CompanyEquity(HUMAN_COMPANY);
	GSNews.Create(GSNews.NT_GENERAL, GSText(GSText.STR_HELLO_WORLD, HUMAN_COMPANY), HUMAN_COMPANY);
	_current_date = GSDate.GetCurrentDate();
	_current_year = GSDate.GetYear(_current_date);
	_previous_year = _current_year;
	while (true) {
		local loop_start_tick = GSController.GetTick();

		this.HandleEvents();
		this.DoTest();

		// Loop with a frequency of five days
		local ticks_used = GSController.GetTick() - loop_start_tick;
		this.Sleep(Helper.Max(1, 5 * 74 - ticks_used));
	}
}

function MainClass::Init()
{
	if (this._load_data != null)
	{
		// Copy loaded data from this._load_data to this.*
		// or do whatever with the loaded data
	}
}

function MainClass::HandleEvents()
{
	if(GSEventController.IsEventWaiting())
	{
		local ev = GSEventController.GetNextEvent();

		if(ev == null)
			return;

		// check event type
		// handle event
	}
}

function MainClass::Save()
{
	Log.Info("Saving data to savegame", Log.LVL_INFO);
	return { 
		some_data = null,
		some_other_data = null
	};
}

function MainClass::Load(version, tbl)
{
	Log.Info("Loading data from savegame made with version " + version + " of the game script", Log.LVL_INFO);

	// Store a copy of the table from the save game
	// but do not process the loaded data yet. Wait with that to Init
	// so that OpenTTD doesn't kick us for taking too long to load.
	this._load_data = {}
   	foreach(key, val in tbl)
	{
		this._load_data.rawset(key, val);
	}	
}

function MainClass::DoTest()
{
	this._equity.GetEquity();
	local assets=this._equity._cash + this._equity._vehicles;
	local liab = this._equity._debt;
	local cval = assets-liab;
	local HUMAN_COMPANY = 0;
	_current_date = GSDate.GetCurrentDate();
	_current_year = GSDate.GetYear(_current_date);
	if(_current_year != _previous_year) {
		_previous_year = _current_year;
		pval=cval;
		pprofit=profit;
	}
	profit = cval-pval;
//	local infotext = ("Cash: "+_equity._cash+" Debt: "+_equity._debt+"\nVehicles: "+_equity._vehicles+"\nAssets "+assets+"Liabilities "+liab+"\nCompany value "+cval);
	local infotext = GSText(GSText.STR_BALANCE_1);
	infotext.AddParam(HUMAN_COMPANY);
	local infotext2 = GSText(GSText.STR_BALANCE_2);
	infotext2.AddParam(_equity._cash);
	infotext2.AddParam(_equity._debt.tointeger());
	local infotext3 = null;
	if(cval>=0) { infotext3 = GSText(GSText.STR_BALANCE_3); }
	else { infotext3 = GSText(GSText.STR_BALANCE_3N); }
	infotext3.AddParam(_equity._vehicles.tointeger());
	infotext3.AddParam(abs(cval));
	local infotext4 = null;
	if(profit>=0 && pprofit >=0 ) { infotext4 = GSText(GSText.STR_BALANCE_4); }
	else if (profit>=0 && pprofit <0 ) { infotext4 = GSText(GSText.STR_BALANCE_4L); }
	else if (profit<0 && pprofit >=0 ) { infotext4 = GSText(GSText.STR_BALANCE_4N); }
	else { infotext4 = GSText(GSText.STR_BALANCE_4NL); }
	infotext4.AddParam(abs(profit));
	infotext4.AddParam(abs(pprofit));
	local shorttext = "Cash: +"+_equity._cash+" Vehicles: +"+_equity._vehicles+" Debt: -"+_equity._debt+" Value: "+cval+" Profit: "+profit+" Last year: "+pprofit;
	local gt = GSGoal.GT_NONE;
	local qt = GSGoal.QT_INFORMATION;
	/*if(cval<0) {
		if(negstart != null && GSDate.GetCurrentDate()-negstart <= 1095) {
			qt = GSGoal.QT_WARNING;
		} else if(negstart != null && GSDate.GetCurrentDate()-negstart>1095) {
			qt = GSGoal.QT_ERROR;
		} else {
			negstart = GSDate.GetCurrentDate();
		}
	} else {
		negstart = null;
	}*/
	if(_goal != null) {if(GSGoal.IsValidGoal(_goal)) {GSGoal.Remove(_goal);}}
	if(_goal2 != null) {if(GSGoal.IsValidGoal(_goal2)) {GSGoal.Remove(_goal2);}}
	if(_goal3 != null) {if(GSGoal.IsValidGoal(_goal3)) {GSGoal.Remove(_goal3);}}
	if(_goal4 != null) {if(GSGoal.IsValidGoal(_goal4)) {GSGoal.Remove(_goal4);}}
	_goal = GSGoal.New(0, infotext, gt, 0);
	_goal2 = GSGoal.New(0, infotext2, gt, 0);
	_goal3 = GSGoal.New(0, infotext3, gt, 0);
	_goal4 = GSGoal.New(0, infotext4, gt, 0);
	//_goal = GSGoal.New(0, shorttext, gt, 0);
	//GSGoal.Question(0, 0, infotext, qt, GSGoal.BUTTON_OK);
	/*GSLog.Info("Cash "+this._equity._cash+" Debt "+this._equity._debt);
	GSLog.Info("Vehicles "+this._equity._vehicles);
	GSLog.Info("Assets     Liabilities     Company Value");
	GSLog.Info(assets+"    "+liab+"     "+cval);*/
}

class CompanyEquity
{
	_company = null;
	_vehicles = 0;
	_equity_value = 0;
	_current_quarter = null;
	_current_date = null;
	_prev_quarter = null;
	_cash = 0;
	_debt = 0;
	constructor(company)
	{
		_company = company;
		
		//this.GetEquity();
	}
	function GetEquity()
	{
		if(GSCompany.ResolveCompanyID(_company) != GSCompany.COMPANY_INVALID)
		{
			local _mycompany = GSCompanyMode(_company);
			local vl = GSVehicleList();
			local v = null;
			_cash = GSCompany.GetBankBalance(_company);
			_debt = GSCompany.GetLoanAmount();
			if(!vl.IsEmpty()) {
				_vehicles = 0;
				v = vl.Begin();
				do {
					_vehicles += GSVehicle.GetCurrentValue(v);
					v = vl.Next();
				} while(!vl.IsEnd());
			} else {
				_vehicles = 0;
			}
		} else {
			GSLog.Error("Invalid company");
		}
	}
}
