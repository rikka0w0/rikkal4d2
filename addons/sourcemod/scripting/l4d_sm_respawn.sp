#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0.0"


public Plugin myinfo = {
	name = "L4D SM Respawn",
	author = "Rikka0w0, AtomicStryker & Ivailosp",
	description = "Let's you respawn Players by console",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=96249"
}

static float g_pos[3];
static Handle hRoundRespawn = INVALID_HANDLE;
static Handle hBecomeGhost = INVALID_HANDLE;
static Handle hState_Transition = INVALID_HANDLE;
static Handle hGameConf = INVALID_HANDLE;

public void OnPluginStart() {
	char game_name[24];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false) && !StrEqual(game_name, "left4dead", false)) {
		SetFailState("L4D_SM_Respawn supports Left 4 Dead and L4D2 only.");
	}

	LoadTranslations("common.phrases");
	LoadTranslations("l4d_sm_respawn.phrases");
	hGameConf = LoadGameConfigFile("l4drespawn");

	FireOnAdminMenuReady();
	
	CreateConVar("l4d_sm_respawn_version", PLUGIN_VERSION, "L4D SM Respawn Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_BAN, "sm_respawn <player1> [player2] ... [playerN] - respawn all listed players and teleport them where you aim");

	if (hGameConf != INVALID_HANDLE) {
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RoundRespawn");
		hRoundRespawn = EndPrepSDKCall();
		if (hRoundRespawn == INVALID_HANDLE) SetFailState("L4D_SM_Respawn: RoundRespawn Signature broken");
		
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "BecomeGhost");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hBecomeGhost = EndPrepSDKCall();
		if (hBecomeGhost == INVALID_HANDLE && StrEqual(game_name, "left4dead2", false))
			LogError("L4D_SM_Respawn: BecomeGhost Signature broken");

		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "State_Transition");
		PrepSDKCall_AddParameter(SDKType_PlainOldData , SDKPass_Plain);
		hState_Transition = EndPrepSDKCall();
		if (hState_Transition == INVALID_HANDLE && StrEqual(game_name, "left4dead2", false))
			LogError("L4D_SM_Respawn: State_Transition Signature broken");
	} else {
		SetFailState("could not find gamedata file at addons/sourcemod/gamedata/l4drespawn.txt , you FAILED AT INSTALLING");
	}
}

public Action Command_Respawn(int client, int args) {
	if (args < 1) {
		ReplyToCommand(client, "%t", "Usage");
		return Plugin_Handled;
	}
	
	char arg1[MAX_TARGET_LENGTH];
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	
	GetCmdArg(1, arg1, sizeof(arg1));
 
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			0,				// no filtering
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; i++)
	{
		RespawnPlayer(client, target_list[i]);
	}
	
	ReplyToCommand(client, "%t", "Respawned target", target_name);
	
	return Plugin_Handled;
}

static void RespawnPlayer(int client, int player_id) {
	switch(GetClientTeam(player_id)) {
		case 2:	{
			bool canTeleport = SetTeleportEndPoint(client);
		
			SDKCall(hRoundRespawn, player_id);
			
			CheatCommand(player_id, "give", "first_aid_kit");
			CheatCommand(player_id, "give", "smg");
			
			if(canTeleport)
			{
				PerformTeleport(client,player_id,g_pos);
			}
		}
		
		case 3:	{
			char game_name[24];
			GetGameFolderName(game_name, sizeof(game_name));
			if (StrEqual(game_name, "left4dead", false)) return;
		
			SDKCall(hState_Transition, player_id, 8);
			SDKCall(hBecomeGhost, player_id, 1);
			SDKCall(hState_Transition, player_id, 6);
			SDKCall(hBecomeGhost, player_id, 1);
		}
	}
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients || !entity;
} 

static bool SetTeleportEndPoint(int client) {
	float vAngles[3];
	float vOrigin[3];
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	//get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace)) {
		float vBuffer[3];
		float vStart[3];

		TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		float Distance = -35.0;
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		g_pos[0] = vStart[0] + (vBuffer[0]*Distance);
		g_pos[1] = vStart[1] + (vBuffer[1]*Distance);
		g_pos[2] = vStart[2] + (vBuffer[2]*Distance);
	} else {
		PrintToChat(client, "%t", "Cannot teleport");
		CloseHandle(trace);
		return false;
	}
	CloseHandle(trace);
	return true;
}

void PerformTeleport(int client, int target, float pos[3]) {
	pos[2]+=40.0;
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	
	LogAction(client,target, "\"%L\" teleported \"%L\" after respawning him" , client, target);
}

stock void CheatCommand(int client, char[] command, char[] arguments="") {
	int userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}

/* ========== Admin Menu ========== */
// Keep track of the top menu
TopMenu g_TopMenu_AdminMenu = null;

void FireOnAdminMenuReady() {
	/* See if the menu plugin is already ready */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
		/* If so, manually fire the callback */
		OnAdminMenuReady(topmenu);
	}
}

public void OnAdminMenuReady(Handle hTopMenu) {
	TopMenu topmenu = TopMenu.FromHandle(hTopMenu);
	
	/* Block us from being called twice */
	if (topmenu == g_TopMenu_AdminMenu) {
		return;
	}
	g_TopMenu_AdminMenu = topmenu;
	
	// Add menu entries
	TopMenuObject adminmenu_playercommands = FindTopMenuCategory(topmenu, ADMINMENU_PLAYERCOMMANDS);	
	AddToTopMenu(topmenu, "respawn_player", TopMenuObject_Item, ItemHandler, adminmenu_playercommands);
}

public void ItemHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int clientID, char[] buffer, int maxlength) {
	if (action == TopMenuAction_DisplayOption) {
		Format(buffer, maxlength, "%T", "Respawn Player", clientID);
	} else if (action == TopMenuAction_SelectOption) {
		// The admin menu item was selected, display the dead player list
		CreateAndDisplayMenu(clientID);
	}
}

bool CreateAndDisplayMenu(int clientID) {
		Menu playerList = CreateMenu(PlayerListHandler, MenuAction_Select | MenuAction_Cancel);
		playerList.SetTitle("%T", "Respawn Player", clientID);
		
		int numberOfDead = AddTargetsToMenu2(playerList, clientID, COMMAND_FILTER_DEAD | COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS);
		if (numberOfDead == 0) {
			PrintToChat(clientID, "%t", "Nobody is dead");
			delete playerList;
			return false;
		}
		
		//Add an exit button
		playerList.ExitButton = true;
		playerList.ExitBackButton = true;
		
		//And finally, show the menu to the client
		playerList.Display(clientID, MENU_TIME_FOREVER);
		return true;
}

public int PlayerListHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Cancel) {	// param1 - clientID, param2 - reason
		if (param2 == MenuCancel_ExitBack) {
			// Back option is select
			// Display the previous admin menu
			DisplayTopMenu(g_TopMenu_AdminMenu, param1, TopMenuPosition_LastCategory);
		}
		delete menu;
		return 0;
	}
	
	char menuInfo[64];	
	char menuName[64];
	
	if(action == MenuAction_Select)	{ // param1 - clientID, param2 - itemID
		menu.GetItem(param2, menuInfo, sizeof(menuInfo), _, menuName, sizeof(menuName));
		int targetClientID = GetClientOfUserId(StringToInt(menuInfo));
		RespawnPlayer(param1, targetClientID);
		
		CreateAndDisplayMenu(param1);
	}
	
	return 0;
}