# Copilot Instructions for SourcePawn KnifeMode Plugin

## Repository Overview

This repository contains a SourcePawn plugin for SourceMod called "KnifeMode" designed for Zombie Reloaded servers. The plugin allows human players to kill zombies using knife attacks, with a unique mechanic where knifed zombies have a limited time to infect a human or they will automatically die.

**Key Files:**
- `addons/sourcemod/scripting/KnifeMode.sp` - Main plugin source (360 lines)
- `addons/sourcemod/scripting/include/knifemode.inc` - Include file with forwards
- `sourceknight.yaml` - Build configuration
- `.github/workflows/ci.yml` - CI/CD pipeline

## Technical Environment

**Language & Platform:**
- SourcePawn (SourceMod scripting language)
- Target: SourceMod 1.11+ (legacy version, not latest 1.12+)
- Compiler: SourcePawn compiler via SourceKnight build system
- Games: Counter-Strike: Source, CS:GO (Source engine games)

**Dependencies:**
- SourceMod 1.11.0-git6934 (specified in sourceknight.yaml)
- MultiColors plugin (for colored chat messages)
- ZombieReloaded plugin (core game mode dependency)

**Build System:**
- SourceKnight build system (alternative to traditional spcomp)
- GitHub Actions for CI/CD with automatic releases
- Outputs compiled `.smx` files to `addons/sourcemod/plugins/`

## Code Style & Standards

**This codebase follows specific SourcePawn conventions:**

```sourcepawn
#pragma semicolon 1
#pragma newdecls required
```

**Variable Naming:**
- Global variables: `g_` prefix (e.g., `g_bEnabled`, `g_fExplodeTime`)
- ConVars: `g_cv` prefix (e.g., `g_cvEnabled`, `g_cvExplodeTime`)
- Use descriptive names: `g_ZombieExplode[MAXPLAYERS+1]` array for tracking state
- Boolean variables: `g_b` prefix (e.g., `g_bSpectate`, `g_bUnload`)

**Function Naming:**
- PascalCase for public functions: `OnPluginStart()`, `EnableKnifeMode()`
- camelCase for local variables and parameters
- Stock functions: descriptive names like `GetTeamAliveCount()`, `IsValidClient()`

**Memory Management:**
- Use `delete` for Handle cleanup (never check null before delete)
- DataPack usage: `new DataPack()` → write data → `delete pack`
- Timer handles are auto-managed by SourceMod

## Plugin-Specific Architecture

**Core Mechanics:**
1. **Knife Detection**: Hooks `player_hurt` event to detect knife attacks
2. **Timer System**: Uses DataPack + Timer for delayed zombie death
3. **State Tracking**: `g_ZombieExplode[]` array tracks which zombies are marked for death
4. **ConVar System**: Extensive configuration via ConVars with change hooks

**Event Flow:**
```
Human knifes zombie → player_hurt event → Timer started → Zombie has X seconds to infect someone → Timer expires → Zombie dies (or gets saved)
```

**Key Functions to Understand:**
- `EnDamage()` - Main knife detection logic
- `ByeZM()` - Timer callback for killing zombies
- `ZR_OnClientInfected()` - ZR forward to save knifed zombies
- `EnableKnifeMode()` - Toggle plugin functionality

## Development Guidelines

**When modifying this plugin:**

1. **Event Handling**: Always check `if (!g_bEnabled) return;` in event callbacks
2. **Client Validation**: Use `IsValidClient()` stock function before client operations
3. **Timer Safety**: Always use `TIMER_FLAG_NO_MAPCHANGE` for map transition safety
4. **Memory**: Use DataPack for complex timer data, always delete it
5. **ConVar Changes**: Hook ConVar changes and update global variables immediately

**Common Patterns:**
```sourcepawn
// Safe client check
if (!IsValidClient(client) || !IsPlayerAlive(client))
    return;

// Timer with data
DataPack pack = new DataPack();
pack.WriteCell(userid);
CreateTimer(time, Callback, pack, TIMER_FLAG_NO_MAPCHANGE);

// ConVar change handling
HookConVarChange(cvar, OnConVarChanged);
```

**Configuration System:**
- All convars created in `OnPluginStart()`
- Values cached in global variables for performance
- `AutoExecConfig(true)` generates default config file

## Testing & Validation

**No Unit Tests**: SourcePawn plugins typically don't have automated tests. Testing requires:

1. **Manual Server Testing**:
   - Load plugin on development server with ZombieReloaded
   - Test knife mechanics with multiple players
   - Verify timer functionality and edge cases

2. **Build Validation**:
   ```bash
   # Build using SourceKnight
   sourceknight build
   # Check for compilation errors
   ```

3. **Edge Cases to Test**:
   - Last zombie knife kill (g_bKillLastZM setting)
   - Attacker becomes zombie before timer expires (g_bTeamKill setting)  
   - Multiple simultaneous knife attacks
   - Map changes during active timers
   - Plugin reload scenarios

**Debugging:**
- Use `LogMessage()` for server console logging
- `PrintToServer()` for immediate console output
- Server console shows plugin load/unload status

## Integration Points

**External Plugin Dependencies:**
- **ZombieReloaded**: Uses `ZR_IsClientHuman()`, `ZR_IsClientZombie()`, `ZR_OnClientInfected()`
- **MultiColors**: Uses `CPrintToChat()`, `CPrintToChatAll()` for colored messages
- **Spectate**: Optional integration to disable spectate during knife mode

**Plugin Forwards:**
- Provides `KnifeMode_OnToggle(bool bEnabled)` forward for other plugins
- Other plugins can detect knife mode state changes

## Common Issues & Solutions

**Memory Leaks**: 
- Always `delete` DataPacks in timer callbacks
- Don't use `.Clear()` on StringMaps/ArrayLists (creates leaks)

**Timer Safety**:
- Use `TIMER_FLAG_NO_MAPCHANGE` for map transition safety
- Validate clients in timer callbacks (player may have disconnected)

**ConVar Synchronization**:
- Cache ConVar values in globals for performance
- Update cached values in change hooks immediately

**Client Validation**:
- Always validate client index bounds and connection state
- Check if client is alive before game-related operations

## Build Commands

```bash
# Local development build
sourceknight build

# Clean build artifacts
rm -rf .sourceknight/

# Check plugin syntax (if spcomp available)
spcomp -i include/ KnifeMode.sp
```

**CI/CD**: GitHub Actions automatically builds on push/PR and creates releases with compiled `.smx` files.

## File Structure Best Practices

When making changes:
- Plugin source: `addons/sourcemod/scripting/KnifeMode.sp`
- Include files: `addons/sourcemod/scripting/include/`
- Never commit `.smx` files (they're build artifacts)
- Configuration files would go in `addons/sourcemod/configs/` (none currently)
- Translation files would go in `addons/sourcemod/translations/` (none currently)

## Version Management

- Plugin version defined in `myinfo` struct: currently "2.7.4"
- Follow semantic versioning for changes
- Update version in plugin source when making functional changes
- CI automatically creates GitHub releases from tags