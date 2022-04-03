#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

#define VERSION "2.5.2"

#define WEAPONS_MAX_LENGTH 32
#define DMG_GENERIC 0

bool g_ZombieExplode[MAXPLAYERS+1] = false;

ConVar g_explodeTime;
ConVar g_cvSpectate;

public Plugin myinfo =
{
    name = "[ZR] Knife Mode",
    author = "Franc1sco steam: franug, inGame, maxime1907, .Rushaway",
    description = "Kill zombies with knife",
    version = VERSION,
    url = ""
}

public void OnPluginStart()
{
    g_explodeTime = CreateConVar("sm_knifemode_time", "3", "Seconds that a zombie has to catch any human");

    g_cvSpectate = FindConVar("sm_spec_enable");
    g_cvSpectate.AddChangeHook(OnConVarChanged);

    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_hurt", EnDamage);
    HookEvent("round_start", Event_RoundStart);

    AutoExecConfig(true);
}

public void OnAllPluginsLoaded()
{
    if (!LibraryExists("Spectate"))
	{
	   	LogError("[KnifeMode] Spectate plugin is required or not loaded. Can't change sm_spec_enable to 0.");
    }
    else
    {
        DisableSpec();
        LogMessage("[KnifeMode] Changed cvar sm_spec_enable to 0.");
    }
}

public void OnMapEnd()
{
    g_cvSpectate.IntValue = 1;
    LogMessage("[KnifeMode] Map Ended... Changed cvar sm_spec_enable to .");
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvSpectate)
    {
        if(g_cvSpectate.IntValue != 0)
		{
			DisableSpec();
		}
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (GetEngineVersion() == Engine_CSGO)
    {
        CPrintToChatAll("{green}[Knife Mode] {darkred}You can use your knife to kill Zombies!");
    }
    else
    {
        CPrintToChatAll("{fullred}[Knife Mode] {white}You can use your knife to kill Zombies!");
    }
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
                g_ZombieExplode[client] = true;

                if (GetEngineVersion() == Engine_CSGO)
                {
                    PrintHintText(client, "<font class='fontSize-l' color='#00ff00'>[Knife Mode]</font> <font class='fontSize-l'>You have %f seconds to catch any human or you will die!</font>", GetConVarFloat(g_explodeTime), attacker);
                    CPrintToChat(client, "{green}[Knife Mode] {gray}You have {red}%f seconds {gray}to catch any human {red}or you will die!", GetConVarFloat(g_explodeTime), attacker);
                }   
                else
                {
                    PrintCenterText(client, "[Knife Mode] You have %f seconds to catch any human or you will die!", GetConVarFloat(g_explodeTime), attacker);
                    CPrintToChat(client, "{green}[Knife Mode] {white}You have {red}%f seconds {white}to catch any human {red}or you will die!", GetConVarFloat(g_explodeTime), attacker);
                 }
                 
                Handle pack;
                CreateDataTimer(GetConVarFloat(g_explodeTime), ByeZM, pack);
                WritePackCell(pack, client);
                WritePackCell(pack, attacker);
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
    int client;
    int attacker;

    ResetPack(pack);
    client = ReadPackCell(pack);
    attacker = ReadPackCell(pack);

    if (IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client) && g_ZombieExplode[client])
    {
        g_ZombieExplode[client] = false;

        if (IsValidClient(attacker))
        {
            DealDamage(client, 999999, attacker, DMG_GENERIC, "weapon_knife"); // enemy down ;)
        }
        else
        {
            ForcePlayerSuicide(client);
        }
    }
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

            DispatchKeyValue(nClientVictim,			"targetname",		"war3_hurtme");
            DispatchKeyValue(EntityPointHurt,		"DamageTarget",	"war3_hurtme");
            DispatchKeyValue(EntityPointHurt,		"Damage",				sDamage);
            DispatchKeyValue(EntityPointHurt,		"DamageType",		sDamageType);
            if (!StrEqual(sWeapon, ""))
                DispatchKeyValue(EntityPointHurt,	"classname",		sWeapon);
            DispatchSpawn(EntityPointHurt);
            AcceptEntityInput(EntityPointHurt,	"Hurt",					(nClientAttacker != 0) ? nClientAttacker : -1);
            DispatchKeyValue(EntityPointHurt,		"classname",		"point_hurt");
            DispatchKeyValue(nClientVictim,			"targetname",		"war3_donthurtme");

            RemoveEdict(EntityPointHurt);
        }
    }
}

void DisableSpec()
{
    g_cvSpectate.IntValue = 0;
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}