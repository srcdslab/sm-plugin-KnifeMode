#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <multicolors>

#define WEAPONS_MAX_LENGTH 32
#define DMG_GENERIC 0

bool    g_bSpectate = false,
        g_bSpectateHooked = false,
        g_ZombieExplode[MAXPLAYERS+1] = { false, ... };

ConVar  g_cvExplodeTime, 
        g_cvSpectateDisable, 
        g_cvUnload,
        g_cvKillLastZM,
        g_cvSpectate = null;

public Plugin myinfo =
{
    name = "[ZR] Knife Mode",
    author = "Franc1sco steam: franug, inGame, maxime1907, .Rushaway",
    description = "Kill zombies with knife",
    version = "2.6.3",
    url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("KnifeMode");
	return APLRes_Success;
}

public void OnPluginStart()
{
    g_cvExplodeTime = CreateConVar("sm_knifemode_time", "3", "Seconds that a zombie has to catch any human");
    g_cvUnload = CreateConVar("sm_knifemode_unload", "0", "Automaticaly unload plugin on map end [0 = No | 1 = Yes, unload it.]");
    g_cvSpectateDisable = CreateConVar("sm_knifemode_spectate_disable", "0", "Automaticaly disable the spectate plugin on map start [0 = No | 1 = Yes, disable it.]");
    g_cvKillLastZM = CreateConVar("sm_knifemode_kill_lastzm", "0", "Allow last zombie alive to be killed by a knife ? [0 = No | 1 = Yes, kill it.]");

    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_hurt", EnDamage);
    HookEvent("round_start", Event_RoundStart);

    AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
    g_bSpectate = LibraryExists("Spectate");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "Spectate"))
    {
        g_bSpectate = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "Spectate"))
    {
        g_bSpectate = false;
        if (g_bSpectateHooked)
        {
            g_cvSpectate.RemoveChangeHook(OnConVarChanged);
            g_cvSpectate = null;
            g_bSpectateHooked = false;
        }
    }
}

public void OnConfigsExecuted()
{
    if (g_cvSpectateDisable.BoolValue)
        ToggleSpecEnable(false);
}

public void OnMapEnd()
{
    if (g_cvUnload.BoolValue)
    {
        char sFilename[256];
        GetPluginFilename(INVALID_HANDLE, sFilename, sizeof(sFilename));
        ServerCommand("sm plugins unload %s", sFilename);
    }

    if (g_cvSpectateDisable.BoolValue)
        ToggleSpecEnable(true);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvSpectate && g_cvSpectateDisable.BoolValue && g_cvSpectate.BoolValue)
    {
        ToggleSpecEnable(false);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (GetEngineVersion() == Engine_CSGO)
        CPrintToChatAll("{green}[Knife Mode] {darkred}You can use your knife to kill Zombies!");
    else
        CPrintToChatAll("{fullred}[Knife Mode] {white}You can use your knife to kill Zombies!");
}

public void EnDamage(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    
    if (!IsValidClient(attacker))
        return;
        
    if (IsPlayerAlive(attacker))
    {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));

        if(ZR_IsClientHuman(attacker) && ZR_IsClientZombie(client))
        {
            char weapon[WEAPONS_MAX_LENGTH];
            GetEventString(event, "weapon", weapon, sizeof(weapon));

            if(StrEqual(weapon, "knife", false))
            {
                if (!g_ZombieExplode[client])
                {
                    if (g_cvKillLastZM.IntValue == 0 && GetTeamAliveCount(2) <= 1) // don't create useless timer
                        return;

                    Handle pack;
                    CreateDataTimer(GetConVarFloat(g_cvExplodeTime), ByeZM, pack);
                    WritePackCell(pack, client);
                    WritePackCell(pack, attacker);

                    if (GetEngineVersion() == Engine_CSGO)
                    {
                        PrintHintText(client, "<font class='fontSize-l' color='#00ff00'>[Knife Mode]</font> <font class='fontSize-l'>You have %0.1f seconds to catch any human or you will die!</font>", GetConVarFloat(g_cvExplodeTime), attacker);
                        CPrintToChat(client, "{green}[Knife Mode] {gray}You have {red}%0.1f seconds {gray}to catch any human {red}or you will die!", GetConVarFloat(g_cvExplodeTime), attacker);
                    }   
                    else
                    {
                        PrintCenterText(client, "[Knife Mode] You have %0.1f seconds to catch any human or you will die!", GetConVarFloat(g_cvExplodeTime), attacker);
                        CPrintToChat(client, "{green}[Knife Mode] {white}You have {red}%0.1f seconds {white}to catch any human {red}or you will die!", GetConVarFloat(g_cvExplodeTime), attacker);
                    }

                    g_ZombieExplode[client] = true;
                }
            }
        }
    }
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn)
{
    if (!IsValidClient(attacker))
        return Plugin_Continue;

    if (g_ZombieExplode[attacker])
    {
        g_ZombieExplode[attacker] = false;
        if (GetEngineVersion() == Engine_CSGO)
        {
            PrintHintText(attacker, "<font class='fontSize-l' color='#00ff00'>[Knife Mode]</font> <font class='fontSize-l'>You have caught a human, you are saved!</font>");
            CPrintToChat(attacker, "{green}[Knife Mode] {gray}You have caught a human, you are saved!");
        }
        else
        {
            PrintCenterText(attacker, "[Knife Mode] You have caught a human, you are saved!");
            CPrintToChat(attacker, "{green}[Knife Mode] {white}You have caught a human, you are saved!");
        }
    }
    return Plugin_Continue;
}

