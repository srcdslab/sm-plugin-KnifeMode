#if defined _KnifeMode_Included
    #endinput
#endif
#define _KnifeMode_Included

/**
 * Called when KnifeMode is toggled
 * 
 * @param bEnabled true if enabled, false otherwise
 */
forward void KnifeMode_OnToggle(bool bEnabled);

public SharedPlugin __pl_KnifeMode =
{
    name = "KnifeMode",
    file = "KnifeMode.smx",
    #if defined REQUIRE_PLUGIN
    required = 1
    #else
    required = 0
    #endif
}; 