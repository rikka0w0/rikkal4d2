/************************************************
* Plugin name:		[L4D2] MultiSlots
* Plugin author:	SwiftReal
* 
* Based upon:
* - (L4D) Zombie Havoc by Bigbuck
* - (L4D2) Bebop by frool
* - Bots Control In Coop Mode by Pan XiaoHai
* - Survivor Bot Takeover by MasterMe
*
* Version 1.0
* 		- Initial Release
* Version 2.0
* 		- Fixed this shit
************************************************/

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION 				"2.0"
#define CVAR_FLAGS					FCVAR_PLUGIN|FCVAR_NOTIFY
#define DELAY_KICK_FAKECLIENT 		0.1
#define DELAY_KICK_NONEEDBOT 		5.0
#define DELAY_CHANGETEAM_NEWPLAYER 	1.5
#define TEAM_SPECTATORS 			1
#define TEAM_SURVIVORS 				2
#define DAMAGE_EVENTS_ONLY			1
#define	DAMAGE_YES					2

new Handle:hMaxSurvivors
new Handle:timer_SpawnTick = INVALID_HANDLE
new Handle:timer_SpecCheck = INVALID_HANDLE
new Handle:hKickIdlers
new bool:gbVehicleLeaving
new bool:gbPlayedAsSurvivorBefore[MAXPLAYERS+1]
new bool:gbFirstItemPickedUp
new bool:gbPlayerPickedUpFirstItem[MAXPLAYERS+1]
//new Float:vecLocationStart[3]
new String:gMapName[128]
new giIdleTicks[MAXPLAYERS+1]

public Plugin:myinfo = 
{
	name 			= "[L4D2] MultiSlots",
	author 			= "SwiftReal, MI 5, Pan XiaoHai, MasterMe",
	description 	= "Allows additional survivor players in coop, survival, and scavenge gameplay modes",
	version 		= PLUGIN_VERSION,
	url 			= "http://l4d2maps.us/"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	// This plugin will only work on L4D2
	decl String:GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead2", false) == -1)
		return APLRes_Failure; 
	
	return APLRes_Success; 
}

public OnPluginStart()
{
	// Create plugin version cvar and set it
	CreateConVar("l4d2_multislots_version", PLUGIN_VERSION, "L4D2 MultiSlots version", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED)
	SetConVarString(FindConVar("l4d2_multislots_version"), PLUGIN_VERSION)
	
	// Register commands
	RegAdminCmd("sm_addbot", AddBot, ADMFLAG_KICK, "Attempt to add and teleport a survivor bot")
	RegConsoleCmd("sm_join", JoinTeam, "Attempt to join Survivors")
	RegConsoleCmd("sm_jointeam1", ClientToSpectate, "Attempt to join spectator team")
	RegConsoleCmd("sm_afk", ClientToSpectate, "Attempt to join spectator team")
	RegConsoleCmd("sm_spectate", ClientToSpectate, "Attempt to join spectator team")
	
	// Register cvars
	hMaxSurvivors = CreateConVar("l4d2_multislots_max_survivors", "8", "How many survivors allowed?", CVAR_FLAGS, true, 4.0, true, 32.0)
	hKickIdlers = CreateConVar("l4d2_multislots_kickafk", "1", "Kick idle players? (0 = no  1 = player 10 min, admins kickimmune 2 = player 10 min, admins 20 min)", CVAR_FLAGS, true, 0.0, true, 2.0)
	
	// Hook events
	HookEvent("item_pickup", evtRoundStartAndItemPickup)
	HookEvent("player_left_start_area", evtPlayerLeftStart)
	HookEvent("survivor_rescued", evtSurvivorRescued)
	HookEvent("finale_vehicle_leaving", evtFinaleVehicleLeaving)
	HookEvent("mission_lost", evtMissionLost)
	HookEvent("player_activate", evtPlayerActivate)
	HookEvent("bot_player_replace", evtPlayerReplacedBot)
	HookEvent("player_bot_replace", evtBotReplacedPlayer)
	
	// Create or execute plugin configuration file
	AutoExecConfig(true, "l4d2multislots")	
}

