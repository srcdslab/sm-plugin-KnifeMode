#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <multicolors>

#define WEAPONS_MAX_LENGTH 32
#define DMG_GENERIC 0 // https://developer.valvesoftware.com/wiki/Damage_types

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
Handle g_fwdOnToggle;

public Plugin myinfo =
{
	name = "[ZR] Knife Mode",
	author = "Franc1sco steam: franug, inGame, maxime1907, .Rushaway",
	description = "Kill zombies with knife",
	version = "2.7.1",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("KnifeMode");
	g_fwdOnToggle = CreateGlobalForward("KnifeMode_OnToggle", ET_Ignore, Param_Cell);
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


	HookConVarChange(g_cvEnabled, OnConVarChanged);
	HookConVarChange(g_cvExplodeTime, OnConVarChanged);
	HookConVarChange(g_cvUnload, OnConVarChanged);
	HookConVarChange(g_cvSpectateDisable, OnConVarChanged);
	HookConVarChange(g_cvKillLastZM, OnConVarChanged);
	HookConVarChange(g_cvTeamKill, OnConVarChanged);

	g_bEnabled = g_cvEnabled.BoolValue;
	g_fExplodeTime = g_cvExplodeTime.FloatValue;
	g_bUnload = g_cvUnload.BoolValue;
	g_bSpectateDisable = g_cvSpectateDisable.BoolValue;
	g_bKillLastZM = g_cvKillLastZM.BoolValue;
	g_bTeamKill = g_cvTeamKill.BoolValue;

	if (g_bEnabled)
	{
		HookEvent("player_spawn", PlayerSpawn);
		HookEvent("player_hurt", EnDamage);
		HookEvent("round_start", Event_RoundStart);
	}

	AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
	g_bSpectate = LibraryExists("Spectate");
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
	{
		g_cvEnabled.SetInt(0);
		LogMessage("[KnifeMode] Disabling Knife Mode (setting enabled cvar to 0)...");
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{

	if (convar == g_cvEnabled)
		EnableKnifeMode(g_cvEnabled.BoolValue);
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

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;

	CPrintToChatAll("{fullred}[Knife Mode] {white}You can use your knife to kill Zombies!");
}

public void EnDamage(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;

	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (!IsValidClient(attacker) || !IsPlayerAlive(attacker))
		return;
		
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (ZR_IsClientHuman(attacker) && ZR_IsClientZombie(client))
	{
		char weapon[WEAPONS_MAX_LENGTH];
		GetEventString(event, "weapon", weapon, sizeof(weapon));

		if (strcmp(weapon, "knife", false) != 0 || g_ZombieExplode[client] || (!g_bKillLastZM && GetTeamAliveCount(CS_TEAM_T) <= 1))
			return;

		DataPack pack = new DataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, attacker);
		CreateTimer(g_fExplodeTime, ByeZM, pack, TIMER_FLAG_NO_MAPCHANGE);

		PrintCenterText(client, "[Knife Mode] You have %0.1f seconds to catch any human or you will die!", g_fExplodeTime, attacker);
		CPrintToChat(client, "{green}[Knife Mode] {white}You have {red}%0.1f seconds {white}to catch any human {red}or you will die!", g_fExplodeTime, attacker);

		g_ZombieExplode[client] = true;
	}
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
	if (!g_bEnabled)
		return Plugin_Continue;

	if (!IsValidClient(attacker) || !g_ZombieExplode[attacker])
		return Plugin_Continue;

	g_ZombieExplode[attacker] = false;

	PrintCenterText(attacker, "[Knife Mode] You have caught a human, you are saved!");
	CPrintToChat(attacker, "{green}[Knife Mode] {white}You have caught a human, you are saved!");
	return Plugin_Continue;
}

public Action ByeZM(Handle timer, DataPack pack)
{
	if (!g_bEnabled)
	{
		delete pack;
		return Plugin_Stop;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int attacker = ReadPackCell(pack);
	delete pack;

	if (!IsValidClient(client))
		return Plugin_Stop;

	// Another check : In case 2 different pack is in progress for differents clients
	if (!g_bKillLastZM && GetTeamAliveCount(CS_TEAM_T) <= 1)
	{
		PrintCenterText(client, "[Knife Mode] You are the last Zombie alive, canceling your death!");
		CPrintToChat(client, "{green}[Knife Mode] {white}You are the last Zombie alive, canceling your death!");
		return Plugin_Stop;
	}
	else if (!g_bTeamKill && (!IsValidClient(attacker) || !IsPlayerAlive(attacker) || ZR_IsClientZombie(attacker)))
	{
		PrintCenterText(client, "[Knife Mode] Attacker is no longer human, you are saved!");
		CPrintToChat(client, "{green}[Knife Mode] {white}Attacker is no longer human, you are saved!");
		return Plugin_Stop;
	}

	if (IsPlayerAlive(client) && ZR_IsClientZombie(client) && g_ZombieExplode[client])
	{
		if (IsValidClient(attacker))
			DealDamage(client, 999999, attacker, DMG_GENERIC, "weapon_knife"); // enemy down ;)
		else
			ForcePlayerSuicide(client);
	}
	return Plugin_Stop;
}

public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	if (!g_bEnabled)
		return;

	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_ZombieExplode[client] = false;
}

stock Action DealDamage(int nClientVictim, int nDamage, int nClientAttacker = 0, int nDamageType = DMG_GENERIC, char [] sWeapon = "")
{
	if (nClientVictim > 0 && IsValidEdict(nClientVictim) && IsClientInGame(nClientVictim) && IsPlayerAlive(nClientVictim) && nDamage > 0)
	{
		int EntityPointHurt = CreateEntityByName("point_hurt");
		if (EntityPointHurt != 0)
		{
			char sDamage[16];
			IntToString(nDamage, sDamage, sizeof(sDamage));

			char sDamageType[32];
			IntToString(nDamageType, sDamageType, sizeof(sDamageType));

			DispatchKeyValue(nClientVictim,			"targetname",		"war3_hurtme");
			DispatchKeyValue(EntityPointHurt,		"DamageTarget",		"war3_hurtme");
			DispatchKeyValue(EntityPointHurt,		"Damage",		sDamage);
			DispatchKeyValue(EntityPointHurt,		"DamageType",		sDamageType);
			if (!StrEqual(sWeapon, ""))
				DispatchKeyValue(EntityPointHurt,	"classname",		sWeapon);
			DispatchSpawn(EntityPointHurt);
			AcceptEntityInput(EntityPointHurt,		"Hurt",			(nClientAttacker != 0) ? nClientAttacker : -1);
			DispatchKeyValue(EntityPointHurt,		"classname",		"point_hurt");
			DispatchKeyValue(nClientVictim,			"targetname",		"war3_donthurtme");

			RemoveEdict(EntityPointHurt);
		}
	}
	return Plugin_Continue;
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

bool IsValidClient(int client, bool nobots = false)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
		return false;

	return IsClientInGame(client);
}

void EnableKnifeMode(bool enable)
{
	if (enable && !g_bEnabled)
	{
		HookEvent("player_spawn", PlayerSpawn);
		HookEvent("player_hurt", EnDamage);
		HookEvent("round_start", Event_RoundStart);
		LogMessage("[KnifeMode] Knife Mode enabled.");
	}
	else if (!enable && g_bEnabled)
	{
		UnhookEvent("player_spawn", PlayerSpawn);
		UnhookEvent("player_hurt", EnDamage);
		UnhookEvent("round_start", Event_RoundStart);
		LogMessage("[KnifeMode] Knife Mode disabled.");
	}
	g_bEnabled = enable;

	if (g_fwdOnToggle != null)
	{
		Call_StartForward(g_fwdOnToggle);
		Call_PushCell(g_bEnabled);
		Call_Finish();
	}
}

stock void UnHookSpectate()
{
	g_bSpectate = false;
	if (g_bSpectateHooked)
	{
		g_cvSpectate.RemoveChangeHook(OnConVarChanged);
		g_cvSpectate = null;
		g_bSpectateHooked = false;
	}
}