public Action ByeZM(Handle timer, Handle pack)
{
    ResetPack(pack);
    int client = ReadPackCell(pack);
    int attacker = ReadPackCell(pack);

    // Another check : In case 2 different pack is in progress for differents clients
    if (g_cvKillLastZM.IntValue == 0 && GetTeamAliveCount(2) <= 1)
    {
        if (GetEngineVersion() == Engine_CSGO)
        {
            PrintHintText(client, "<font class='fontSize-l' color='#00ff00'>[Knife Mode]</font> <font class='fontSize-l'>You are the last Zombie alive, canceling your die!</font>");
            CPrintToChat(client, "{green}[Knife Mode] {gray}You are the last Zombie alive, canceling your die!");
        }
        else
        {
            PrintCenterText(client, "[Knife Mode] You are the last Zombie alive, canceling your die!");
            CPrintToChat(client, "{green}[Knife Mode] {white}You are the last Zombie alive, canceling your die!");
        }
        return Plugin_Stop;
    }

    if (IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client) && g_ZombieExplode[client])
    {
        if (IsValidClient(attacker))
            DealDamage(client, 999999, attacker, DMG_GENERIC, "weapon_knife"); // enemy down ;)
        else
            ForcePlayerSuicide(client);
    }
    return Plugin_Continue;
}

public void PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_ZombieExplode[client] = false;
}

stock Action DealDamage(int nClientVictim, int nDamage, int nClientAttacker = 0, int nDamageType = DMG_GENERIC, char [] sWeapon = "")
{
    if (nClientVictim > 0 &&
        IsValidEdict(nClientVictim) &&
        IsClientInGame(nClientVictim) &&
        IsPlayerAlive(nClientVictim) &&
        nDamage > 0)
    {
        int EntityPointHurt = CreateEntityByName("point_hurt");
        if(EntityPointHurt != 0)
        {
            char sDamage[16];
            IntToString(nDamage, sDamage, sizeof(sDamage));

            char sDamageType[32];
            IntToString(nDamageType, sDamageType, sizeof(sDamageType));

            DispatchKeyValue(nClientVictim,	        "targetname",		"war3_hurtme");
            DispatchKeyValue(EntityPointHurt,		"DamageTarget",		"war3_hurtme");
            DispatchKeyValue(EntityPointHurt,		"Damage",		sDamage);
            DispatchKeyValue(EntityPointHurt,		"DamageType",		sDamageType);
            if (!StrEqual(sWeapon, ""))
                DispatchKeyValue(EntityPointHurt,	"classname",		sWeapon);
            DispatchSpawn(EntityPointHurt);
            AcceptEntityInput(EntityPointHurt,		"Hurt",			(nClientAttacker != 0) ? nClientAttacker : -1);
            DispatchKeyValue(EntityPointHurt,		"classname",		"point_hurt");
            DispatchKeyValue(nClientVictim,	        "targetname",		"war3_donthurtme");

            RemoveEdict(EntityPointHurt);
        }
    }
    return Plugin_Continue;
}

void ToggleSpecEnable(bool enable)
{
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
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
		if(IsPlayerAlive(i) && GetClientTeam(i) == team)
			count++;
	}
	return count;
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
