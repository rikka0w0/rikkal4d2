#pragma semicolon 1
#include <sourcemod>

#include <ps_natives>

#define PLUGIN_VERSION "1.2"
#define MSGTAG "\x04[PS]\x01"
#define PS_MIN "1.66"
#define PS_ModuleName "!usepoints Enabler"

new bool:loaded = false;

public Plugin:myinfo = 
{
	name = "[PS] !usepoints Enabler",
	author = "McFlurry",
	description = "Enables players to use !usepoints instead of !buy or !buystuff",
	version = PLUGIN_VERSION,
	url = "N/A"
}

public OnPluginStart()
{
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	}
	LoadTranslations("points_system.phrases");
	RegConsoleCmd("sm_usepoints", Cmd_UsePoints);
}

public OnPluginEnd()
{
	if(LibraryExists("ps_natives") && loaded)
	{
		loaded = false;
		PS_UnregisterModule(PS_ModuleName);
	}
}
	
public OnPSLoaded()
{
	if(LibraryExists("ps_natives"))
	{
		if(PS_GetVersion() >= StringToFloat(PS_MIN))
		{
			if(PS_RegisterModule(PS_ModuleName)) LogMessage("%T", "Module: Warning 1", LANG_SERVER);
			loaded = true;
		}	
		else
		{
			SetFailState("%T", "Module: Error 1", LANG_SERVER);
		}	
	}
	else
	{
		SetFailState("%T", "Module: Error 2", LANG_SERVER);
	}	
}

public OnPSUnloaded()
{
	loaded = false;
}	

public Action:Cmd_UsePoints(client, args)
{
	if(!loaded) return Plugin_Handled;
	if(IsClientInGame(client) && IsPlayerAlive(client)) FakeClientCommand(client, "sm_buy");
	return Plugin_Handled;
}	