public OnMapStart()
{
	GetCurrentMap(gMapName, sizeof(gMapName))
	//FindLocationStart()
	TweakSettings()
	gbFirstItemPickedUp = false
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
	if(client)
	{
		gbPlayedAsSurvivorBefore[client] = false
		gbPlayerPickedUpFirstItem[client] = false
		giIdleTicks[client] = 0
	}	
	return true
}

public OnClientDisconnect(client)
{
	gbPlayedAsSurvivorBefore[client] = false
	gbPlayerPickedUpFirstItem[client] = false
}

public OnMapEnd()
{
	StopTimers()
	gbVehicleLeaving = false
	gbFirstItemPickedUp = false
}

////////////////////////////////////
// Callbacks
////////////////////////////////////

public Action:ClientToSpectate(client, argCount)
{
	ChangeClientTeam(client, 1)
	return Plugin_Handled
}

public Action:AddBot(client, args)
{
	SpawnFakeClientAndTeleport()		
	ServerCommand("sb_add")
	return Plugin_Handled
}

public Action:JoinTeam(client, args)
{
	if(!IsClientConnected(client))
		return Plugin_Handled
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == TEAM_SURVIVORS)
		{	
			if(DispatchKeyValue(client, "classname", "player") == true)
			{
				PrintHintText(client, "You are already a survivor kemosabe.")
			}
			else if((DispatchKeyValue(client, "classname", "info_survivor_position") == true) && !IsClientAlive(client))
			{
				PrintHintText(client, "You are dead. Wait for rescue or defib.")
			}
		}
		else if(IsClientIdle(client))
		{
			PrintHintText(client, "Press your mouse to hunt the walking dead.")
		}
		else
		{			
			if(TotalFreeBots() == 0)
			{
				SpawnFakeClientAndTeleport()
				
				CreateTimer(1.0, Timer_AutoJoinTeam, client, TIMER_REPEAT)				
			}
			else
				TakeOverBot(client, false)
		}
	}	
	return Plugin_Handled
}

////////////////////////////////////
// Events
////////////////////////////////////

public evtRoundStartAndItemPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!gbFirstItemPickedUp)
	{
		// alternative to round start...
		if(timer_SpecCheck == INVALID_HANDLE)
			timer_SpecCheck = CreateTimer(15.0, Timer_SpecCheck, _, TIMER_REPEAT)	
		
		gbFirstItemPickedUp = true
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(!gbPlayerPickedUpFirstItem[client] && !IsFakeClient(client))
	{
		// force setting client cvars here...
		//ForceClientCvars(client)
		gbPlayerPickedUpFirstItem[client] = true
		gbPlayedAsSurvivorBefore[client] = true
	}
}

public evtPlayerActivate(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client)
	{
		if((GetClientTeam(client) != TEAM_SURVIVORS) && !IsFakeClient(client) && !IsClientIdle(client))
			CreateTimer(DELAY_CHANGETEAM_NEWPLAYER, Timer_AutoJoinTeam, client, TIMER_REPEAT)
	}
}

public evtPlayerLeftStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(client)
	{
		if(IsClientConnected(client) && IsClientInGame(client))
		{
			if(GetClientTeam(client)==TEAM_SURVIVORS)
				gbPlayedAsSurvivorBefore[client] = true
		}
	}
}

public evtPlayerReplacedBot(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "player"))
	if(!client) return
	if(GetClientTeam(client)!=TEAM_SURVIVORS || IsFakeClient(client)) return
	
	if(!gbPlayedAsSurvivorBefore[client])
	{
		//ForceClientCvars(client)
		gbPlayedAsSurvivorBefore[client] = true
		giIdleTicks[client] = 0
		
		decl String:GameMode[30]
		GetConVarString(FindConVar("mp_gamemode"), GameMode, sizeof(GameMode))			
		if(StrEqual(GameMode, "mutation3", false))
		{
			SetEntityHealth(client, 1)
			SetEntityTempHealth(client, 99)
		}
		
		decl String:PlayerName[100]
		GetClientName(client, PlayerName, sizeof(PlayerName))
		PrintToChatAll("\x04MAN UP BITCHES! \x03%s is here to save all your arses and kill ALL zombos!", PlayerName)
	}
}

public evtBotReplacedPlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new bot = GetClientOfUserId(GetEventInt(event, "bot"))
	if(GetClientTeam(bot) == TEAM_SURVIVORS)
		CreateTimer(DELAY_KICK_NONEEDBOT, Timer_KickNoNeededBot, bot)
}

