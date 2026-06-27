# FBLA Roblox Game - Career Exploration

A Roblox career exploration game for FBLA, set up with Rojo for Cursor ↔ Studio sync.

## What Syncs via Rojo

| Location | Syncs? | Notes |
|----------|--------|-------|
| ServerScriptService | ✅ Yes | All server scripts |
| StarterPlayerScripts | ✅ Yes | BootLoading, FirstPersonCamera |
| StarterGui | ❌ No | UI elements + scripts stay in Studio |
| ReplicatedFirst | ❌ No | LoadingGui stays in Studio |
| Workspace | ❌ No | Models, parts, object scripts stay in Studio |

## Project Structure

```
FBLAROBLOXGAME/
├── src/
│   ├── server/                    # → Syncs to ServerScriptService
│   │   ├── StartGame.server.luau
│   │   ├── TeleportToWorld.server.luau
│   │   └── Settings.server.luau
│   ├── client/                    # → Syncs to StarterPlayerScripts
│   │   ├── BootLoading.client.luau
│   │   └── FirstPersonCamera.client.luau
│   ├── gui/                       # Reference copies (edit in Studio)
│   │   ├── MainMenuGui/
│   │   │   └── Menu.client.luau
│   │   └── LoadingScreenGui/
│   │       └── Loading.client.luau
│   └── shared/                    # → Syncs to ReplicatedStorage.Shared
├── default.project.json
└── FBLArobloxgamereal.rbxlx       # Original backup
```

## Quick Start

### 1. Start Rojo Server
```bash
cd ~/Desktop/FBLAROBLOXGAME
rojo serve
```

### 2. Connect in Studio
1. Open your game in Roblox Studio
2. Click **Plugins → Rojo → Connect**
3. Server and client scripts will sync!

### 3. Edit in Cursor
- Edit files in `src/server/` or `src/client/`
- Save → Changes appear in Studio instantly
- Press Play in Studio to test

## Scripts That Sync

**Server Scripts** (in Cursor → syncs to Studio):
- `StartGame.server.luau` - Play button handler
- `TeleportToWorld.server.luau` - World teleportation
- `Settings.server.luau` - Player settings DataStore

**Client Scripts** (in Cursor → syncs to Studio):
- `BootLoading.client.luau` - Loading screen logic
- `FirstPersonCamera.client.luau` - Camera and body visibility

## Scripts That DON'T Sync (Edit in Studio)

**GUI Scripts** (stay in Studio):
- `Menu.client.lua` - Main menu (inside MainMenuGui)
- `Loading.client.lua` - Loading screen (inside LoadingGui)

These are inside ScreenGuis with complex UI hierarchies. Edit them directly in Studio, or copy changes from the `src/gui/` reference files.

## Your Game's Important Elements

### Workspace
- CareerZones, MenuSpawn, HubSpawn
- Rig, Warnet Thing, Baseplate

### ReplicatedStorage (RemoteEvents)
- StartGame, TeleportToWorld
- SettingsGet, SettingsSet
- ViewmodelArms

### StarterGui (UI)
- MainMenuGui (Menu.client.lua + all UI elements)

### ReplicatedFirst
- LoadingGui (Loading.client.lua + Frame + StatusLabel)

## Troubleshooting

**Scripts appearing in wrong places?**
- Disconnect Rojo, delete duplicate scripts in Studio, reconnect

**GUI scripts not updating?**
- GUI scripts don't sync via Rojo - edit them in Studio directly

**Extra folders appearing?**
- Check default.project.json mappings
