#pragma semicolon 1
#include <sourcemod>

#define SCA_VERSION "1.0"
#define PATH_MAX 260
#define CFG_FILENAME_LEN_MAX 64

Handle g_hCfgBlackList;

//Plugin Info
public Plugin myinfo = 
{
	name = "Sourcemod Config AutoLoader",
	author = "Rikka0w0 & honorcode23",
	description = "Will make sure that all config files inside cfg/sourcemod folder are executed",
	version = SCA_VERSION,
	url = "No URL available"
}

stock SetupCfgBlackList() {
	g_hCfgBlackList = CreateArray(CFG_FILENAME_LEN_MAX);
	PushArrayString(g_hCfgBlackList, "sourcemod.cfg");
	PushArrayString(g_hCfgBlackList, "sm_warmode_on.cfg");
	PushArrayString(g_hCfgBlackList, "sm_warmode_off.cfg");
	
	// CFG Files included in the list will NOT be executed
	// FileName should include .cfg
	// Add more to black list here
}

public OnPluginStart() {
	SetupCfgBlackList();
	
	CreateConVar("sm_config_loader_version", SCA_VERSION, "Version of Sourcemod Config Loader plugin", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegAdminCmd("sm_exec_configs", CmdExecAllCfg, ADMFLAG_RCON, "Will execute all sourcemod configs again");
	RegAdminCmd("sm_list_configs", CmdListCfgs, ADMFLAG_RCON, "Will list all sourcemod configs that will be executed at the beginning of each map");
}

public Action CmdExecAllCfg(client, args) {
	ExecuteAllConfigs(client);
	return Plugin_Handled;
}

public Action CmdListCfgs(client, args) {
	ListConfigs(client);
	return Plugin_Handled;
}

DirectoryListing directoryListingExec;
public Action ExecConfigs(Handle timer, any client) {
	if (directoryListingExec == INVALID_HANDLE) {
		ReplyToCommand(client, "[SM] Cannot open cfg/sourcemod, aborting");
		return Plugin_Stop;
	}

	int executed = 0;
	char configFileName[PATH_MAX];
	FileType fileType;
	while (directoryListingExec.GetNext(configFileName, PATH_MAX, fileType)) {
		if (fileType == FileType_File) {
			if(FindStringInArray(g_hCfgBlackList, configFileName) == -1) {
				// Not in black list
				ReplyToCommand(client, "Executed: %s", configFileName);
				ServerCommand("exec sourcemod/%s", configFileName);
				
				executed++;
				if (executed > 10) {
					CreateTimer(0.1, ExecConfigs, client);
					return Plugin_Stop;
				}
			}
		}
	}
	
	CloseHandle(directoryListingExec);
	return Plugin_Stop;
}

stock ExecuteAllConfigs(int client) {
	directoryListingExec = OpenDirectory("cfg/sourcemod", false, NULL_STRING);
	
	if (directoryListingExec == INVALID_HANDLE) {
		ReplyToCommand(client, "[SM] Cannot open cfg/sourcemod, aborting");
		return;
	}
	
	ReplyToCommand(client, "[SM] Executing Sourcemod configuration files");
	ExecConfigs(INVALID_HANDLE, client);
}

stock ListConfigs(int client) {
	DirectoryListing directoryListing;
	directoryListing = OpenDirectory("cfg/sourcemod", false, NULL_STRING);
	
	if (directoryListing == INVALID_HANDLE) {
		ReplyToCommand(client, "[SM] Cannot open cfg/sourcemod, aborting");
		return;
	}
	
	ReplyToCommand(client, "[SM] Sourcemod config files:");
	
	int executed = 0;
	int skipped = 0;
	char configFileName[PATH_MAX];
	FileType fileType;
	while (directoryListing.GetNext(configFileName, PATH_MAX, fileType)) {
		if (fileType == FileType_File) {
			if(FindStringInArray(g_hCfgBlackList, configFileName) == -1) {
				// Not in black list
				ReplyToCommand(client, "File: %s", configFileName);
				executed++;
			} else {
				ReplyToCommand(client, "Skip: %s", configFileName);
				skipped++;
			}
		}
	}
	
	CloseHandle(directoryListing);
	ReplyToCommand(client, "[SM] Found %d configs, %d in blacklist.", executed, skipped);
}