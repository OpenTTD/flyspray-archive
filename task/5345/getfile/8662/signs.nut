/* -*- Mode: C++; tab-width: 6 -*- */ 

/*
 * This file is part of Script Communication Protocol (shorten to SCP), which are libraries for OpenTTD NoAI and NoGO
 * Copyright (C) 2012 Krinn <krinn@chez.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

class _SCPLib_Sign
{
static	CommunicationTile = SCPMap.GetTileIndex(2,1); // location for the communication Sign
static	base			= {}
static	SignState		= SCPList();	// state of signs we found:
								// 0-dead the sign doesn't exist anymore or must be removed
								// 1-no handling : a sign we don't care at all
								// 2-not a vital sign but valid
								// 3-vital sign (index=0) from a company
								// 4-as #3 but delay (unregistred client or hole in message waiting a retransmition of missing part)
								// 5-vital sign we own and watch
static	maxSignPerCompany = 1024; // max signs per company we could handle (so 15*thatnumber is highest signID we could handle)
	
	ID		= null;
	PoolID	= null;
	Title		= null;
	Message	= null;
	isQuery	= null;
	MessageID	= null;
	OwnerID	= null;
	CommandID	= null;
	Index		= null;
	SenderID	= null;
	ReceiverID	= null;
	TransportID	= null;
	Data		= null;
	HeaderSize	= null;
	CommonHeader= null;
	constructor(_id, _companyid)
		{
		this.Title=SCPSign.GetName(_id);
		this.ID = _id;
		this.OwnerID = _companyid;
		this.PoolID = _SCPLib_Sign.GetSignPoolID(this.ID, this.OwnerID);
		local signobject=_SCPLib_Sign.Load(this.PoolID);
		local save=(signobject == null);
		if (!save && signobject.Title == this.Title)	return signobject;
		if (!this.ReadCodedPanel())	return null; 
		this.AnyInterrest();
		if (save)	_SCPLib_Sign.base[this.PoolID] <- this;
		}
}

function _SCPLib_Sign::GetSignPoolID(signID, companyID)
// return the SignPoolID for signID and companyID
{
	local highID = (_SCPLib_Sign.maxSignPerCompany * companyID);
	if (highID > _SCPLib_Sign.maxSignPerCompany * 16)
		{
		_SCPLib_Message.SCPLogError("Too many signs to handle : "+highID);	return -1; // reject it if we have too many signs to handle
		}
	return (signID+highID);
}

function _SCPLib_Sign::Load(poolSignID)
// load sign object
{
return poolSignID in _SCPLib_Sign.base ? _SCPLib_Sign.base[poolSignID] : null;
}

function _SCPLib_Sign::DeleteSignObject(_SignPoolID)
// remove the sign object, clear message if need
{
local signid=_SignPoolID % (_SCPLib_Sign.maxSignPerCompany);
local compid=(_SignPoolID - signid) / (_SCPLib_Sign.maxSignPerCompany);
local switcher=null;
//	if (_SCPLib_Share.LibraryMode)	switcher=GSCompanyMode(compid);
local sigobj=_SCPLib_Sign.Load(_SignPoolID);
local clearCache=(_SCPLib_Sign.SignState.HasItem(_SignPoolID));
if (sigobj != null) // signobject must exist
	{
	local status=0;
	if (clearCache)	status=_SCPLib_Sign.SignState.GetValue(_SignPoolID);
	if (status == 5) // only clear message if status is/was 5
		{
		local company_owner=null;	// GS don't use its own ID but stole the companyID that own the sign
							// so we must get sure the stolen companyID is given instead of our ID
		if (_SCPLib_Share.LibraryMode)	company_owner=compid;
							else	company_owner=sigobj.ReceiverID;
		_SCPLib_MessagePool.DeleteMessage(sigobj.MessageID, company_owner);
		}
	delete _SCPLib_Sign.base[_SignPoolID];
	}
if (clearCache)	_SCPLib_Sign.SignState.RemoveItem(_SignPoolID); // reset cache to ignore it now
_SCPLib_Message.SCPLogInfo("SignObjDelete: signID="+signid+" compID="+compid+" SignPool size="+_SCPLib_Sign.SignState.Count()+" MessagePool size="+_SCPLib_MessagePool.PoolCache.Count());
}

function _SCPLib_Sign::GarbageCollector()
// remove dead signs, no more needed signs... clearnup sign buffer // 3comp : 8sig = 3080
{
	foreach (poolID, status in _SCPLib_Sign.SignState)
		{
		local signid=poolID % (_SCPLib_Sign.maxSignPerCompany);
		local compid=(poolID - signid) / (_SCPLib_Sign.maxSignPerCompany);
		local switcher=null;
		if (_SCPLib_Share.LibraryMode)	switcher=GSCompanyMode(compid);
		local exist=SCPSign.IsValidSign(signid);
		if (status == 0 && exist)	{ exist=SCPSign.RemoveSign(signid); _SCPLib_Message.SCPLogInfo("SIGNDELETE "+signid+" res:"+exist); } // really clear the sign in the game
		if (!exist)	_SCPLib_Sign.DeleteSignObject(poolID);
		switcher=null;
		}
}

function _SCPLib_Sign::ReadCodedPanel()
// Read a panel and decode it
{
	local buff="";
	local read=null;
	local invalidHeader=true;
	this.Message=SCPSign.GetName(this.ID);
	this.MessageID = -1;
	this.CommandID=null;
	for (local i=0; i < this.Message.len(); i++)
		{
		read=this.Message.slice(i, i+1);
		if (read == _SCPLib_Charcode.QuerySpace || read == _SCPLib_Charcode.AnswerSpace || read == _SCPLib_Charcode.LooseSpace)
			{
			switch (read)
				{
				case	_SCPLib_Charcode.QuerySpace:
					this.isQuery=true;
				break;
				case	_SCPLib_Charcode.AnswerSpace:
					this.isQuery=false;
				break;
				case	_SCPLib_Charcode.LooseSpace:
					this.isQuery=null;
				break;
				}
			this.CommandID=_SCPLib_Charcode.SCPCharToByte(buff);
			this.HeaderSize=i;
			if (this.CommandID != -1)	invalidHeader=false;
			break;
			}
		else	buff=buff+read;
		}
	if (!invalidHeader)
		{
		invalidHeader=true;
		buff="";
		for (local i=this.HeaderSize+1; i < this.Message.len(); i++)
			{
			read=this.Message.slice(i, i+1);
			if (read == _SCPLib_Charcode.QuerySpace || read == _SCPLib_Charcode.AnswerSpace || read == _SCPLib_Charcode.LooseSpace)
				{
				this.MessageID=_SCPLib_Charcode.SCPCharToByte(buff);
				this.HeaderSize=i;
				if (this.MessageID != -1)	invalidHeader=false;
				break;
				}
			else	buff=buff+read;
			}
		}
	if (!invalidHeader)
		{
		invalidHeader=true;
		buff="";
		for (local i=this.HeaderSize+1; i < this.Message.len(); i++)
			{
			read=this.Message.slice(i, i+1);
			if (read == _SCPLib_Charcode.QuerySpace || read == _SCPLib_Charcode.AnswerSpace || read == _SCPLib_Charcode.LooseSpace)
				{
				this.TransportID=_SCPLib_Charcode.SCPCharToByte(buff);
				this.SenderID=_SCPLib_Client.GetSenderCompanyID(this.TransportID);
				this.ReceiverID=_SCPLib_Client.GetReceiverCompanyID(this.TransportID);
				this.HeaderSize=i;
				if (this.Index != -1)	invalidHeader=false;
				break;
				}
			else	buff=buff+read;
			}
		}
	if (!invalidHeader)	this.CommonHeader=this.Message.slice(0, this.HeaderSize);
	if (!invalidHeader)
		{
		invalidHeader=true;
		buff="";
		for (local i=this.HeaderSize+1; i < this.Message.len(); i++)
			{
			read=this.Message.slice(i, i+1);
			if (read == _SCPLib_Charcode.QuerySpace || read == _SCPLib_Charcode.AnswerSpace || read == _SCPLib_Charcode.LooseSpace)
				{
				this.Index=_SCPLib_Charcode.SCPCharToByte(buff);
				this.HeaderSize=i;
				if (this.Index != -1)	invalidHeader=false;
				break;
				}
			else	buff=buff+read;
			}
		}
	if (!invalidHeader)
			{ this.Data=this.Message.slice(this.HeaderSize+1); }
		else	{
			_SCPLib_Message.SCPLogInfo("Invalid header, ignoring this one");
			return false;
			}
return true;
}

function _SCPLib_Sign::DrawPanel(_MessageID, _CompanyID, _item=-1)
// Panel is the sign panel as draw by openttd
// if item isn't provide we draw all panels for that message, else only the panel item #
{
	local msg= _SCPLib_MessagePool.LoadMessage(_MessageID, _CompanyID);
	if (msg == null)	{ _SCPLib_Message.SCPLogError("Cannot find message "+_MessageID+" in the pool"); return false; }
	local switcher = null;
	if (_SCPLib_Share.LibraryMode)	switcher=GSCompanyMode(_CompanyID);
	if (_item >= msg.Data.len())	{  _SCPLib_Message.SCPLogError("Asked item "+_item+" out of data range : "+msg.Data.len()); return false; }
	local first= msg.Data.len()-1;
	local last = -1;
	if (_item != -1)	{ first = _item; last= _item-1; }
	for (local i= first; i > last; i--)
		{
		local sig= null;
		local t_count=0;
		local giveup=false;
		do	{
			sig= SCPSign.BuildSign(_SCPLib_Sign.CommunicationTile, msg.Data[i]);
			local errstr="";
			if (_SCPLib_Share.LibraryMode)	errstr=GSError.GetLastErrorString();
								else	errstr=AIError.GetLastErrorString();
			giveup=SCPSign.IsValidSign(sig);
			t_count++;
			if (!giveup)	{
						_SCPLib_Message.SCPLogError("Trying building sign "+sig+" attempt="+t_count+" error="+errstr);
						SCPController.Sleep(1);
						}
			} while (!giveup);
			_SCPLib_Message.SCPLogInfo("SIGNCREATE "+sig+" built");
		local company_owner=null;
		if (_SCPLib_Share.LibraryMode)	company_owner=_CompanyID; // GS need to pass the sign owner ID and not its own ID
							else	company_owner=msg.ReceiverID; // AI pass its own ID
		if (i == 0)	_SCPLib_Sign.NewSignEntry(sig, company_owner); // Add the first sign directly in our watch list, because GS is pretty fast at handling them
		_SCPLib_Message.SCPLogInfo("DrawPanel SignID="+sig+" MessageID="+msg.MessageID+" from="+msg.SenderID+" to="+msg.ReceiverID+" "+i+" >"+msg.Data[i]);
		}
	_SCPLib_MessagePool.MessageStatusDraw(msg.MessageID, msg.ReceiverID);
	switcher = null;
}

function _SCPLib_Sign::DataSplit(messageID, commandID, transportCompanyID, isQuery, data)
// Encode & split data in a array of string of 31 bytes
// return the array
{
	local datasize=data.len();
	local spacerMode=null;
	switch (isQuery)
		{
		case	true:
			spacerMode=_SCPLib_Charcode.QuerySpace;
		break;
		case	false:
			spacerMode=_SCPLib_Charcode.AnswerSpace;
		break;
		case	null:
			spacerMode=_SCPLib_Charcode.LooseSpace;
		break;
		}
	local header=_SCPLib_Charcode.ByteToSCPChar(commandID)+spacerMode;
	// encoding commandID at first position so we will then only need to check byte1 on every sign to find if this need our attention or not
	// as the registration command will always be command #0
	header=header+_SCPLib_Charcode.ByteToSCPChar(messageID)+spacerMode;
	header=header+_SCPLib_Charcode.ByteToSCPChar(transportCompanyID)+spacerMode;
	local splitted=[];
	for (local i=0; i < data.len(); i++)
		{
		local value=_SCPLib_Charcode.DataEncode(data[i]);
		if (value == -1)	return -1;
		splitted.push(value);
		}
	local again=[];
	local needstore=true;
	local str="";
	local index=0;
	local sizeheader=header+_SCPLib_Charcode.ByteToSCPChar(index)+spacerMode;
	local counter=sizeheader.len();
	for (local i=0; i < splitted.len(); i++)
		{
		local value=splitted[i];
		for (local k=0; k < value.len(); k++)
			{
			str=str+value.slice(k, k+1);
			counter++;
			needstore=true;
			if (counter == 31)
				{
				again.push(header+_SCPLib_Charcode.ByteToSCPChar(index)+spacerMode+str);
				str="";
				index++;
				sizeheader=header+_SCPLib_Charcode.ByteToSCPChar(index)+spacerMode;
				counter=sizeheader.len();
				needstore=false;
				}
			}
		}
	if (needstore)	again.push(header+_SCPLib_Charcode.ByteToSCPChar(index)+spacerMode+str);
	return again;
}

function _SCPLib_Sign::AnyInterrest()
// Check if sign message level of interrest for us
// This is to fast checks for AI and GS.
{
	local value=null; // we set the state of that sign
	if (this.SenderID == _SCPLib_Client.GetOurCompanyID())	value=1; // Ignore our own message
	if (value == null && this.Index > 0)	value=2;	// valid, but we don't care a message that isn't the root index
	
	if (this.Index == 0)
		{
		if (value == 1)	value=5; // we own that one
				else	value=3; // a vital from someone
		if (value == 3 && !_SCPLib_Client.ClientExist(this.SenderID))	value=4; // vital but delay
		if (value == 4 && this.CommandID < 2)	value=3;	// never delay basics commands
		}
	else	if (value == null)	value=2; // non vital, not from us
	_SCPLib_Message.SCPLogInfo("Status update: signPoolID="+this.PoolID+" SignID="+this.ID+" Command="+this.CommandID+" Sender="+this.SenderID+" Receiver="+this.ReceiverID+" State="+value+" Index="+this.Index);
	_SCPLib_Sign.SignState.SetValue(this.PoolID, value);
}

function _SCPLib_Sign::NewSignEntry(signID, companyID)
// Add a new sign object to our list of signs
{
	local signpool = _SCPLib_Sign.GetSignPoolID(signID, companyID);
	if (signpool == -1)	return;
	if (!_SCPLib_Sign.SignState.HasItem(signpool))
		{
		_SCPLib_Sign.SignState.AddItem(signpool, 0); // state as new/dead
		if (SCPSign.GetLocation(signID) == _SCPLib_Sign.CommunicationTile)	
				local signobject=_SCPLib_Sign(signID, companyID); // create a new sign object
			else	_SCPLib_Sign.SignState.SetValue(signpool, 1); // flag it as ignore
		}
	else	{ // We know that one
		local handle = (SCPSign.GetLocation(signID) == _SCPLib_Sign.CommunicationTile);
		if (!handle)	_SCPLib_Sign.SignState.SetValue(signpool, 1);
				else	{ // Change its state if it has changed
					local signobject = _SCPLib_Sign.Load(signpool);
					if (signobject == null)	{ _SCPLib_Message.SCPLogError("Unknown sign object found at communication tile "+signpool); }
								else	{
									local currentTitle=SCPSign.GetName(signID);
									local oldTitle=signobject.Title;
									if (currentTitle != oldTitle)
										{
										_SCPLib_Sign.DeleteSignObject(signpool); // remove old object and cache entry
										_SCPLib_Sign.SignState.AddItem(signpool, 0); // and add it again to cache as fresh
										local s=_SCPLib_Sign(signID, companyID); // and rebuild new object
										_SCPLib_Message.SCPLogInfo("Recreating signobject as sign has been changed from "+oldTitle+" to "+currentTitle);	
										}
									}
					}
		}
}

function _SCPLib_Sign::BrowseSign()
// Browse openttd signs to see if we should handle them
{
	local allcompany=SCPList();

	allcompany.AddList(_SCPLib_Client.CompanyList);
	allcompany.RemoveValue(-1); // keep only good companies
	if (!_SCPLib_Share.LibraryMode)	allcompany.KeepValue(_SCPLib_Client.GetOurCompanyID());
						else	allcompany.RemoveValue(16);
	local switcher=null;
	local signcheck=0;
	foreach (companyID, dummy in allcompany)
		{
		local all_Sign = null;
		if (_SCPLib_Share.LibraryMode)
			{
			switcher=null;
			switcher=GSCompanyMode(companyID);
			all_Sign=SCPSignList();
			all_Sign.Valuate(GSSign.GetOwner);
			all_Sign.RemoveValue(18); // Not really safe, but until we get a GSCompany.COMPANY_DEITY const...
			}
		else	all_Sign=SCPSignList();
		SCPController.Sleep(1);
		foreach (signID, dummy in all_Sign)
			{
			_SCPLib_Sign.NewSignEntry(signID, companyID);
			}
		_SCPLib_Sign.GarbageCollector(); // delete signs we don't use anymore
		switcher=null;
		}
	SCPController.Sleep(1);
	local back= _SCPLib_Sign.ReadCommand(); // this only handle 1 command per try, but fully (so could handle many signs)
	if (back == false && _SCPLib_Sign.SignState.Count() > 0)
		{
		foreach (sigpoolid, state in _SCPLib_Sign.SignState)
			{
			local sobj=_SCPLib_Sign.Load(sigpoolid);
			local s_id, s_title, s_company, s_cmd, s_index, s_msg, s_data="null";
			s_id=sigpoolid % (_SCPLib_Sign.maxSignPerCompany);
			s_company=(sigpoolid - s_id) / (_SCPLib_Sign.maxSignPerCompany);
			s_title=SCPSign.GetName(s_id);
			if (sobj!=null)
				{
				//s_id=sobj.ID;
				//s_company=sobj.Owner;$
				s_cmd=sobj.CommandID;
				s_index=sobj.Index;
				s_msg=sobj.MessageID;
				s_data=sobj.Data
				}
			print("sigid="+s_id+" poolid="+sigpoolid+" state="+state+" s_company="+s_company+" s_index="+s_index+" s_cmd="+s_cmd+" s_msg="+s_msg+" s_title="+s_title+" s_data="+s_data);
			}
		}
	return back;
	}

function _SCPLib_Sign::ReadCommand()
// Read, decode and execute command found in the sign
{
	local sameIndex=SCPList();
	local baseList=SCPList();
	baseList.AddList(_SCPLib_Sign.SignState);
	baseList.KeepValue(3); // Keep only ones of high interrest
	if (baseList.IsEmpty())	return false;
	// find every message that are part of this one
	local panel=_SCPLib_Sign.Load(baseList.Begin());
	if (panel == null)	{ _SCPLib_Message.SCPLogError("Cannot load message "+baseList.Begin()); return false; }
	baseList.AddList(_SCPLib_Sign.SignState);
local z="";
foreach (pid, state in baseList)	{ z=z+"pid="+pid+"/"+state+" "; }
print("assembling with all signs = "+z);
	baseList.KeepValue(2);
	baseList.AddItem(panel.PoolID, 3); // reinject the message we handle
	local scramble = [];
	local maxIndex = -1;
	foreach (poolID, dummy in baseList)
		{
		local another=_SCPLib_Sign.Load(poolID);
		if (another == null)	{ continue; }
		if (another.CommonHeader == panel.CommonHeader)
			{
			if (maxIndex < another.Index)	maxIndex=another.Index;
			scramble.push(another);
			sameIndex.AddItem(poolID, 0);
			}
		}
	if (sameIndex.IsEmpty())	{ _SCPLib_Message.SCPLogError("<0 base array found bug ! Avoiding crash"); return false; }
	local reorder=array(maxIndex+1, null);
	local index=null;
	local switcher=null;
	_SCPLib_Message.SCPLogInfo("reorder size="+reorder.len()+" sameIndex size="+sameIndex.Count()+" scramble size="+scramble.len()+" maxIndex="+maxIndex);
	local gotHole=false;
	if (maxIndex >= sameIndex.Count())
		{
		// could happen if a sign miss, sign buffer overflow..., see maxSignPerCompany setting
		_SCPLib_Message.SCPLogError("Hole in message detect !");
		gotHole=true;

		}
	foreach (signpoolid, dummy in sameIndex)
		{
		local signobj=_SCPLib_Sign.Load(signpoolid); // cannot fail already tested upper
		if (!gotHole)	_SCPLib_Sign.SignState.SetValue(signpoolid, 0);	// flag them so garbage collector catch and remove them
		reorder[signobj.Index]=signobj.Data;
		}
	if (gotHole)
		{
		for (local i=0; i < reorder.len(); i++)
			{
			if (reorder[i]==null)
				{
				SCPLib.QueryCompany("SCPGetHole","SCPBaseSet",panel.SenderID, panel.MessageID, i, panel.PoolID); // ask for missing one
				_SCPLib_Message.SCPLogInfo("Querying missing part "+i+" from message "+panel.MessageID+" to company "+panel.SenderID);
				_SCPLib_Sign.SignState.SetValue(panel.PoolID, 4);
				}
			}
		return false;
		}
	// now expand the message
	local getData=[];
	local buff="";
	local buffline=reorder[0];
	local datatype=-1;
	local linecounter=0;
	local rowcounter=-1;
	local string_delimiter = 35;
	string_delimiter=string_delimiter.tochar();
	local number_delimiter = 36;
	number_delimiter=number_delimiter.tochar();
	local negative_delimiter = 37;
	negative_delimiter=negative_delimiter.tochar();
	local end=false;
	local read="";
	local newcommand=false;
	do	{
		rowcounter++;
		if (rowcounter == buffline.len())
			{
			rowcounter=0;
			linecounter++;
			if (linecounter == reorder.len())	{ end=true; }
			if (!end)	buffline=reorder[linecounter];
			}
		if (!end)	buff=buffline.slice(rowcounter, rowcounter+1);

		if (buff == string_delimiter || buff == number_delimiter || buff == negative_delimiter || end)
			{
			if (!newcommand)
				{
				if (!end)	switch (buff[0])
					{
					case	string_delimiter[0]:
						datatype=0;
					break;
					case	number_delimiter[0]:
						datatype=1;
					break;
					case	negative_delimiter[0]:
						datatype=2;
					break;
					default: // if end reach
					}
				newcommand=true;
				}
			else	{
				local uncode="";
				local error=false;
				switch (datatype)
					{
					case	0:
						uncode=_SCPLib_Charcode.DecodeString(read);
						error=(uncode == -1);
					break;
					case	1:
						uncode=_SCPLib_Charcode.SCPCharToByte(read);
						error=(uncode == -1);
					break;
					case	2:
						uncode=_SCPLib_Charcode.SCPCharToByte(read);
						error=(uncode == -1);
						uncode= 0 - uncode; // negate it after the error checking, as -1 is an error
					}
				if (error)	{ _SCPLib_Message.SCPLogError("Problem decoding datatype="+datatype); return false; }
				getData.push(uncode);
				newcommand=false;
				if (!end)
					{
					rowcounter--; // step back to redo that last delimiter
					if (rowcounter < 0)	{ rowcounter=0; linecounter--; }
					}
				read="";
				}
			}
		else	read=read+buff;
		} while (!end);
// now we can trigger the command
local reply=_SCPLib_Message();
reply.Command = panel.CommandID;
reply.MessageID = panel.MessageID;
reply.SenderID = panel.SenderID;
reply.ReceiverID = panel.ReceiverID;
reply.PoolID = -1;	// we cannot use the message.PoolID as it is set as a SignPoolID and not a MessagePoolID
if (reply.MessageID != -1)	reply.PoolID = _SCPLib_MessagePool.GetPoolID(reply.MessageID, panel.ReceiverID);
reply.Type = panel.isQuery;
reply.Data = getData;
_SCPLib_Command.ExecuteCommand(reply);
// and clear everything.
_SCPLib_Sign.GarbageCollector();
return true;
}

