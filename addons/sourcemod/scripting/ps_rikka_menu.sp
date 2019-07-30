#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#include <l4d2_weapon_stocks>
#include <ps_natives>

#define PLUGIN_VERSION "1.2"
#define PS_MIN "1.0"
#define PS_ModuleName "Rikka's server menu"

#define MSGTAG "\x04[PS]\x01"
#define ITEMCOUNT 2

ConVar g_RikkaItemCost[ITEMCOUNT];
char g_RikkaItemName[ITEMCOUNT][64];

bool loaded = false;

public Plugin myinfo = 
{
	name = "[PS] Rikka's server menu",
	author = "Rikka0w0",
	description = "Buy funny stuff",
	version = PLUGIN_VERSION,
	url = "N/A"
}

public void OnPluginStart()
{
	char game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	}
	
	LoadTranslations("points_system.phrases");
	LoadTranslations("ps_rikka_menu.phrases");
	
	LoadTranslations("core.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("points_system_menus.phrases");
	
	g_RikkaItemCost[0] = CreateConVar("psrm_points_meleeenlarge", "15", "How many points does a melee enlarge cost", FCVAR_PLUGIN);
	g_RikkaItemName[0] = "Melee Enlarge";
	g_RikkaItemCost[1] = CreateConVar("psrm_points_respawn", "25", "How many points does a respawn cost", FCVAR_PLUGIN);
	g_RikkaItemName[1] = "Respawn";
	
	AutoExecConfig(true, "ps_rikka_menu");
}

public void OnPluginEnd()
{
	if(LibraryExists("ps_natives") && loaded)
	{
		loaded = false;
		PS_UnregisterModule(PS_ModuleName);
	}
}
	
public void OnPSLoaded()
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

public void OnPSUnloaded()
{
	loaded = false;
}

public void OnBuyMenuBuilding(int client, Handle menu) {
	char buffer[64];
	Format(buffer, sizeof(buffer), "%T", "Rikka Menu", client);
	AddMenuItem(menu, "g_RikkaMenu", buffer);
}

public void OnBuyMenuSelect(int client, Handle menu, int menuPos) {
	char menuName[64];
	GetMenuItem(menu, menuPos, menuName, sizeof(menuName));
	
	if (!StrEqual(menuName, "g_RikkaMenu"))
		return;
	
	BuildRikkaMenu(client);
}

void BuildRikkaMenu(int client) {
	char menuName[64];
	Menu subMenu = CreateMenu(RikkaMenuHandler, MenuAction_Select | MenuAction_End | MenuAction_Cancel);
	subMenu.SetTitle("%T", "Rikka Menu", client);
	subMenu.ExitBackButton = true;
	
	// Add all menu items
	for (int i=0; i<ITEMCOUNT; i++)
	{
		Format(menuName, sizeof(menuName), "%T", g_RikkaItemName[i], client);
		subMenu.AddItem("", menuName);	
	}

	subMenu.Display(client, MENU_TIME_FOREVER);
}

public int RikkaMenuHandler(Handle menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_End) {
		delete menu;	// Release resources allocated for the menu instance
		return 0;
	}
	
	if (action == MenuAction_Cancel) {	// param1 - client, param2 - reason
		if (param2 == MenuCancel_ExitBack) {
			// Open main menu
			FakeClientCommand(param1, "sm_buy");
		}
	} else if (action == MenuAction_Select)	{	// param1 - client, param2 - itemPos
		DisplayConfirmMenu(param1, param2);
	}
	
	return 0;
}

