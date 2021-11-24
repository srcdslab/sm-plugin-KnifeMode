#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <multicolors>

#pragma semicolon 1

#define VERSION "2.3"

#define WEAPONS_MAX_LENGTH 32
#define DMG_GENERIC 0

new bool:g_ZombieExplode[MAXPLAYERS+1] = false;
new Handle:explodeTime;

public Plugin:myinfo =
{
    name = "[ZR] Knife Mode",
    author = "Franc1sco steam: franug, inGame, maxime1907, .Rushaway",
    description = "Kill zombies with knife",
    version = VERSION,
    url = ""
};

public OnPluginStart()
{
    CreateConVar("sm_knifemode_version", VERSION, "version", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_hurt", EnDamage);
    HookEvent("round_start", Event_RoundStart);

    explodeTime = CreateConVar("sm_knifemode_time", "3", "Seconds that a zombie has to catch any human");

    AutoExecConfig(true);
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

public IsValidClient( client ) 
{
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false;
    return true; 
}

public EnDamage(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (!IsValidClient(attacker))
		return;

	if (IsPlayerAlive(attacker))
	{
        new client = GetClientOfUserId(GetEventInt(event, "userid"));

        if(ZR_IsClientHuman(attacker) && ZR_IsClientZombie(client))
        {
            decl String:weapon[WEAPONS_MAX_LENGTH];
            GetEventString(event, "weapon", weapon, sizeof(weapon));

            if(StrEqual(weapon, "knife", false))
            {
                g_ZombieExplode[client] = true;

                if (GetEngineVersion() == Engine_CSGO)
                {
                    PrintHintText(client, "<font class='fontSize-l' color='#00ff00'>[Knife Mode]</font> <font class='fontSize-l'>You have %f seconds to catch any human or you will die!</font>", GetConVarFloat(explodeTime), attacker);
                    CPrintToChat(client, "{green}[Knife Mode] {gray}You have {red}%f seconds {gray}to catch any human {red}or you will die!", GetConVarFloat(explodeTime), attacker);
                }   
                else
                {
                    PrintCenterText(client, "[Knife Mode] You have %f seconds to catch any human or you will die!", GetConVarFloat(explodeTime), attacker);
                    CPrintToChat(client, "{green}[Knife Mode] {white}You have {red}%f seconds {white}to catch any human {red}or you will die!", GetConVarFloat(explodeTime), attacker);
                 }
                 
                new Handle:pack;
                CreateDataTimer(GetConVarFloat(explodeTime), ByeZM, pack);
                WritePackCell(pack, client);
                WritePackCell(pack, attacker);
            }
		}
	}
}

public Action:ZR_OnClientInfect(&client, &attacker, &bool:motherInfect, &bool:respawnOverride, &bool:respawn)
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

public Action:ByeZM(Handle:timer, Handle:pack)
{
    new client;
    new attacker;

    ResetPack(pack);
    client = ReadPackCell(pack);
    attacker = ReadPackCell(pack);

    if (IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client) && g_ZombieExplode[client])
    {
        g_ZombieExplode[client] = false;

        if (IsValidClient(attacker))
            DealDamage(client, 999999, attacker, DMG_GENERIC, "weapon_knife"); // enemy down ;)
        else
            ForcePlayerSuicide(client);
    }
}

public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_ZombieExplode[client] = false;
}

stock DealDamage(nClientVictim, nDamage, nClientAttacker = 0, nDamageType = DMG_GENERIC, String:sWeapon[] = "")
{
    if (nClientVictim > 0 &&
        IsValidEdict(nClientVictim) &&
        IsClientInGame(nClientVictim) &&
        IsPlayerAlive(nClientVictim) &&
        nDamage > 0)
    {
        new EntityPointHurt = CreateEntityByName("point_hurt");
        if(EntityPointHurt != 0)
        {
            new String:sDamage[16];
            IntToString(nDamage, sDamage, sizeof(sDamage));

            new String:sDamageType[32];
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
