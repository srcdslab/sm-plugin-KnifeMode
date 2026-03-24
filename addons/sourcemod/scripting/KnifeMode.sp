#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiereloaded>
#include <multicolors>

#define WEAPONS_MAX_LENGTH 32

bool    g_bSpectate = false,
		g_bUnload = false,
		g_bSpectateHooked = false,
		g_bSpectateDisable = false,
		g_bKillLastZM = true,
		g_bTeamKill = false,
		g_ZombieExplode[MAXPLAYERS+1] = { false, ... },
		g_bEnabled = true;

ConVar  g_cvExplodeTime, 
		g_cvSpectateDisable, 
		g_cvUnload,
		g_cvKillLastZM,
		g_cvSpectate,
		g_cvTeamKill,
		g_cvEnabled;

float g_fExplodeTime = 3.0;
GlobalForward g_fwdOnToggle;

public Plugin myinfo =
{
	name = "[ZR] Knife Mode",
	author = "Franc1sco steam: franug, inGame, maxime1907, .Rushaway",
	description = "Kill zombies with knife",
	version = "2.7.9",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("KnifeMode");
	g_fwdOnToggle = new GlobalForward("KnifeMode_OnToggle", ET_Ignore, Param_Cell);
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_knifemode_enabled", "1", "Enable or disable Knife Mode [0 = Off | 1 = On]", _, true, 0.0, true, 1.0);
	g_cvExplodeTime = CreateConVar("sm_knifemode_time", "3", "Seconds that a zombie has to catch any human (60s max)", _, true, 0.1, true, 60.0);
	g_cvUnload = CreateConVar("sm_knifemode_unload", "0", "Automaticaly disable knifemode on map end [0 = No | 1 = Yes, disable it.]", _, true, 0.0, true, 1.0);
	g_cvSpectateDisable = CreateConVar("sm_knifemode_spectate_disable", "0", "Automaticaly disable the spectate command on map start [0 = No | 1 = Yes, disable it.]", _, true, 0.0, true, 1.0);
	g_cvKillLastZM = CreateConVar("sm_knifemode_kill_lastzm", "1", "Allow last zombie alive to be killed by a knife ? [0 = No | 1 = Yes, kill it.]", _, true, 0.0, true, 1.0);
	g_cvTeamKill = CreateConVar("sm_knifemode_allow_teamkill", "1", "Allow knifed zombie to be killed if attacker has become zombie [0 = No | 1 = Yes, allow it.]", _, true, 0.0, true, 1.0);


	g_cvEnabled.AddChangeHook(OnConVarChanged);
	g_cvExplodeTime.AddChangeHook(OnConVarChanged);
	g_cvUnload.AddChangeHook(OnConVarChanged);
	g_cvSpectateDisable.AddChangeHook(OnConVarChanged);
	g_cvKillLastZM.AddChangeHook(OnConVarChanged);
	g_cvTeamKill.AddChangeHook(OnConVarChanged);

	g_bEnabled = g_cvEnabled.BoolValue;
	g_fExplodeTime = g_cvExplodeTime.FloatValue;
	g_bUnload = g_cvUnload.BoolValue;
	g_bSpectateDisable = g_cvSpectateDisable.BoolValue;
	g_bKillLastZM = g_cvKillLastZM.BoolValue;
	g_bTeamKill = g_cvTeamKill.BoolValue;

	if (g_bEnabled)
	{
		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("player_hurt", Event_PlayerHurt);
		HookEvent("round_start", Event_RoundStart);
	}

	AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
	g_bSpectate = LibraryExists("Spectate");
	SendForward();
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "Spectate", false) == 0)
		g_bSpectate = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "Spectate", false) == 0)
		UnHookSpectate();
}

public void OnConfigsExecuted()
{
	if (g_bSpectateDisable)
		ToggleSpecEnable(false);
}

public void OnMapEnd()
{
	if (g_bSpectateDisable)
		ToggleSpecEnable(true);

	UnHookSpectate();

	if (g_bUnload && g_cvEnabled.BoolValue == true)
		ToggleKnifeMode(false);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvEnabled)
		ToggleKnifeMode(g_cvEnabled.BoolValue);
	else if (convar == g_cvExplodeTime)
		g_fExplodeTime = g_cvExplodeTime.FloatValue;
	else if (convar == g_cvUnload)
		g_bUnload = g_cvUnload.BoolValue;
	else if (convar == g_cvSpectateDisable)
		g_bSpectateDisable = g_cvSpectateDisable.BoolValue;
	else if (convar == g_cvKillLastZM)
		g_bKillLastZM = g_cvKillLastZM.BoolValue;
	else if (convar == g_cvTeamKill)
		g_bTeamKill = g_cvTeamKill.BoolValue;
	else if (convar == g_cvSpectate && g_bSpectateDisable && g_cvSpectate.BoolValue)
		ToggleSpecEnable(false);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;

	CPrintToChatAll("{fullred}[Knife Mode] {white}You can use your knife to kill Zombies!");
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;

	int attackerid = event.GetInt("attacker");
	int attacker = GetClientOfUserId(attackerid);
	
	if (!attacker || !IsPlayerAlive(attacker) || ZR_IsClientZombie(attacker))
		return;
	
	int clientid = event.GetInt("userid");
	int client = GetClientOfUserId(clientid);

	if (!client || !IsPlayerAlive(client) || !ZR_IsClientZombie(client))
		return;

	char weapon[WEAPONS_MAX_LENGTH];
	event.GetString("weapon", weapon, sizeof(weapon));

	if (strcmp(weapon, "knife", false) != 0 || g_ZombieExplode[client] || (!g_bKillLastZM && GetTeamAliveCount(CS_TEAM_T) <= 1))
		return;

	DataPack pack = new DataPack();
	pack.WriteCell(clientid);
	pack.WriteCell(attackerid);
	CreateTimer(g_fExplodeTime, ByeZM, pack, TIMER_FLAG_NO_MAPCHANGE);

	PrintCenterText(client, "[Knife Mode] You have %0.1f seconds to catch any human or you will die!", g_fExplodeTime);
	CPrintToChat(client, "{green}[Knife Mode] {white}You have {red}%0.1f seconds {white}to catch any human {red}or you will die!", g_fExplodeTime);

	g_ZombieExplode[client] = true;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if (!g_bEnabled || motherInfect)
		return;

	if (attacker < 1 || attacker > MaxClients)
		return;

	if (!g_ZombieExplode[attacker])
		return;

	g_ZombieExplode[attacker] = false;

	PrintCenterText(attacker, "[Knife Mode] You have caught a human, you are saved!");
	CPrintToChat(attacker, "{green}[Knife Mode] {white}You have caught a human, you are saved!");
}