void DisplayConfirmMenu(int client, int option)
{
	char buffer[64], numbuf[64];
	Menu menu = CreateMenu(MenuHandler_Confirm, MenuAction_Select | MenuAction_End | MenuAction_Cancel);
	menu.SetTitle("%T", "Cost", client, GetItemCost(option));
	
	// Attach the optionId in the first item
	IntToString(option, numbuf, sizeof(numbuf));
	Format(buffer, sizeof(buffer),"%T", "Yes", client);
	menu.AddItem(numbuf, buffer);	// Yes
	
	GetItemDesc(client, option, numbuf, sizeof(numbuf));
	Format(buffer, sizeof(buffer),"%T\n%s", "No", client, numbuf);
	menu.AddItem("", buffer);		// No
	
	SetMenuExitBackButton(menu, true);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Confirm(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		delete menu;	// Release resources allocated for the menu instance
		return;
	}
	
	if (action == MenuAction_Cancel) {	// param1 - client, param2 - reason
		if (param2 == MenuCancel_ExitBack)
		{
			BuildRikkaMenu(param1);
		}
	} else if (action == MenuAction_Select)	{	// param1 - client, param2 - itemPos
		if (param2 == 1) {	// No is selected
			BuildRikkaMenu(param1);
		} else {			// Yes is selected
			char menuInfo[10];
			GetMenuItem(menu, param2, menuInfo, sizeof(menuInfo));
			int option = StringToInt(menuInfo);
			
			int cost = GetItemCost(option);
			if (!HasEnoughPoints(param1, cost)) {
				ReplyToCommand(param1, "%s %T", MSGTAG, "Insufficient Funds", param1);
				return;
			}
			
			if(ExecuteItem(param1, option))
				PS_RemovePoints(param1, cost);
		}
	}
}

bool HasEnoughPoints(int iClientIndex, int iCost){
	if(iClientIndex > 0){
		return PS_GetPoints(iClientIndex) >= iCost;
	}
	return false;
}

int GetItemCost(int itemPos) {
	return g_RikkaItemCost[itemPos].IntValue;
}

void GetItemDesc(int clientID, int itemPos, char[] buffer, int maxlen) {
	switch (itemPos)
	{
		case 0:	// Melee Enlarge
		{
			Format(buffer, maxlen, "%T", "Melee Enlarge Desc", clientID);
		}
		default:
		{
			Format(buffer, maxlen, "");
		}
	}
}

bool ExecuteItem(int clientID, int itemPos) {
	switch (itemPos)
	{
		case 0:	// Melee Enlarge
		{
			return EnlargeMelee(clientID);
		}
		case 1:	// Respawn
		{
			return RespawnPlayer(clientID);
		}
	}
	
	return false;
}

bool EnlargeMelee(int clientID) {
	int ent = GetPlayerWeaponSlot(clientID, 1);	// Entity ID
	L4DW_WeaponId wepid = L4DW_IdentifyWeapon(ent);
	
	if (wepid != WEPID_MELEE) {
		// Not a melee weapon! Prompt the player and return
		ReplyToCommand(clientID, "%t", "No melee weapon");
	
		return false;
	}
	
	L4DW_MeleeWeaponId meleeClass = L4DW_IdentifyMelee(ent);
	float scale = 2.5;
	if(meleeClass==WEPID_MACHETE)	scale=4.0;
	if(meleeClass==WEPID_BASEBALL_BAT || WEPID_CRICKET_BAT)	scale=1.7;
	if(meleeClass==WEPID_FRYING_PAN)	scale=3.5;
	if(meleeClass==WEPID_ELECTRIC_GUITAR)	scale=2.3;
	if(meleeClass==WEPID_CHAINSAW_MELEE)	scale=2.0;
	if(meleeClass==WEPID_KATANA)	scale=3.0;
	scale = scale * 1.3;
	
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2); 
	SetEntPropFloat(ent , Prop_Send, "m_flModelScale", scale); 
	
	return true;
}

bool RespawnPlayer(int clientID)
{
	if (IsPlayerAlive(clientID))
	{
		ReplyToCommand(clientID, "%t", "You are not dead");
		
		return false;
	}

	int userflags = GetUserFlagBits(clientID);
	SetUserFlagBits(clientID, ADMFLAG_ROOT);
	int flags = GetCommandFlags("sm_respawn");
	SetCommandFlags("sm_respawn", flags & ~FCVAR_CHEAT);
	FakeClientCommand(clientID, "sm_respawn \"%N\"", clientID);
	SetCommandFlags("sm_respawn", flags);
	SetUserFlagBits(clientID, userflags);

	return true;
}