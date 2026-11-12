# Mod Template

Copy this folder, give it a new name and edit `_polymod_meta.json` to start a new Shark mod.

## Structure

```
modTemplate/
├── _polymod_meta.json   Mod name, description, authors and versions
├── _polymod_icon.png    Optional 64x64 icon shown for the mod
├── assets/              Files here replace the game's own assets with the same path
│   ├── images/          e.g. assets/images/icon.png replaces the app icon image
│   └── data/            e.g. assets/data/... replaces data files
└── scripts/             HScript (.hxs) files loaded on startup
    └── main.hxs
```

## Metadata

- `api_version` must match the mod API the app is built with (currently `0.3.0`), otherwise the mod is skipped.
- `mod_version` is your own version number.

## Assets

Shark loads mods with Polymod. Any file placed under `assets/` in this folder overrides the file with the same path in the game, so you only include what you want to change.

## Scripts

Every `.hxs` file inside `scripts/` is loaded when the app starts. Define any of these functions to react to events:

| Hook | When it runs |
|---|---|
| `onCreate()` | The script was loaded |
| `onUpdate(elapsed)` | Every frame |
| `onMessageSent(message)` | The user sent a chat message |
| `onReplyReceived(reply)` | Shark replied |
| `onImageGenerated()` | An image was generated |
| `onError(error)` | A chat request failed |
| `onThinkingStart()` / `onThinkingEnd()` | Shark started or stopped thinking |
| `onNavigate(destination)` | The app is about to change screen |
| `onStateChanged(stateName)` | The current screen changed |
| `onLanguageChanged(languageCode)` | The language changed |
| `onIntroStart()` / `onIntroSkip()` / `onIntroComplete()` | Intro screen events |

Scripts can call `logInfo`, `logWarning`, `playSound`, `muteAudio`, `unmuteAudio`, `sendMessage`, `registerCommand`, `generateImage`, `vibrate`, `getStorage`, `setStorage`, `bodyIdle`, `bodyThink`, `bodyTalk`, `bodyReact`, `isOnline`, `isApiOnline`, `getMessageCount`, `getImageCount` and read `modName`, `buildVersion`, `apiVersion` and `isSafeMode`.
