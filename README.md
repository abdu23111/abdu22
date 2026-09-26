# abdu22

Roblox game synced into Studio with [Rojo](https://rojo.space).

## Setup (once)

1. Install Rojo: `aftman install` (uses `aftman.toml`), or download it from https://github.com/rojo-rbx/rojo/releases
2. In Roblox Studio, install the **Rojo** plugin from the Creator Store.

## Sync into Studio

```sh
git pull
rojo serve
```

In Studio, open the Rojo plugin and click **Connect**. Code in `src/` now live-syncs into your place.

## Layout

| Folder        | Goes to in Studio                               |
| ------------- | ----------------------------------------------- |
| `src/server`  | `ServerScriptService.Server`                    |
| `src/client`  | `StarterPlayer.StarterPlayerScripts.Client`     |
| `src/shared`  | `ReplicatedStorage.Shared`                      |

File suffixes: `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript.
