# Chiip — Game Design Document

> Living document: it changes as the game is built and playtested. Values marked *(tune)* are starting points, not final numbers.
>
> Last updated: 2026-10-16

## 1. Pitch

Chiip is a single-player tactical first-person shooter in the spirit of Counter-Strike. You fight rounds against bots with precise, learnable gunplay, in a chunky, pixelated world that looks like a 1996 Quake-era shooter.

## 2. Design pillars

Every feature should support at least one pillar. If it doesn't, it goes to the backlog.

1. **Gunplay you can master.** Accuracy is earned by stopping before you shoot, controlling the spray and aiming at heads. Skill from CS should carry over.
2. **Every round matters.** You get one life per round, money carries between rounds, and you decide when to buy and when to save.
3. **Readable retro look.** Low-res and pixelated, but enemies are always clearly visible. Clarity beats detail.
4. **Fair bots.** Bots react with human-like delay, miss sometimes and never see through walls.

## 3. Core loop

Buy or save during freeze time → play the round (move, hold angles, fight, take guns off the floor, plant or defuse) → round ends → earn money → next round, with a fresh loadout.

A match is won by the first team to win a set number of rounds.

## 4. Mechanics

### 4.1 Movement

Movement is based on Counter-Strike, which inherited it from Quake: you accelerate and slow down with friction on the ground, and have limited control in the air.

| State | Speed (Source units/s) | Speed (m/s) | Notes |
|---|---|---|---|
| Running with knife | 250 | 6.35 | Top speed depends on the weapon held |
| Running with rifle | 215–225 | 5.5–5.7 | |
| Walking (Shift) | 52% of running | | Footsteps are silent |
| Crouching (Ctrl) | 34% of running | | Better accuracy, smaller target |
| Jump height | ~57 units | ~1.45 m | Big accuracy penalty while in the air |

Ground acceleration is based on 250 u/s times the stance factor, whatever weapon you hold, as in CS:GO (D-023).

Starting physics values, CS:GO-like *(tune)*:

| Setting | Value |
|---|---|
| Gravity | 800 units/s² (20.3 m/s²) |
| Ground acceleration | 5.5 |
| Friction | 5.2 |
| Stop speed | 80 units/s |
| Air acceleration | 12 |

**Body:** 1.83 m tall (72 units), eyes at 1.63 m (64 units), 0.8 m wide.

**View:** CS's default field of view, 90° horizontally on a 4:3 screen. Widescreen shows more at the sides, as in CS.

**Units:** 1 Godot unit = 1 metre. CS values are converted with 1 Source unit ≈ 2.54 cm, which makes the 72-unit-tall CS player about 1.83 m tall.

**Skills the movement must support:** counter-strafing (tapping the opposite key to stop instantly), jiggle peeking and crouch-jumping onto boxes.

**Crouch-jump:** crouching in the air pulls your legs up, so press crouch while airborne, or together with jump. This raises your feet from 57 to 75 units, enough to land on a 64-unit crate.

**Measured** (by `tests/movement_test.gd`, holding the Rifle):

| Check | Result |
|---|---|
| Run / walk / crouch top speed | 215 / 112 / 73 u/s (250 / 130 / 85 with nothing in hand) |
| Time to drop below 34% speed (accurate shooting) | 70 ms counter-strafing, 203 ms releasing the key |
| Standing jump / crouch-jump, feet height | 57 u / 75 u |
| Speed you can add sideways in the air | 0.76 m/s (30 u/s) |
| Bunny-hop cap | 1.2 × run speed (6.55 m/s with the Rifle) |

### 4.2 Shooting

- **Hitscan:** bullets hit instantly along a straight line, with no travel time, like in CS.
- **Accuracy:**
  - The first shot is accurate when you stand still.
  - Inaccuracy grows with movement speed, jumping and sustained fire. Crouching reduces it.
  - Each automatic weapon has a fixed, learnable **spray pattern** plus a little random spread.
  - Recoil recovers over time once you stop shooting.
  - **How recoil works in Chiip:** each shot's position in the spray pattern pushes it away from your aim. The view kicks by half of that (aim punch), so while spraying the bullets land above the crosshair and you pull down to compensate. After you stop, the pattern wears off at 12 shots per second (starting 0.15 s after the last shot): a 3-shot burst is gone in about 0.4 s, a full 30-shot spray in about 2.6 s. Checked: shots follow the pattern exactly (0.0000° off with random spread switched off).
  - Shots land at a random spot inside a cone around your aim. The distance from the center is uniform (as in CS), so on average shots land halfway out and most hit near the middle. Measured with 20 taps each: standing 0.057° average / 0.115° worst (cone 0.12°), running 2.5° / 4.4° (cone 4.6°).
- **Damage by hit zone** (CS-like multipliers *(tune)*):

  | Zone | Multiplier |
  |---|---|
  | Head | ×4 |
  | Chest and arms | ×1 |
  | Stomach | ×1.25 |
  | Legs | ×0.75 |

- **Measured with the Rifle** (one shot per zone at a dummy):

  | Zone | 5 m | 40 m |
  |---|---|---|
  | Head | 142.9 | 135.2 |
  | Stomach | 44.7 | 42.2 |
  | Chest / arms | 35.7 | 33.8 |
  | Legs | 26.8 | 25.3 |

  A headshot kills an unarmored player (100 HP) at any distance on the range. Damage is shown rounded down, as in CS.