public Action ByeZM(Handle timer, DataPack pack)
{
	if (!g_bEnabled)
	{
		delete pack;
		return Plugin_Stop;
	}

	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());

	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}

	int attacker = GetClientOfUserId(pack.ReadCell());
	delete pack;

	if (!g_ZombieExplode[client])
		return Plugin_Stop;

	g_ZombieExplode[client] = false;

	if (!attacker)
	{
		PrintCenterText(client, "[Knife Mode] Attacker left the game, you are saved!");
		CPrintToChat(client, "{green}[Knife Mode] {white}Attacker left the game, you are saved!");
		return Plugin_Stop;
	}

	// Another check : In case 2 different pack is in progress for differents clients
	if (!g_bKillLastZM && GetTeamAliveCount(CS_TEAM_T) <= 1)
	{
		PrintCenterText(client, "[Knife Mode] You are the last Zombie alive, canceling your death!");
		CPrintToChat(client, "{green}[Knife Mode] {white}You are the last Zombie alive, canceling your death!");
		return Plugin_Stop;
	}
	else if (!g_bTeamKill && (!IsPlayerAlive(attacker) || ZR_IsClientZombie(attacker)))
	{
		PrintCenterText(client, "[Knife Mode] Attacker is no longer human, you are saved!");
		CPrintToChat(client, "{green}[Knife Mode] {white}Attacker is no longer human, you are saved!");
		return Plugin_Stop;
	}

	if (IsPlayerAlive(client) && ZR_IsClientZombie(client))
	{
		int knife = GetPlayerWeaponSlot(attacker, CS_SLOT_KNIFE);

		// inflictor should be the knife
		int inflictor = knife;

		// If the attacker no longer has a knife, clear attacker so ZR treats
		// this as a world/suicide kill instead of a human-triggered infection.
		if (knife == -1)
		{
			inflictor = attacker; // make inflictor the attacker himself if there is no knife
			attacker = 0;
		}

		// Set the boolean variable to true when the zombie is getting the damage to avoid duplicated knives...
		g_ZombieExplode[client] = true;
		SDKHooks_TakeDamage(client, inflictor, attacker, 999999.0, _, knife);
		g_ZombieExplode[client] = false;
	}

	return Plugin_Stop;
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_ZombieExplode[client] = false;
}

void ToggleSpecEnable(bool enable)
{
	if (!g_bEnabled)
		return;

	if (!g_bSpectate)
		return;

	if (!g_bSpectateHooked)
	{
		g_cvSpectate = FindConVar("sm_spec_enable");
		g_cvSpectate.AddChangeHook(OnConVarChanged);
		g_bSpectateHooked = true;
	}

	g_cvSpectate.IntValue = view_as<int>(enable);
	LogMessage("[KnifeMode] Changed cvar sm_spec_enable to %d.", enable);
}

stock int GetTeamAliveCount(int team)
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (IsPlayerAlive(i) && GetClientTeam(i) == team)
			count++;
	}

	return count;
}

void ToggleKnifeMode(bool enable)
{
	if (enable && !g_bEnabled)
	{
		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("player_hurt", Event_PlayerHurt);
		HookEvent("round_start", Event_RoundStart);
		LogMessage("[KnifeMode] Knife Mode enabled.");
	}
	else if (!enable && g_bEnabled)
	{
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_hurt", Event_PlayerHurt);
		UnhookEvent("round_start", Event_RoundStart);
		LogMessage("[KnifeMode] Knife Mode disabled.");
	}

	g_bEnabled = enable;

	SendForward();
}

stock void UnHookSpectate()
{
	g_bSpectate = false;
	if (g_bSpectateHooked)
	{
		g_cvSpectate.RemoveChangeHook(OnConVarChanged);
		delete g_cvSpectate;
		g_bSpectateHooked = false;
	}
}

stock void SendForward()
{
	Call_StartForward(g_fwdOnToggle);
	Call_PushCell(g_bEnabled);
	Call_Finish();
}
