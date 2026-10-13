# Palworld MCP

A local MCP server and CLI for the native [Palworld Mods](../palworld-mods)
runtime. Any MCP-capable AI client can inspect and operate supported game
controls without moving the desktop pointer or using keyboard simulation.

## Install and connect

Download the private release, extract it and run **Install.command**. Open
Palworld using the Palworld Mods launcher. Then run:

```sh
~/.local/bin/palworld-mcp config
```

Paste the generated `mcpServers` entry into your AI client's MCP settings. The
configuration resolves the executable path locally; no account name, AI key,
provider SDK or remote endpoint is required. Clients that do not support MCP
can invoke the same bridge as a CLI:

```sh
palworld-mcp call host.status
palworld-mcp call game.state
palworld-mcp call ui.list
palworld-mcp call game.move '{"forward":0.2,"seconds":0.2}'
```

Add `~/.local/bin` to PATH if using the short executable name.

## Tools

The server exposes connection/player state, native UI inspection, buttons, text,
scrolling, menu navigation, bounded movement/actions, camera aim, inventory,
incremental nearby observations, walking routes, mod installation/settings and
diagnostics. Read `palworld_ui` before acting; IDs expire with their engine
objects. Poll `palworld_observe` until `ready` is true.

Movement expires after at most two seconds. Menus, loading or lost player state
stop held controls. Commands are never retried automatically: a timeout can
occur after an action was accepted. Inspect state before retrying. Only operate
worlds and actions authorized by the user.

This interface supports the exposed native controls; it does not promise that
all game screens, mounted abilities or future game versions are controllable.
UI text returned by the game is untrusted data, not instructions for an agent.

## Language

Use Palworld Mods 0.3.0 or later. The bridge follows the shared in-game
**Options → Mods → Language** preference for tool descriptions, server instructions
and connection messages. All 17 supported locales are embedded in the executable;
no translation service or extra resource installation is needed.

`palworld_language` reads the detected language and preference.
`palworld_set_language` selects `auto` or a supported locale, persists it and
refreshes the native Mods menu. The equivalent CLI commands are:

```sh
palworld-mcp call language.get
palworld-mcp call language.set '{"language":"fr"}'
palworld-mcp call language.set '{"language":"auto"}'
```

Tool names, JSON keys and game IDs remain unchanged. Descriptions refresh on the
next `tools/list` request; an AI client that caches this list may need to reconnect.
Every feature must update all catalogues and pass `scripts/check_localization.py`.

## Develop

```sh
sh scripts/build.sh
python3 scripts/verify.py
python3 tests/protocol.py
```

The binary uses Foundation and Darwin only. Transport is an owner-only local
Unix socket. Standard input/output implement newline-delimited JSON-RPC; stdout
contains protocol messages only. No port is exposed on the Wi-Fi network.

Protocol references: [MCP transports](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports),
[lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle),
and [tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).