- **Armor** reduces body damage, and a **helmet** reduces headshot damage (CS:GO's rule, D-093): see 4.11.
- Later (backlog): wallbangs (shooting through thin surfaces) and tagging (getting hit slows you down).

### 4.3 Weapons

Weapons get their own names in Chiip (provisional, D-090: your check). CS names are used here only as a reference. Every weapon is one data file (`weapons/<role>.tres`, D-091), and **`docs/weapons.csv`** is the balancing table exported from those files (`tools/export_weapon_table.gd`): every stat plus damage per second, shots to kill with and without armor, and whether a headshot kills through a helmet, at 10 and 30 m. Open it in Excel or Numbers. Starting values *(tune)*:

You get weapons three ways: the **loadout** (rounds: the knife and the Sparrow; Team Deathmatch: your class's signature gun, the Sparrow, the knife and a grenade), the **buy menu** (rounds only, 4.6), and **pickups**: guns the dead drop and **map weapons** that appear at random places each round (4.6, D-098).

| Slot | Weapon (role) | CS reference | Price | Kill reward | Damage | Armor pen. | Fire rate | Magazine | Reload | Speed (u/s) | Draw |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pistol | **Sparrow** (service pistol, semi-auto) | Glock / USP | in every loadout ($200 if you lost it) | $200 | 32, ×0.90 | 50% | 400 /min | 15 + 45 | 2.2 s | 240 | 0.6 s |
| Pistol | **Verdict** (hand cannon, semi-auto) | Desert Eagle | $500 | $200 | 63, ×0.81 | 93.2% | 267 /min | 7 + 35 | 2.2 s | 230 | 0.75 s |
| Primary | **Hornet** (SMG) | MP9 / MAC-10 | $1,000 | $200 | 26, ×0.87 | 60% | 857 /min | 30 + 120 | 2.1 s | 240 | 0.75 s |
| Primary | **Breaker** (pump shotgun, 9 pellets in a 3.2° cone) | Nova | $1,000 | $200 | 9 × 26, ×0.70, 30 m reach | 50% | 68 /min | 8 + 32 | 0.4 s + 0.5 s per shell | 220 | 0.85 s |
| Primary | **Ram** (AK-style rifle) | AK-47 | $2,500 | $200 | 36, ×0.98 | 77.5% | 600 /min | 30 + 90 | 2.5 s | 215 | 0.95 s |
| Primary | **Warden** (carbine) | M4A4 | $2,500 | $200 | 33, ×0.97 | 70% | 666 /min | 30 + 90 | 3.1 s | 225 | 0.95 s |
| Primary | **Heron** (sniper rifle, scoped) | AWP | $4,000 | $200 | 115, ×0.99 | 97.5% | 41 /min | 5 + 30 | 3.7 s | 200 (100 scoped) | 1.15 s |
| Knife | **Knife** (slash 40, stab 65; from behind 90 / 180) | Knife | in every loadout | $500 | — | 85% | slash 0.4 s, stab 1 s | — | — | 250 | 0.5 s |
| Grenade | **Frag** (high explosive) | HE grenade | $300 | $200 | 98 at the centre | 57.5% | — | 1 | — | 245 | 0.5 s |
| Grenade | **Flashbang** | Flashbang | $200 | — | blinds | — | — | 2 | — | 245 | 0.5 s |
| Grenade | **Smoke** | Smoke grenade | $300 | — | an 18 s cloud | — | — | 1 | — | 245 | 0.5 s |

Damage is per bullet at point-blank, then ×the falloff for every 500 units (12.7 m). *Armor pen.* is the share of a hit on armor that still reaches health (CS's armor ratio halved, see 4.2). *Draw* is the time after switching to it before it can fire. What the numbers mean in a fight (from the table, 10 m):

- **A headshot through a helmet kills** with the Ram (111), the Verdict, the Heron and a full Breaker blast; not with the Warden (92), the Hornet or the Sparrow. That's CS's AK-vs-M4 trade: the Warden is more accurate, moves faster and holds 30 rounds, but needs a second bullet on a helmet.
- **Body shots to kill:** Ram 3 (4 through armor), Warden 4 (5), Hornet 5 (8), Sparrow 4 (7), Verdict 2 (3), Breaker one blast (two through armor), Heron one, armor or not.
- **Prices are round and go by tier** (the light economy, D-090): $500 for the better pistol, $1,000 for the close-range guns, $2,500 for a rifle, $4,000 for the sniper rifle. Every kill pays $200, a knife kill $500.

**Rifle** (the Ram, AK-like), its M2 values in detail *(tune)*:

| Stat | Value | CS AK-47 reference |
|---|---|---|
| Damage | 36, ×0.98 per 500 units of distance | 36, 0.98 |
| Headshot | 144 at point-blank: kills an unarmored player in one shot | 143 |
| Fire rate | 600 rounds/min | 600 |
| Magazine | 30 + 90 | 30 + 90 |
| Reload | 2.5 s | ~2.5 s |
| Speed while held | 215 u/s | 215 |
| Accuracy (cone radius) | 0.12° standing, 0.08° crouched, +4.5° at full run, +9° in the air, +0.1° per spray shot (max +1.5°) | — |
| Spray | 30-shot pattern: climbs ~6° over 10 shots, sways left to −2.3°, then right to +1.95° | Similar shape |
| Aim punch | The view kicks 50% of the pattern; recoil wears off at 12 shots per second | ~50% |

**How each kind works** (D-095):

- **Pistols** (Sparrow, Verdict) fire once per click; holding the trigger fires one shot.
- **The Breaker** fires 9 pellets in a 3.2° cone (on top of its own small inaccuracy): one blast kills up close, while at 25 m most pellets miss and falloff does the rest. It loads **one shell at a time** (0.4 s to bring it up, 0.5 s a shell); pressing fire with at least one shell in stops the reload and fires.
- **The Heron's scope:** the right mouse button steps through two zoom levels (40/90 and 15/90 of your field of view, CS's AWP) and back out. Unscoped it is useless (a 4° cone) and shows no crosshair, as in CS. Scoping in takes 0.3 s to become fully accurate (0.02°); moving costs accuracy that takes 0.35 s to come back after you stop; scoped you move at 100 u/s. After each shot you drop out of the scope and go back in once the bolt is worked (1.46 s). The mouse turns the view less while scoped, in step with the zoom, so the same hand movement crosses the same part of the screen. A black scope view with a round window and thin cross lines covers the screen.
- **The knife:** left click slashes (40, every 0.4 s, reach 1.5 m), right click stabs (65, every second, reach 1.1 m); from behind (the victim facing away) 90 and 180. The damage is the same on every zone (no headshot bonus, as in CS), and armor stops 15% of it. A swing makes no noise for the bots.
- **Reloads are per holder:** the Rifleman's *Quick Hands* reloads 15% faster (the Ram in 2.1 s).

The other automatic guns have their own patterns: the Warden climbs about 78% as high and sways right first, the Hornet climbs only 3.6° and then wobbles quickly from side to side; quick pistol shots climb (the Verdict 2.8° a shot), and the Breaker and Heron kick once per shot.

Every weapon is generated from one part list (D-054) and comes as a world model (drops and pickups), a third-person model in the character's hand, a first-person model with arms, and buy-menu and kill-feed icons.

### 4.4 Bots

- Find their way around the map using a navigation mesh.
- Behaviour states: follow the round's orders (attack, defend, or patrol in practice) → engage an enemy → search the last known position. In bomb rounds the orders include planting and defusing (see below).
- **Vision:** a field-of-view cone plus a line-of-sight check, so no wallhacks.
- **Hearing:** running footsteps and gunshots reveal your position. Walking is silent.
- **Difficulty** comes from reaction time, aim accuracy, spray control and decision speed. Presets *(tune)*:

  | | Easy | Normal | Hard |
  |---|---|---|---|
  | Noticing speed | 1.5× slower | baseline | 0.7× |
  | Reaction time (after noticing) | 0.6 s | 0.45 s | 0.3 s |
  | Max turn speed | 150°/s | 220°/s | 320°/s |
  | Aim error (start → smallest wobble) | 10° → 2° | 8° → 1.1° | 5° → 0.8° |
  | Headshot chance | 5% | 15% | 35% |
  | Recoil control | 10% | 50% | 65% |
  | Counter-strafes before shooting | no | yes | yes |

  *Noticing*: an enemy must stay in view for a moment before a bot reacts: 0.25 s + 1 s per 35 m, 2.5× longer outside the central 50° of its vision (D-037). Measured for Normal: 0.50 s at 10 m straight ahead, 1.31 s at 40 m, 1.11 s at 10 m at the edge of vision.

  Measured against a player standing still at 10 m with the bot holding an angle (3 runs each, after the M4 playtest tuning): first shot after ~1.4 / ~0.95 / ~0.6 s, kill after ~4.3 / 2–4 / 1.1–1.5 s. A moving target is much harder for them.
- **States:** patrol → engage (enemy noticed) → search (walk to the last known position, look left, right and ahead) → patrol. Hearing you run, or being shot, makes a bot come and check. A bot can also *hold* a position (watch one direction) instead of patrolling.
- **In a match** (D-045) every bot gets orders at the start of each round:
  - **Attackers** split into loose groups of about two (3 attackers: a pair and a single). Each group takes one of the map's attack routes (the test map has a west, a middle and an east lane), its members setting off 0.6 s apart with a little spread, so they don't walk in single file. At the end of the route they *clear* the defenders' end: they check the hold spots and the defenders' spawn at random, **walking** (silent), until the round is over.
  - **Defenders** each take a different hold spot near their end (the test map has six: the platform, the west flank, both ends of the peek walls, the gap between them, beside the tunnel) and watch its angle, letting the view drift ±10°. They leave the spot only for enemies seen or heard within **35 m**, so a fight far up the map doesn't pull everyone out. After a fight or a search they hold the nearest spot.
  - After a detour (a fight or a search), attackers carry on from the part of their route they're nearest to, instead of walking back.
- **No long-range stalemates** (D-067): an attacker that has traded shots with an enemy beyond 35 m for 6 s stops shooting for 4 s and closes in. Defenders keep holding at any range.
- **In bomb rounds** (D-081): the attackers pick one site at random. The carrier's group takes the route that ends nearest to it, and after their routes all attackers clear around that site. The carrier plants near the site's middle, or goes straight there when less than 30 s of round time would be left for it. The attacker bot nearest a dropped bomb fetches it. After the plant the attackers watch the bomb from 5–10 m away; every defender retakes: the first at the bomb defuses and the others cover within 7 m, looking away from it. A bot planting or defusing stops to fight an enemy who shows up unless it's at least 70% done (or the fuse wouldn't allow a restart). The carrier and the fetcher don't go and check noises, and after the plant bots only check enemies within 15 m of the bomb.
- **In the team respawn mode** (D-083) bots hunt in pairs: each team's bots form groups of about two. The member alive the longest leads: it runs to a teammate's sighting (anything a teammate saw or heard in the last 6 s) if it's within 25 m, otherwise it roams from patrol point to patrol point, looking left and right at each. Its partner follows about 6 m behind and to one side, watching that flank; the leader walks while the partner catches up. A bot only goes to check what it saw or heard within 25 m, so the fights spread over the map instead of everyone running to every gunshot.
- **Buying** (D-099): bots buy as a team as the freeze time begins: a pistol round in the first round of each half, a full buy when the team averages $3,300 (each class its gun, a vest and a helmet, kits for defenders, grenades), a force buy (cheap guns and a vest) when a team is on match point, in the last round of a half or with $2,400 on average, and otherwise a save. At half time each bot changes class (the team stays a mix).
- **Using the arsenal** (D-099): a gun in hand always (the pistol when the primary is empty, or instead of a reload up close), the Heron scoped and still before it fires, the shotgun only within 18 m, guns worth $500 more picked up within 10 m (map weapons within 15 m), and frags and flashbangs thrown at enemies they heard or lost sight of 6–24 m away (looking away from their own flash).
- **Getting unstuck:** a bot that tries to walk but gets nowhere for 0.5 s jumps (like a CS bot); after 1.2 s it backs off to the side and finds a new path.
- **Holding fire:** a bot doesn't shoot while a living teammate (you included) is within 0.6 m of its line of fire, whether or not friendly fire is on.
- Measured in a bots-only 3v3 on the test map: defenders are on their spots after about 7 s, attackers are 36 m out of spawn after 10 s, the first fight starts after about 12 s, and rounds end by elimination after 27–47 s.
- **Turning** eases in and out like a hand on a mouse (no constant-speed snapping), so tracking a moving target lags a little.
- **Animation:** procedural walk cycle (legs swing from the hips, arms a little, the body bobs), a placeholder until real animated models (D-039).

### 4.5 Rounds and match

- Two teams **without names** (D-041). Each player sees their own team in **blue** and the enemies in **red**. Underneath, one side attacks and the other defends, which decides where they spawn and who wins on time-out.
- You plus bot teammates vs. a bot team: 1–5 per side, 3v3 by default.
- **Main menu and match setup** (D-064). The game starts on the **main menu**: the title CHIIP and the buttons **Play**, **Practice**, **Settings** and **Quit**, over a slow camera flight across the test map (a calm 80-second lap, 4 to 6 m up, looking over the level; nobody is playing). Since M10 (D-135, your mockup) the main menu is a dark column on the left: CHIIP, then **Play**, **Practice**, **Settings**, **Quit**, and Host and Join ("soon", M9). **Play** opens the **Play screen**: three cards, **Team Deathmatch** (picked and framed in lime, "click to play": one click on it starts the match), **Bomb** and **Practice** (a click picks one, a second click or the big Play button plays it), and under them **Custom**, the picked mode's options. **Practice** in the main menu starts the **Shooting Range** at once (D-141: no bots until you add them from the console). The defaults are Team Deathmatch on the rotation from Depot; a settings file from before M10 gets them once. Custom lets you choose: your team size and the enemy team size (1–5 each, you included in yours; 3v3 by default), the bots' difficulty (Easy, **Normal**, Hard), the length (first to **5**, 10 or 15 rounds in Bomb; first to 25, **50**, 75 or 100 kills and **5**, **10** or 15 minutes in Team Deathmatch), friendly fire (**Off** or On) and the map (every map in the game but the Shooting Range, which is practice only, and the hidden test map; Depot by default, D-141). Since M8 (D-087) it starts with the **Mode**: **Rounds** (bomb rounds on maps with bomb sites) or **Team respawn**, whose length is first to 30, **50** or 75 kills; and a **Maps** row: **One map**, or **Rotation**: Depot, Square and Spillway one after the other, starting on the map you chose if it's one of them. A line sums it up ("You and 2 bots against 3 bots. Normal bots, first to 5 rounds, friendly fire off.", "Team respawn: … first to 50 kills …", "Maps in rotation: Depot, Square, Spillway."). **Start** begins the match, **Back** returns. The game remembers your last choices for the next start. **Esc** closes match setup or the settings menu; on the main page it does nothing. In the game, the end screen's **Main menu** button and the console command `disconnect` (as in CS) go back to the menu.
- **Pause menu** (D-065). In the game **Esc** pauses everything: the round timer, the bots, bullets and sounds all stand still, and a panel offers **Resume**, **Settings** (the same settings menu; Esc or Back returns to the pause menu) and **Leave match** (**Leave practice** in the bot arena), which goes back to the main menu. Esc again resumes. Esc does nothing new while the console is open (it closes the console) or after the match is over (the end screen has the screen). While you are paused the Tab scoreboard stays hidden and the HUD stays as it was. This is for playing alone: in multiplayer (M9) nobody can stop the other players, so there the menu will be an overlay that doesn't pause (D-065).
- Round phases *(tune)*: freeze time (5 s; 15 s with buying from M7) → live round (1:55) → round end (5 s). During freeze time you can look around, crouch and reload, but not move, jump or shoot.
- At each round start everyone is back at their side's spawn with full health and a **fresh loadout**: the knife and the Sparrow, no armor (D-090, section 4.6). In team respawn and practice you spawn with your class's loadout instead.
- A round is won by eliminating the other team, or through the bomb (section 4.7: on maps with bomb sites the explosion wins it for the attackers and a defuse for the defenders). If time runs out before a plant, the defending side wins, as in CS. If the last players of both teams die in the same moment, the defenders win too (after a plant: the attackers).
- Whoever dies stays dead until the next round. During the round-end pause the survivors can still move and shoot, but the result stands.
- **After you die in a match you spectate** (D-046), like CS, in first person only:
  - For about **2 s** you still see your own view from where you fell, with "Killed by …", so you see who got you.
  - Then the view moves to a living **teammate**: you see exactly what they see (their eyes, their aim, their recoil kick, their muzzle flash), and hear from where they are. Their health, ammo and weapon replace yours on the HUD, and a line at the bottom says "Spectating Bot2 · click for next". No free look.
  - **Left click** switches to the next living teammate. When the one you watch dies, the view moves on to the next one after **1.5 s**. If no teammate is alive, you stay on the last view, where they fell, and watch the end of the round from there.
  - When the next round starts you are back in your own eyes. You can't watch the other team.
- **Compass** (M11, D-180): a thin strip at the top centre, above the round bar, as plain as it gets: N, E, S and W with small ticks every 15 degrees, turning with your view (120 degrees across), a short pointer in the middle. When an **enemy fires** within 60 m (a gunshot, as the bots hear it), a small red square appears at that bearing and fades out after about two seconds: one square per enemy, moving as you turn, stuck to the strip's edge when he is more than 60 degrees to the side. Nothing else is marked: no teammates, no footsteps, no grenades. Practice shows it too; it hides while you are dead.
- **Round HUD** (D-047, matches only; practice mode shows none of it). Colors are always relative to you: your team blue, the enemy red.
  - **Top bar, top centre:** your score on the left (blue box), the round timer in the middle with "Round 3" under it, their score on the right (red box). Under each score one small square per player, lit while that player is alive. The timer counts the freeze time down (yellow) before the round and then runs from 1:55 (red in the last 10 s); after the round ends it stays where it stopped (0:00 after a time-out).
  - **Freeze time, centre:** "Round 3 · starts in 4", and your side this half: "You attack: push to the far end" or "You defend: hold your end". After half time "Switching sides" is shown above it, and a team one round from winning gets "Match point" (yours, blue), "Enemy match point" (red) or "Match point for both teams" below it.
  - **Round end, centre:** "Round won" (blue) or "Round lost" (red), and why, said for your side: "Enemy team eliminated" / "Your team was eliminated", "Time ran out: you held your end" / "Time ran out: the defenders held their end".
  - **Kill feed, top right:** one line per death, "Killer > Victim" with each name in its team's color and a gold "HS" after a headshot kill; a death without a killer shows only the victim. Lines that involve you (a kill of yours or your own death) have a darker background and a white outline. The newest line is at the bottom, at most 5 lines show, each fades out after 5 s, and the feed starts empty in every round.
- **Scoreboard** (D-050, hold **Tab**, matches only): while you hold the key a panel appears in the middle of the screen, and it is gone when you let go. It never pauses the game, blocks movement or takes mouse clicks, so you can peek at it while moving. At the top "Round 3" and the score, yours in blue and theirs in red; below it both teams as tables, yours first under a blue header, the enemy under a red one. One row per player: name, kills, deaths, assists and damage (rounded), best first (most kills, then most damage, then the order they joined). Your own row is highlighted and marked "(you)". **Players who are dead this round are dimmed**, so you see at a glance who is still alive. The numbers follow the match while you hold it. It stays closed while the developer console is open and once the match is over (the end screen shows the final table, where nobody is dimmed). Practice mode has no scoreboard.
- **Stats** for the scoreboard: kills (a teamkill counts −1), deaths, assists (more than 40 damage to an enemy someone else kills, as in CS) and damage (health actually removed, so a 142-damage headshot on a 30 HP enemy counts 30).
- **Practice** (the main menu's **Practice** button, or `-- --practice`): the **Shooting Range** (D-141), without rounds. One simple yard. Targets at 5, 10, 20 and 40 m and one moving at 15 m (walking pace, 2.5 m/s) show every hit's damage and a running total; a spray wall at 10 m; a stand for every gun and grenade, refilled 2 s after you take it (D-142); a small open area behind the stands for fights. It starts with **no bots**: the console's `bot_add [easy|normal|hard] [ally|enemy]` adds one (an enemy unless `ally`), `bot_kick [all]` removes them, `bot_difficulty <level>` changes them all. Bots come at the difficulty you last chose in match setup (Normal at first), in the open area, at least 20 m from you. Bots and you respawn after 3 s (you where you started), so there is no spectating. Practice on another map (the console's `map`, or `--map`) starts with two bots, as before.
- Match: first to **5** (default), **10** or **15** rounds. Sides swap at half time, after 4, 9 or 14 rounds, so a draw is impossible. The teams keep their numbers and colors; only who attacks and who defends flips, so each team starts the next round at the other end of the map. The longest match is 9, 19 or 29 rounds.
- **How a match ends:** when a team wins its 5th (10th, 15th) round, the usual round-end pause still plays so you see how that round was won. Then everyone is frozen and the **end screen** opens over the scene with the mouse free: "Victory" or "Defeat" for your team, the final score ("yours - theirs", your number blue, theirs red), and a scoreboard with your team first (blue) and the enemy team below (red): one row per player with kills, deaths, assists and damage, best first (kills, then damage), your own row highlighted. Buttons: **Play again** (a fresh match on the same map) and **Main menu** (back to the main menu; it was Quit until the menu existed).
- **Spawns:** each side has five spawn points at its own end of the map. On the test map the defenders start at the north end behind the peek walls and the attackers at the south end of the range, 112 m apart.
- Friendly fire is a match setting: off by default; when on, teammates take a third of the damage, like CS competitive. With it off, bullets pass through teammates (as in CS), so a teammate walking through your spray doesn't block it.
- **Modes** (D-049). **Team Deathmatch** (the team respawn mode) is the primary mode: first in the menu and the default (D-120).
  - **Rounds** (today's mode): one life per round, the bomb objective from M8. Like CS, or CoD's Search & Destroy.
  - **Team respawn** (M8, D-082): like CoD's Team Deathmatch. Both teams start at their ends after 5 s of freeze time. After you die the centre of the screen says "Killed by Bot2" and counts "Respawning in 3", 2, 1 (D-133). You respawn **3 s** after dying, with full health and ammo, at the map's safest respawn point: as far from the living enemies as possible (40 m and more count the same, so far spots take turns), out of their line of sight, preferably near a teammate. Each enemy killed is a point for the killer's team (teamkills and suicides score nothing). The first team to **50 kills** wins (*tune*; D-083: bots-only 3v3 matches score about 20 kills a minute, so this takes about 4 minutes), or the team with more kills after **10 minutes**; a tie goes to **overtime**, where the next kill wins. The top bar shows the kills, "First to 50" under the timer ("OT" and "Next kill wins" in overtime); no bomb and no spectating. Choose it in match setup's Mode row (or `-- --respawn` from the terminal).
- **Maps** (D-049): three small, fast maps in rotation (M8), built for action like CoD's maps rather than CS's long ones. With **Rotation** chosen in match setup (D-087) the end screen offers **Next map: Square** (Depot → Square → Spillway → Depot…): a fresh match by the same rules; **Play again** replays the same map. About 40–60 m across, with three lanes and connections between them, first contact within 5–10 s of spawning, and short sightlines. Every map has two bomb sites and spawn zones, so it works in both modes.

### 4.6 Economy and pickups

A mix of CS and Call of Duty (D-090, your answers of 2026-10-16): a **light economy** where money still matters, a **fresh loadout every round**, and weapons you **pick up**. *(tune)*

- **A fresh loadout every round** (bomb rounds), like CoD's Search & Destroy: at each round start everyone, alive or dead last round, has the **knife and the Sparrow** and nothing else. Whatever you bought or picked up (guns, armor, grenades, a kit) lasts that round only. Money carries over.
- **Money** (round numbers, easy to read): **$1,000** at the start of each half, **$10,000** at most.

  | For | Money |
  |---|---|
  | Winning a round | $3,000 |
  | Losing a round | $1,500; $2,000 for the second loss in a row, $2,500 for the third, $3,000 from the fourth (a win starts the count again) |
  | A kill | $200 ($500 with the knife) |
  | A teamkill | −$200 |
  | Planting the bomb | $200 for every attacker, win or lose |
  | Defusing the bomb | $200 for the defuser |

- **Buying:** during the 15 s freeze time, when everyone stands at their spawn (so there is no buy zone): **B** opens the buy menu. Prices: Verdict $500; Hornet and Breaker $1,000; Ram and Warden $2,500; Heron $4,000; Sparrow $200 (only if you lost yours); vest $500, vest and helmet $800; defuse kit $300 (defenders); Frag $300, Flashbang $200, Smoke $300. A full buy (rifle, vest and helmet, a grenade) is $3,600, so a winning team can buy every round, and a losing team saves for a round or two, buys cheap, or takes guns off the floor.
- **Pickups:** a gun the dead drop (their best one: the primary, else the pistol) lies on the floor for the rest of the round with its ammo. Walk over it to take it into a free slot; **E** while looking at it swaps it for the gun in that slot. **G** drops the gun you hold. Walking over a dropped gun of a kind you already carry takes its ammo into your reserve (CoD's scavenging; never from a map weapon).
- **Map weapons** (D-098): guns appear at **random places** on the map, never within 15 m of a team's spawn (and 8 m of a respawn point in Team Deathmatch) or on a bomb site, and never always in the same place. Which gun is random too: the Hornet most often, then the Warden, the Ram and the Breaker, the Verdict and the Heron rarest. Each floats and turns over a glowing gold ring with its name and a beam of light. Rounds: **two** new ones every round. Team Deathmatch: **three** out at a time, a taken one replaced somewhere else 20 s later. Walk over one to take it, like any gun on the floor.
- **Team respawn has no money:** you spawn with your class's loadout (its signature gun in hand, the Sparrow, the knife and one grenade); pickups and map weapons work as in rounds, and a dropped gun goes after 30 s; the class menu works any time and your next respawn brings the new class's loadout.
- **Practice:** your class's loadout, and the buy menu gives anything for free, any time.

### 4.7 Bomb mode

Bomb rounds are the round mode on every map with bomb sites (the three quick maps; the test map has none and keeps plain elimination rounds). CS's rules (D-080, *tune*):

- **Carrying:** at each round start a random attacker has the bomb, strapped to their back where everyone can see it. If the carrier dies, it drops where they fell; the first attacker to walk over it picks it up. Defenders can't. Attackers see a dropped bomb's marker through walls (CS shows it on their radar), and get the message "The bomb was dropped".
- **Planting:** hold **Use (E)** inside a bomb site, standing on the floor, for **3.2 s**. You can look around and crouch, but not move or shoot. Letting go starts it over. Defenders within 20 m hear the key presses.
- **After the plant:** the round clock stops and the timer shows "BOMB"; everyone is told the site ("Bomb planted at A") and sees the bomb's marker. The bomb beeps faster and faster (once a second at first, about 8 times a second at the end) and explodes after **40 s**.
- **Defusing:** a defender holds **Use** within **1.5 m** of the bomb for **10 s** (**5 s** with a defuse kit: $300 in the buy menu, defenders only, one round, D-098). The same lock and restart rule as planting; only one defender defuses at a time.
- **Winning:** the explosion wins the round for the attackers, a defuse for the defenders. After the plant, killing every attacker doesn't end the round (the defenders still have to defuse), and killing every defender wins it for the attackers at once. Before the plant, the usual rules: elimination, or the defenders on time-out.
- **The blast:** 500 damage at the bomb, falling off like a bell curve: lethal out to about 13.5 m, 50 damage at about 18 m, nothing beyond about 22 m. Walls don't shield. Nobody gets a kill for it.
- **HUD:** a gold "BOMB" tag above your weapon while you carry it; "Hold E to plant" / "Hold E to defuse" under the crosshair where you can; "Planting" / "Defusing" with a progress bar while you do. Freeze time says "You attack: plant the bomb at A or B" or "You defend: guard A and B"; the round-end banner says "The bomb exploded" or "The bomb was defused".

### 4.8 Audio

In a tactical shooter, sound is part of the gameplay. Footsteps and gunshots must be directional and easy to read. They are retro-styled but clear.

- **Your own footsteps** are clearly audible, so you always know when you're making noise, but quieter than an enemy's steps 5 m away.
- **The mix** (M13, D-194): every sound of a kind is equally loud, so loudness tells distance and nothing else. Your own rifle shot sounds like an enemy's 10 m away; an enemy's shot at 40 m is 14 dB quieter. In a fight an enemy's step 8 m away stays within 8 dB of your own shot. The bomb's beep is clearly above the steps around it. Nothing plays louder than its file, and a limiter keeps a big fight from clipping.
- **Enemy footsteps** are loud and directional (a step at your side is 14 dB louder in the near ear, D-190) and fade out at 30 m, a bit beyond the 25 m at which bots hear you. Hearing is symmetric: you can hear them as far as they can hear you (D-038).
- **Footsteps are bright** (most energy around 1–6 kHz), so they carry on laptop speakers too.
- Walking (Shift) and crouch-walking are silent for everyone.
- While you spectate a teammate (see 4.5) you hear from where they are, as in CS: the listener is the camera, which sits at their head.
- Four volumes (D-058, D-195): **master**, **effects** (everything in the game), **interface** (menu clicks, the bomb-planted alert) and **music** (the menu track and the stingers), so each can be turned down on its own.
- **Footsteps sound like the floor** (D-084): hard (concrete, stone, plaster), gravel (a crunch), metal (a ring) and wood (a hollow knock). Same range and loudness on every floor.
- **Bullets** make a sound where they land, heard within 35 m: a crack on hard surfaces, a thud in gravel, a ping on metal, a thock in wood, a thwack on a body, and a bright "dink" on a head, louder and heard farther, like CS's headshot sound.
- **Every gun sounds like itself** (M13, D-191): seven shot signatures (the pistol's snap, the hand cannon's cracking boom, the SMG's papery rattle, the carbine's tight crack, the rifle's heavy thump, the shotgun's blast, the sniper rifle's crack and roll). Farther than 15 m another player's shot starts turning into its **far variant** (duller, with a long echo), all far by 40 m, so you hear how far away a fight is. The frag and the bomb have far variants too. The sniper rifle carries 2 dB more than the rifle, the hand cannon and shotgun 1 dB more, the SMG 1 dB less and the pistols 2 dB less.
- **Walls muffle sound** (M13, D-192): a sound whose straight path to you is blocked is duller and quieter, 4 dB per wall and 1.5 dB per metre of wall (at most 18 dB); round a corner (a pillar, a crate, a door frame next to you) it is only 3 dB quieter and a little dull. Steps and reloads get all of it, shots and explosions three quarters (a fight across the map stays audible), the bomb's beep half.
- **The place sounds like itself** (M13, D-193): in a small room the sound is short and close, in a hall bigger and longer, in a yard between walls it has a short slap echo, and in the open it is almost dry. It is the place *you* stand in, found from the map around you, and it changes smoothly as you walk through a door. Kept light, so every step stays clear.
- **Reloads** have three sounds per gun (magazine out, magazine in, bolt or slide), different for each gun, and others hear them within 15 m.
- **The bomb** beeps faster and faster once planted, and planting (key presses) and defusing (wire clicks) can be heard 20 m away. Everyone hears a two-tone alert when it's planted, and the explosion.
- **Interface:** menu buttons tick on hover and click when pressed. Game sounds play on the *Effects* bus, interface sounds on *Interface*.
- **Music** (M13, D-195): a dark, driving 35 s loop in the main menu that fades out when a game starts, and short stingers in the same key: a punchy "go" when a round goes live, a rising phrase for a round won, a falling one for a round lost, a phrase of relief when the bomb is defused (for both teams), and longer cadences for a match won or lost. Made for Chiip, on the *Music* bus.
- All sounds are generated by code (D-020), retro and short.

### 4.9 Classes

Four classes, each with its own look and **one passive perk** (D-052). Classes don't restrict weapons: anyone can buy or pick up anything, so the economy stays CS-like. The signature gun is the class's loadout where there's no money (team respawn and practice: signature gun, Sparrow, knife and one grenade, shown on the class card; D-090) and what its bots like to buy. You pick a class at match start and can change it during freeze time (in team respawn any time: the new class comes with your next respawn); bots get a mix and pick again at half time. **All four perks work** (M7, D-099): the numbers in the table below. **How you pick** (D-078): a class menu opens by itself when the match starts (four cards: click one or press **1** to **4**; **Esc** closes it without a change), and **M** opens it again during freeze time of any round, so you can change class between rounds but never in a live round. Your class stays until you change it. In practice mode, which has no freeze time, M works at any time. The console's `class [name]` does the same. **Bots get a mix:** each team's bots cycle through the four classes from a random one, so three bots are three different classes.

| Class | Build and silhouette | Perk *(tune)* | Signature gun (respawn loadout) |
|---|---|---|---|
| **Rifleman** | 1.82 m, stocky, upright. High-cut helmet with a team stripe, goggles, plate carrier, olive-grey trousers | **Quick Hands:** reloads and weapon switches 15% faster | Ram (+ Frag) |
| **Bulwark** | 1.92 m, broad, slight hunch. Closed helmet with a team stripe over a gas mask, big grey shoulder plates edged in team colour | **Plated:** with armor on, takes 10% less damage than other classes and the armor wears down 30% slower. No effect without armor | Breaker (+ Flashbang) |
| **Marksman** | 1.88 m, lanky. Knee-length moss-grey coat, hood, team-colour scarf and a team panel across the back | **Steady:** scoped accuracy recovers 30% faster after moving, and scoping in is 20% faster | Heron (+ Smoke) |
| **Scout** | 1.72 m, slim. Beanie, balaclava, glowing goggles, a fitted team-colour jacket, a radio with an antenna | **Light Step:** running footsteps carry 70% as far (a deliberate exception to D-038) | Hornet (+ Flashbang) |

- **The class draft** (D-099): each match offers you **two random classes**; you choose one in the class menu that opens at the start (keys 1 and 2) and can switch between your two in any freeze time (any time in Team Deathmatch, from your next respawn). Bots draft the same way, and every offer includes a class the team doesn't have yet, so each team still gets a mix. At half time the bots may switch to their other class. Practice offers all four.
- **Silhouette first** (D-053): height, build, posture and headgear make each class recognisable at a glance, even as a dark shape.
- **Team colour** is painted at runtime: every class wears a neutral kit (olive-grey, charcoal, stone grey, moss; never desert tones, D-031) with team-colour parts: **sleeves on every class**, plus the class's own marks (shirt or jacket, helmet stripe, plate edges, scarf, back panel). They show blue on your team and red on the enemy team (D-041), and cover 11–23% of the body from every side (D-070). The names are final.
- **Hit zones follow each body** (D-055, D-074, D-077): the Bulwark is the biggest target and the Scout the smallest (total zone volume Scout 132 L, Marksman 173 L, Rifleman 223 L, Bulwark 484 L, since the Bulwark's shoulder plates and ammo pack count as chest). Perks balance the difference. The zones are boxes on the body's bones (15 per class: head, chest, stomach, and one box per arm and leg bone), measured from the model's own parts, so they move with the animation. **Eye height stays the same for every class** (CS's 64 units standing, 46 crouched), and so does the collision hull, so cover and peeking work the same for everyone; a taller class shows its head above cover a little before it can see over it, and the Scout a little after.

### 4.10 Grenades

CS's grenades (D-097) *(tune)*. You carry at most 1 Frag, 2 Flashbangs and 1 Smoke (4 in all); **4** takes one out (again: the next kind).

- **Throwing:** press fire (or aim) to pull the pin (0.3 s); the grenade leaves your hand when you let go. **Fire throws** hard (15 m/s), **aim lobs** gently (7 m/s); either way 10° above where you look (when you look level; less looking up), plus your own movement (×1.25). After the last one of a kind, the weapon you held before comes out. Switching away with the pin pulled puts it back.
- **Flight:** a light gravity (0.4 of the world's, as in CS), bouncing off walls, floors and people (losing half its speed into the surface each bounce), then rolling to a stop.
- **Frag** (high explosive): goes off 1.6 s after the throw. 98 damage at the middle, falling off like a bell curve (about 87 at 1.5 m, 59 at 3 m, 13 at 6 m, nothing past 9 m). Walls stop it (it needs a clear line to your chest or head). Armor lets 57.5% through. Alone it can't kill a full-health player, as in CS. It hurts its thrower and, with friendly fire on, teammates; the kill is the thrower's, with the Frag in the kill feed.
- **Flashbang:** goes off 1.6 s after the throw. Everyone with a clear line to it is blinded (teammates and the thrower too): up to 4.5 s, white at first and fading over the last 2 s. Full strength when you look toward it (within about 45°), less from the side, only a short flash when it's behind you; full up to 8 m, a third at 45 m, nothing farther or behind a wall. Your screen goes white and your ears ring; a blinded bot sees nothing (it can't notice or keep sight of anyone) until it fades.
- **Smoke:** pops where it comes to rest (at least 1 s after the throw; at the latest after 3.5 s) into a grey cloud about 7 m across and 3 m high for **18 s**: it grows over a second and thins out over the last two. Bots can't see through it; inside it your view goes grey. Bullets pass through, as in CS.

### 4.11 Armor

CS:GO's rule (D-093), the same for every hit, in `Armor`:

- **Kevlar** (100 points) covers the chest, stomach and arms; the **helmet** covers the head while there is armor; the legs are never covered.
- On a covered hit only the weapon's **armor penetration** of the damage reaches health (the Ram 77.5%, the Warden 70%, the Heron 97.5%, see 4.3); the armor loses **half of what it stopped**. When the armor left can't stop that much, each remaining point stops two points of damage and the rest goes through. At 0 armor the helmet is gone too.
- So an armored player hit in the chest by the Ram loses 27.9 health and 4 armor; a Ram headshot does 111.6 through a helmet (a kill), a Warden headshot 92.4 (not a kill).
- The bomb's blast ignores armor (D-080's distances stay true), and dying loses armor, helmet and kit.
- The **Bulwark's Plated** perk works: while it wears armor, every hit does 10% less to its health and wears the armor 30% less.
- **HUD:** the armor number next to your health, behind a pixel shield (an "H" on it with a helmet; dimmed at 0). Console: `armor [0-100] [helmet]`.

## 5. Look and feel

The target is the era of Quake (1996) and Counter-Strike 1.x (1999–2003).

- Low internal render resolution (480 lines), upscaled crisply so pixels stay sharp (D-027, D-048).
- Pixelated textures with nearest-neighbor filtering, so no smoothing. Anisotropic filtering keeps floors sharp into the distance.
- Simple geometry: blocky architecture and low-poly models.
- Characters and weapons: minimalistic and pixelated, in a CS/Quake/CoD-like style. Low-poly models built from rigid pieces, like late-90s shooters, with palette-limited pixel textures, made by a generator (D-054). First person shows 3D arms and gun (D-051).
- World image limited to 16 shades per color channel with light ordered dithering (D-030, D-048).
- Lighting: cool daylight (D-031): neutral white sun, long shadows, light grey-blue haze, warm accents only from lamps and wood. Deliberately *not* a desert/dust look, so Chiip doesn't read as a Counter-Strike copy. Lighting is real-time, with no baked lightmaps (D-085): flat, readable light that keeps the maps editable.
- **Menus and UI** (D-057): one pixel-art look for every menu, the Silkscreen font with square panels and buttons, crisp 2 px borders and no rounded corners or smoothing. Cool dark blue-grey panels, light text and a single icy cyan accent for focus, selection and sliders; team blue and red only mark teams. Deliberately not Counter-Strike's orange and yellow on black. Everything is drawn for a 720-pixel-tall window and scales by the window height (exactly 1.5× at 1080, 2× at 1440), and text sizes sit on the font's pixel grid (16 / 32 / 48 px) so pixels stay whole. The in-game HUD keeps its own simple look. **M10 (D-130, D-134):** the look now comes from your Claude Design mockups: flat ink surfaces, 2 px lines, one lime accent (`#C8F03C`) only for focus, the UI's own team blue (`#5A94FF`) and red (`#FF4D3D`), amber for alerts, Silkscreen at 16 / 32 / 48 / 96 px with Bold titles, an 8 px grid and 32 px from the screen's edges, the "chip" (an 8 px square) marking focus and counting things, and a 21-icon pixel set. Every value is a named token in one file (D-131).
- **Clarity rule:** enemies must always stand out from the background.

## 6. Controls (default)

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Shoot / scope (Heron: two zoom steps), knife: slash / stab | Left mouse / right mouse |
| Next teammate (while dead in a match) | Left mouse |
| Jump | Space or mouse wheel down |
| Crouch | Ctrl |
| Walk (silent) | Shift |
| Reload | R |
| Weapons | 1 primary, 2 pistol, 3 knife, 4 grenades (again: the next grenade); Q last weapon; G drops the gun in hand. Switching takes the new weapon's draw time before it fires |
| Use: plant / defuse the bomb (hold); a press while looking at a gun on the floor swaps it for yours | E |
| Buy menu (freeze time; any time in practice): the category's number, then the item's, or click | B |
| Buy menu | B |
| Class menu (opens at match start; M in freeze time; 1–4 or click to pick) | M |
| Scoreboard (hold, in a match) | Tab |
| Developer console | ` (backtick / tilde key) |
| Pause menu (frees the mouse) | Esc (fixed); Esc again resumes |
| Capture the mouse again (after alt-tab, with no menu open) | Click in the window |
| Settings menu | The main menu's Settings button, the pause menu's Settings button, or the console command `settings` in the game |
| Debug overlay (hidden at start, D-133) | F3 |

Keys are bound by physical position, so they stay in the same place on any keyboard layout (e.g. Czech QWERTZ). These are the defaults: every action except Esc can be rebound (each with a second key or button) in the settings menu, see section 7; a key belongs to one action, so binding it takes it away from the one that had it, as in CS. Open question: macOS may treat Ctrl + click as a right click, which would clash with crouch + shoot. This is checked in M1 (see [DECISIONS.md](DECISIONS.md)).

## 7. Settings that matter to CS players

Settings are saved in a file (`settings.cfg` in the game's user data folder, D-058) the moment they change and apply at once, with no Apply button. They are the player's own, never part of the match rules. The settings menu (D-059; the main menu's and the pause menu's Settings buttons and the console command `settings` open it) edits them in tabs for Game, Video, Audio, Crosshair and Controls, and the console commands `sensitivity`, `fov`, `volume`, `fps_max` and `settings_reset` do too: whichever changes a value, the other follows. "Reset tab to defaults" in the menu puts one tab back. Defaults are today's behaviour. The file also remembers your last match setup (mode, team sizes, difficulty, length or kill limit, friendly fire, rotation, map; D-064, D-087), in its own `[match]` section: those are choices for the next match, not settings of the game, and the menu's "Reset tab" doesn't touch them (the console's `settings_reset` does).

| Section | Setting | Default | Range |
|---|---|---|---|
| Game | **Mouse sensitivity**, CS's scale: each mouse count turns sensitivity × 0.022° (D-016), so your CS number feels the same | 1.0 | 0.05 – 10 |
| Game | Invert Y | off | |
| Game | **Field of view** the CS way: degrees across a 4:3 screen (90 there is what CS means by 90); a wider window shows more to the sides | 90 | 70 – 110 |
| Video | Fullscreen | off | |
| Video | V-Sync | on | |
| Video | Frame limit (CS's `fps_max`), 0 = unlimited; the menu offers Unlimited, 60, 120, 144 and 240 (the console takes any value) | unlimited | 0 or 30 – 1000 |
| Video | **Pixel resolution**: height of the 3D world image in pixels (D-048) | 480 | 270, 360, 480, 540, 720 |
| Video | Palette effect, the retro color limit and dithering (D-030) | on | |
| Video | Pixelated HUD, the whole window at the low resolution (D-027) | off | |
| Video | **UI scale** (D-181): how big the menus and the HUD are, as a share of the biggest size that fits the window. Auto keeps the pixel font even (steps of half: 1×, 1.5×, 2× ...); 100 % fills the window exactly; 75 % and 50 % are smaller. Applies at once | Auto | Auto, 50, 75, 100 % |
| Audio | Master, Effects (footsteps and shots) and Interface (menus) volume, each on its own audio bus | 1.0 each | 0 – 1 |
| Crosshair | Color (swatches or a hex code) and opacity, size (line length), gap, thickness, outline, center dot and dynamic, like CS's crosshair settings; the menu shows a live preview on a dark and a light background (the sizes are in pixels at 720p and scale with the window) | green `#36D07A` (the mockup's, D-137), 7 px, gap 4, thickness 2, outline on, no dot, static (D-021) | size 1 – 30, gap 0 – 20, thickness 1 – 8 |
| Controls | Keys and mouse buttons of move, jump, crouch, walk, shoot, aim, reload, scoreboard, debug overlay and console, each with a primary and a secondary binding; Esc stays fixed. A key is bound by physical position (D-012). In the menu you click a slot and press the new key or mouse button (Esc cancels, Backspace clears the slot). **A key belongs to one action:** binding it takes it from whatever had it, and the menu says which action lost it (D-059) | section 6 | |

- The crosshair was built in M2 (`ui/crosshair.gd`, D-021). Dynamic mode widens the gap to match the actual inaccuracy cone, e.g. +38 px at 720p for 4.5°.
- A value outside its range is clamped; the file can be edited by hand, and anything unreadable falls back to the default.
- *Later:* viewmodel (weapon) position.

## 8. Out of scope for now

Matchmaking, ranked mode, skins and cosmetics, mobile.

Multiplayer *is* planned, as M9 after the single-player game: one player hosts, friends join and bots fill empty slots (D-033).