public evtSurvivorRescued(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"))
	if(client)
	{	
		BypassAndExecuteCommand(client, "give", "weapon_smg_silenced")
		BypassAndExecuteCommand(client, "give", "weapon_pistol_magnum")
		if(StrContains(gMapName, "c1m1", false) == -1)
			GiveWeapon(client)
	}
}

public evtFinaleVehicleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && IsClientAlive(i))
			{
				SetEntProp(i, Prop_Data, "m_takedamage", DAMAGE_EVENTS_ONLY, 1)
				new Float:newOrigin[3] = {0.0, 0.0, 0.0}
				TeleportEntity(i, newOrigin, NULL_VECTOR, NULL_VECTOR)
				SetEntProp(i, Prop_Data, "m_takedamage", DAMAGE_YES, 1)
			}
		}
	}	
	StopTimers()
	gbVehicleLeaving = true
}

public evtMissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	gbFirstItemPickedUp = false
}

////////////////////////////////////
// timers
////////////////////////////////////

public Action:Timer_SpawnTick(Handle:timer)
{
	new iTotalSurvivors = TotalSurvivors()
	if(iTotalSurvivors >= 4)
	{
		timer_SpawnTick = INVALID_HANDLE		
		return Plugin_Stop
	}
	
	for(; iTotalSurvivors < 4; iTotalSurvivors++)
		SpawnFakeClient()
	
	return Plugin_Continue
}

public Action:Timer_SpecCheck(Handle:timer)
{
	if(gbVehicleLeaving) return Plugin_Stop
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SPECTATORS) && !IsFakeClient(i))
			{
				if(!IsClientIdle(i))
				{
					new String:PlayerName[100]
					GetClientName(i, PlayerName, sizeof(PlayerName))		
					PrintToChat(i, "\x03WANNA HUNT ZOMBIES? \x04type \x03!join \x04in chat - THEN KILL EM ALL AND LET BABY JESUS SORT EM OUT!", PlayerName)
				}
				switch(GetConVarInt(hKickIdlers))
				{
					case 0: {}
					case 1:
					{
						if(GetUserFlagBits(i) == 0)
						{
							giIdleTicks[i]++
							if(giIdleTicks[i] == 40)
								KickClient(i, "Player idle longer than 10 min.")
						}
					}
					case 2:
					{
						giIdleTicks[i]++
						if(GetUserFlagBits(i) == 0)
						{
							if(giIdleTicks[i] == 40)
								KickClient(i, "Player idle longer than 10 min.")
						}
						else
						{
							if(giIdleTicks[i] == 80)
								KickClient(i, "Good Sir idle longer than 20 min.")
						}
					}
				}
			}
		}
	}
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))		
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && !IsClientAlive(i))
			{
				new String:PlayerName[100]
				GetClientName(i, PlayerName, sizeof(PlayerName))
				PrintToChat(i, "\x01[\x04DEAD MAN WATCHING\x01] %s, zombies gnawed you to death and you need to be rescued or revived.", PlayerName)
			}
		}
	}	
	return Plugin_Continue
}

public Action:Timer_AutoJoinTeam(Handle:timer, any:client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop
	
	if(IsClientInGame(client))
	{
		if(GetClientTeam(client) == TEAM_SURVIVORS)
			return Plugin_Stop
		if(IsClientIdle(client))
			return Plugin_Stop
		
		JoinTeam(client, 0)
	}
	return Plugin_Continue
}

public Action:Timer_KickNoNeededBot(Handle:timer, any:bot)
{
	if((TotalSurvivors() <= 4))
		return Plugin_Handled
	
	if(IsClientConnected(bot) && IsClientInGame(bot))
	{
		decl String:BotName[100]
		GetClientName(bot, BotName, sizeof(BotName))				
		if(StrEqual(BotName, "FakeClient", true))
			return Plugin_Handled
		
		if(!HasIdlePlayer(bot))
		{
			KickClient(bot, "Kicking No Needed Bot")
		}
	}	
	return Plugin_Handled
}

public Action:Timer_KickFakeBot(Handle:timer, any:fakeclient)
{
	if(IsClientConnected(fakeclient))
	{
		KickClient(fakeclient, "Kicking FakeClient")		
		return Plugin_Stop
	}	
	return Plugin_Continue
}

