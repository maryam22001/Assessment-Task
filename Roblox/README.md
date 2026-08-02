# Skyline Dash 3D (Roblox)

A simple Roblox platformer, in the same spirit as the "Skyline Dash" Pygame Zero project: a main menu, two kinds of patrolling enemies, coins, a win goal, lives, and sound — rebuilt for Roblox using Luau.

## Files

| File | Where it goes |
|---|---|
| `GameServer.lua` | a **Script**, goes in `ServerScriptService` |
| `GameClient.lua` | a **LocalScript**, goes in `StarterPlayerScripts` |
| `README.md` | this file |

Both scripts build everything else in code when the game starts — the level, platforms, coins, enemies, goal, menu, and HUD are all created automatically. You do not need to build anything by hand in the Workspace.

## How to set it up

1. Open Roblox Studio and create a new Baseplate place (or open an existing one — the scripts build their own ground/platforms, so it's fine either way).
2. In the Explorer window, find **ServerScriptService**.
   - Right-click it → Insert Object → **Script**.
   - Delete the default empty code inside, and paste in the full contents of `GameServer.lua`.
   - Rename the script to `GameServer` (optional, just for clarity).
3. In the Explorer window, find **StarterPlayer → StarterPlayerScripts**.
   - Right-click it → Insert Object → **LocalScript**.
   - Delete the default empty code inside, and paste in the full contents of `GameClient.lua`.
   - Rename it to `GameClient` (optional).
4. Click **Play** (or F5) to test in Studio.

## How to play

- **WASD** / arrow keys to move, **Space** to jump (Roblox's default character controls).
- Click **Start Game** on the menu to unfreeze your character and begin. Movement is locked until you press Start, same idea as the Pygame Zero version's main menu.
- **Sound: On/Off** toggles background music and sound effects.
- **Exit** disconnects you from the game session.
- Reach the green goal marker at the far end of the level to win.
- Two enemy types patrol fixed areas and must be avoided or jumped past:
  - a **red "Walker"** that paces back and forth along a platform
  - a **purple "Flyer"** that hovers up and down in a fixed vertical range

  Touching either costs a life (with a brief invulnerability window afterwards so hits don't stack instantly). Falling off the level also costs a life. 0 lives = Game Over; reaching the goal = Win. Either way you're returned to the start to try again.
- Small yellow spinning coins add to your Score (shown top-left, along with your Lives).

## What the scripts use

Only Roblox's own built-in services and API are used: `Players`, `ReplicatedStorage`, `RunService`, `Workspace`, TweenService-free procedural motion (plain math + Heartbeat), `Instance.new` for every part/GUI element, and `RemoteEvent`s for client/server communication. No external plugins, modules, or marketplace assets are required.

Enemy "sprite" animation (leg-swing while walking, a slight bob while idle at each end of their patrol, wing-flap for the flyer) is done procedurally with `math.sin()`-based motion each frame, rather than pre-made animation files — so there's nothing to import or upload for it to work. The player character uses Roblox's own default walk/jump/idle animations, which come bundled with every Roblox character automatically.

Sound effects/music reference sound files that ship with every Roblox client (`rbxasset://sounds/...`), so they don't depend on any uploaded audio assets either. If a particular one doesn't sound like you'd expect, feel free to swap the `SoundId` strings near the top of `GameClient.lua` for your own asset IDs from the Toolbox (Toolbox → Audio → right-click a sound → Copy Asset ID) — an invalid `SoundId` simply fails to play silently, it will not crash the game.

## A note on testing

Unlike the Python/Pygame Zero project, there's no Roblox engine available in the environment this was written in, so this couldn't be run and played end-to-end before handing it to you the way the Pygame Zero game was. What I did do:

- Ran every script through a real Lua syntax checker (`luac`) to catch typos/syntax errors ahead of time.
- Read through the logic carefully for correctness (win/lose conditions, respawn behavior, debounce timing, coordinate math for platforms and patrol ranges).

If something doesn't behave as expected the first time you press Play, check the **Output** window in Studio for the exact error line — that'll usually point straight at the issue, and I'm happy to help debug it from there.
