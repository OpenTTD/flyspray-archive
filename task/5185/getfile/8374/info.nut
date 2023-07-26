class MTCAI extends AIInfo 
 {
   function GetAuthor()      { return "Griffin71"; }
   function GetName()        { return "MTC AI"; }
// Name displayed in the player's AI list
   function GetDescription() { return "Municpial Transport Company AI"; }
   function GetAPIVersion()  { return "1.2"; }
   function GetVersion()     { return 1; }
   function GetDate()        { return "2012-05-08"; }
   function CreateInstance() { return "MTCAI"; } // Class name
   function GetShortName()   { return "MTCO"; } // Must be 4 characters
   
   function GetSettings() 
   {
     AddSetting({name = "RegionallyActive",
                 description = "Turn on if company should be regionally active, connecting to other towns.", 
                 easy_value = 0, 
                 medium_value = 1, 
                 hard_value = 1, 
                 custom_value = 0, 
                 flags = AICONFIG_BOOLEAN}); // 0 = off, false; 1 = on, true
                 
     AddSetting({name = "TransportMail", 
                description = "Turn off if company should not transport mail.", 
                easy_value = 1, 
                medium_value = 1, 
                hard_value = 1, 
                custom_value = 1, 
                flags = AICONFIG_BOOLEAN});
                
     AddSetting({name = "int_setting", 
                 description = "Maximum number of industry chains that supply town it will build.", 
                 easy_value = 0, 
                 medium_value = 1, 
                 hard_value = 2, 
                 custom_value = 2, 
                 flags = 0, 
                 min_value = 0, 
                 max_value = 10});    	
   }
 }
 
 RegisterAI(MTCAI());
