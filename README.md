# O.O.P.S

**Obstacle-Oriented Punishment System** — consent-based hard modes for groups that think Mythic+ is too easy.

Pick a set of *obstacles* (self-imposed handicaps), propose them to your group, and run your keystone while every death cranks up a shared, escalating *punishment level* that makes the obstacles worse for everyone. Fully visible, fully opt-in, fully compliant with Midnight (12.0).

## How it works

1. Type `/oops` to open the control panel.
2. Tick the obstacles you want and pick an intensity (**Mild**, **Spicy**, or **Brutal**).
3. Hit **Start (Solo)** to suffer alone, or **Propose to Group** to invite your party — each member with O.O.P.S installed gets an Accept/Decline popup. Nothing is ever forced on anyone.
4. Every time a group member dies, the **punishment level** rises for the whole group: the screen flashes, a warning plays, and level-scaling obstacles (like Tunnel Vision) get harsher.
5. Finish the keystone for a victory summary, or `/oops stop` to end the run.

## Obstacles

| Obstacle | Effect |
| --- | --- |
| **Tunnel Vision** | A dark vignette closes in around your screen and thickens with every group death |
| **Claustrophobia** | Your camera is locked into first person |
| **No Cartographer** | Your minimap is gone — navigate from memory |
| **Flying Blind** | Enemy nameplates are disabled |
| **Deafened** | All game audio is muted — no boss yells, no cast warnings |

## Mythic+ integration

- **Arm for keystone**: optional setting that auto-starts your selected obstacles the moment a Mythic+ run begins.
- **Completion summary**: finishing a keystone under hard mode prints your deaths and final punishment level, and counts toward your lifetime stats.
- **No escape hatch**: by default, `/reload` does not disable an active hard mode (toggleable in options). `/oops stop` is the honest way out.

## Design notes (and how it differs from a prank addon)

O.O.P.S grew out of B.O.L.T's hidden "hardcore mode" prank module, redesigned as a proper, honest hard-mode framework:

- **Visible, not hidden**: a real control panel and options category instead of secret chat trigger words.
- **Consent-based**: group activation uses an explicit Accept/Decline popup; members can bail out at any time (the addon will judge you, but it will let you).
- **Midnight-proof sync**: group coordination uses addon messages, which keep working inside instances where 12.0 turns player chat into unreadable Secret Values.
- **Never unplayable**: effects are capped (the vignette never fully covers the screen) and overlays are always click-through.
- **Always recoverable**: every CVar an obstacle touches is backed up to saved variables and restored even after a crash, and `/oopsreset` instantly undoes everything, no questions asked.

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/oops) or the GitHub releases
2. Place the `OOPS` folder in your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or type `/reload`

## Console commands

- `/oops` — Toggle the control panel
- `/oops start` — Start a hard mode with your selected obstacles
- `/oops stop` — Stop the current hard mode (stops the whole group if you started it)
- `/oops status` — Show the current run status
- `/oops options` — Open the options panel (also under ESC > Options > AddOns > O.O.P.S)
- `/oops reset` or `/oopsreset` — Emergency reset of all effects

## Releasing (maintainers)

Every push to `main` automatically versions, tags, changelogs and releases the addon, then uploads the package to CurseForge:

- The commit message becomes the changelog entry (one bullet per line).
- Add `[major]` to the commit message to bump the major version, `[skip release]` to skip releasing.
- CurseForge uploads require the `CF_API_KEY` repository secret and an `X-Curse-Project-ID` in `OOPS.toc`; without them the zip is still attached to the GitHub release.
