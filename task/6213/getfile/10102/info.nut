/* -*- Mode: C++; tab-width: 6 -*- */
/*
 *
 * This file is part of ToyLib a library for OpenTTD noai and nogo
 * Copyright (C) 2014 Krinn <krinn@chez.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */


class MyNewAI extends AIInfo
 {
	function GetAuthor()      	{ return "Krinn"; }
	function GetName()        	{ return "MyNewAI"; }
	function GetDescription() 	{ return "A test"; }
	function GetVersion()     	{ return 1; }
	function GetDate()        	{ return "2014-11-08"; }
	function CreateInstance()	{ return "MyNewAI"; }
	function UseAsRandomAI()	{ return false; }
	function GetShortName()		{ return "TST1"; }
	function GetURL()			{ return ""; }

 }

 RegisterAI(MyNewAI());