////////////////////////////////////
// stocks
////////////////////////////////////

stock TweakSettings()
{
	new Handle:hMaxSurvivorsLimitCvar = FindConVar("survivor_limit")
	SetConVarBounds(hMaxSurvivorsLimitCvar, ConVarBound_Lower, true, 4.0)
	SetConVarBounds(hMaxSurvivorsLimitCvar, ConVarBound_Upper, true, 32.0)
	SetConVarInt(hMaxSurvivorsLimitCvar, GetConVarInt(hMaxSurvivors))

	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000) // allow spawning bots at any time
}

stock TakeOverBot(client, bool:completely)
{
	if (!IsClientInGame(client)) return
	if (GetClientTeam(client) == TEAM_SURVIVORS) return
	if (IsFakeClient(client)) return
	
	new bot = FindBotToTakeOver()	
	if (bot==0)
	{
		PrintHintText(client, "There are no survivor bots to take over.")
		return
	}
	
	static Handle:hSetHumanSpec
	if (hSetHumanSpec == INVALID_HANDLE)
	{
		new Handle:hGameConf		
		hGameConf = LoadGameConfigFile("l4d2multislots")
		
		StartPrepSDKCall(SDKCall_Player)
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec")
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer)
		hSetHumanSpec = EndPrepSDKCall()
	}
	
	static Handle:hTakeOverBot
	if (hTakeOverBot == INVALID_HANDLE)
	{
		new Handle:hGameConf		
		hGameConf = LoadGameConfigFile("l4d2multislots")
		
		StartPrepSDKCall(SDKCall_Player)
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TakeOverBot")
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain)
		hTakeOverBot = EndPrepSDKCall()
	}
	
	if(completely)
	{
		SDKCall(hSetHumanSpec, bot, client)
		SDKCall(hTakeOverBot, client, true)
	}
	else
	{
		SDKCall(hSetHumanSpec, bot, client)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5)
	}
	
	return
}

stock FindBotToTakeOver(team=TEAM_SURVIVORS)
{
	new maxplayers = GetMaxClients();

	for (new bot = 1; bot <= maxplayers; bot++)
	{
		if (!IsClientConnected(bot))
			continue
		if (!IsFakeClient(bot))
			continue
		if (GetClientTeam(bot) != team)
			continue
		if (!IsClientAlive(bot))
			continue
		return bot
	}
	return 0
}

stock SetEntityTempHealth(client, hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime())
	new Float:newOverheal = hp * 1.0; // prevent tag mismatch
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal)
}

stock BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand)
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT)
	FakeClientCommand(client, "%s %s", strCommand, strParam1)
	SetCommandFlags(strCommand, flags)
}

stock GiveWeapon(client)
{
	BypassAndExecuteCommand(client, "give", "weapon_hunting_rifle")
	BypassAndExecuteCommand(client, "give", "weapon_pistol_magnum")
}

stock StopTimers()
{
	if(timer_SpawnTick != INVALID_HANDLE)
	{
		KillTimer(timer_SpawnTick)
		timer_SpawnTick = INVALID_HANDLE
	}	
	if(timer_SpecCheck != INVALID_HANDLE)
	{
		KillTimer(timer_SpecCheck)
		timer_SpecCheck = INVALID_HANDLE
	}	
}

stock TotalFreeBots() // total bots (excl. IDLE players)
{
	new int = 0
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if(IsFakeClient(i) && GetClientTeam(i)==TEAM_SURVIVORS)
			{
				if(!HasIdlePlayer(i))
					int++
			}
		}
	}
	return int
}

stock TotalSurvivors() // total bots, including players
{
	new int = 0
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS))
				int++
		}
	}
	return int
}

////////////////////////////////////
// bools
////////////////////////////////////

