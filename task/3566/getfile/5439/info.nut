// Jeremy's AI for OpenTTD: Information file

// Copyright (C) 2010 Jeremy Bennett
// Copyright (C) 2009 OpenTTD NoAI Developers Team

// Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>
// Contributor: Yexo and the NoAI Developers Team <yexo@openttd.org

// This file is part of the New WriteAI for OpenTTD

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

// This is an extension of the WrightAI example AI from the OpenTTD
// website. Created as a learning exercise

// This code is commented throughout for use with Doxygen, although in the
// absence of Squirrel support, Doxygen probably won't process it that well.
// ----------------------------------------------------------------------------
class JeremyAI extends AIInfo {

  //! Identify the author of the AI

  //! @return  A string identifying the author
  function GetAuthor ()
  {
    return "Jeremy Bennett (inspired by the OpenTTD NoAI Developers Team)";
  }

  //! This AI's name

  //! @return  A string naming this AI
  function GetName ()
  {
    return "JeremyAI";
  }

  //! A short version of this AI's name

  //! @return  A 4 character string with the short name of this AI
  function GetShortName ()
  {
    return "NWAI";
  }

  //! All about this AI

  //! @return  A string describing this AI
  function GetDescription ()
  {
    return "A new simple AI that tries to beat you with only aircraft. Now in SVN.";
  }

  //! Which version are we?

  //! @note This must be updated for new versions. OpenTTD will load the AI
  //!       with the highest version number where the names are the same.

  //! @return  This AI's version number
  function GetVersion ()
  {
    return 1;
  }

  //! The date of this version

  //! @return  A string giving the date this AI was developed.
  function GetDate ()
  {
    return "13-Jan-09";
  }

  //! The name of this AI's class in main.nut

  //! @return  A string giving the AI's class name used in main.nut
  function CreateInstance ()
  {
    return "JeremyAI";
  }

  //! Additional settings the user can set for this AI.

  //! The only setting we support is the minimum town size to try to connect
  //! by aeroplane.
  function GetSettings ()
  {
    AddSetting ({name         = "min_town_size",
	         description  = "The minimal size of towns to work on",
	         min_value    =  100,
	         max_value    = 1000,
	         easy_value   =  500,
	         medium_value =  400,
	         hard_value   =  300,
	         custom_value =  500,
	         flags        =    0});
  }
}	// class NewWriteAI


//! Register this AI with the system
RegisterAI (JeremyAI ());