stock bool:SpawnFakeClient()
{
	new bool:fakeclientKicked = false
	
	// create fakeclient
	new fakeclient = 0
	fakeclient = CreateFakeClient("FakeClient")
	
	// if entity is valid
	if(fakeclient != 0)
	{
		// move into survivor team
		ChangeClientTeam(fakeclient, TEAM_SURVIVORS)
		
		// check if entity classname is survivorbot
		if(DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)
		{
			// spawn the client
			if(DispatchSpawn(fakeclient) == true)
			{	
				// kick the fake client to make the bot take over
				CreateTimer(DELAY_KICK_FAKECLIENT, Timer_KickFakeBot, fakeclient, TIMER_REPEAT)
				fakeclientKicked = true
			}
		}			
		// if something went wrong, kick the created FakeClient
		if(fakeclientKicked == false)
			KickClient(fakeclient, "Kicking FakeClient")
	}	
	return fakeclientKicked
}

stock bool:SpawnFakeClientAndTeleport()
{
	new bool:fakeclientKicked = false
	
	// create fakeclient
	new fakeclient = CreateFakeClient("FakeClient")
	
	// if entity is valid
	if(fakeclient != 0)
	{
		// move into survivor team
		ChangeClientTeam(fakeclient, TEAM_SURVIVORS)
		
		// check if entity classname is survivorbot
		if(DispatchKeyValue(fakeclient, "classname", "survivorbot") == true)
		{
			// spawn the client
			if(DispatchSpawn(fakeclient) == true)
			{
				// teleport client to the position of any active alive player
				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVORS) && !IsFakeClient(i) && IsClientAlive(i) && i != fakeclient)
					{						
						// get the position coordinates of any active alive player
						new Float:teleportOrigin[3]
						GetClientAbsOrigin(i, teleportOrigin)				
						TeleportEntity(fakeclient, teleportOrigin, NULL_VECTOR, NULL_VECTOR)						
						break
					}
				}				
				BypassAndExecuteCommand(fakeclient, "give", "weapon_melee_machete")
				if(StrContains(gMapName, "c1m1_hotel", false) == -1)
					GiveWeapon(fakeclient)
				
				// kick the fake client to make the bot take over
				CreateTimer(DELAY_KICK_FAKECLIENT, Timer_KickFakeBot, fakeclient, TIMER_REPEAT)
				fakeclientKicked = true
			}
		}			
		// if something went wrong, kick the created FakeClient
		if(fakeclientKicked == false)
			KickClient(fakeclient, "Kicking FakeClient")
	}	
	return fakeclientKicked
}

stock bool:HasIdlePlayer(bot)
{
	if(!IsFakeClient(bot))
		return false
	
	if(IsClientConnected(bot) && IsClientInGame(bot))
	{
		if((GetClientTeam(bot) == TEAM_SURVIVORS) && IsClientAlive(bot))
		{
			if(IsFakeClient(bot))
			{
				new client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"))			
				if(client)
				{
					if(!IsFakeClient(client) && (GetClientTeam(client) == TEAM_SPECTATORS))
						return true
				}
			}
		}
	}
	return false
}

bool:IsClientIdle(client)
{
	if(GetClientTeam(client) != TEAM_SPECTATORS)
		return false
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			if((GetClientTeam(i) == TEAM_SURVIVORS) && IsClientAlive(i))
			{
				if(IsFakeClient(i))
				{
					if(GetClientOfUserId(GetEntProp(i, Prop_Send, "m_humanSpectatorUserID")) == client)
						return true
				}
			}
		}
	}
	return false
}

stock bool:IsClientAlive(client)
{
	if (!IsClientConnected(client))
		return false

	if (IsFakeClient(client))
		return GetClientHealth(client) > 0 && GetEntProp(client, Prop_Send, "m_lifeState") == 0
	else if (!IsClientInGame(client))
			return false

	return IsPlayerAlive(client)
}

stock bool:IsClientInTeam(client, team=TEAM_SURVIVORS)
{
	if (client <= 0 || !IsClientConnected(client))
		return false

	if (IsFakeClient(client))
		return (GetClientTeam(client) == team)
	else
		return (IsClientInGame(client) && GetClientTeam(client) == team)
}

stock bool:IsClientInGameHuman(client, team=TEAM_SURVIVORS)
{
	if (client > 0)	
		return IsClientConnected(client) && !IsFakeClient(client) && IsClientInGame(client) && GetClientTeam(client) == team
	else return false
}

stock bool:IsClientInGameBot(client, team=TEAM_SURVIVORS)
{
	if (client > 0)	
		return IsClientConnected(client) && IsFakeClient(client) && GetClientTeam(client) == team
	else return false
}