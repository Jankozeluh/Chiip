# Chiip — Game Design Document

> Living document: it changes as the game is built and playtested. Values marked *(tune)* are starting points, not final numbers.
>
> Last updated: 2026-10-15

## 1. Pitch

Chiip is a single-player tactical first-person shooter in the spirit of Counter-Strike. You fight rounds against bots with precise, learnable gunplay, in a chunky, pixelated world that looks like a 1996 Quake-era shooter.

## 2. Design pillars

Every feature should support at least one pillar. If it doesn't, it goes to the backlog.

1. **Gunplay you can master.** Accuracy is earned by stopping before you shoot, controlling the spray and aiming at heads. Skill from CS should carry over.
2. **Every round matters.** You get one life per round, money carries between rounds, and you decide when to buy and when to save.
3. **Readable retro look.** Low-res and pixelated, but enemies are always clearly visible. Clarity beats detail.
4. **Fair bots.** Bots react with human-like delay, miss sometimes and never see through walls.

## 3. Core loop

Buy during freeze time → play the round (move, hold angles, fight, plant or defuse) → round ends → earn money → next round.

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
- **Armor** reduces body damage, and a **helmet** reduces headshot damage. Bought from M7 on; until then nobody has armor (D-041).
- Later (backlog): wallbangs (shooting through thin surfaces) and tagging (getting hit slows you down).

### 4.3 Weapons

Weapons get their own names in Chiip. CS names are used here only as a reference. Weapon stats are stored in data files (`weapons/*.tres`), so they're easy to compare and tune.

**Rifle** (working name, AK-like), starting values *(tune)*:

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

The arsenal (D-056), working names until M7:

| Slot | Weapon | Role | CS reference |
|---|---|---|---|
| Primary | Rifle (AK-style) | Main automatic weapon, one-tap headshots | AK-47 |
| Primary | Carbine | More accurate than the rifle, less damage | M4 |
| Primary | SMG | Cheap and fast to move with, for eco and anti-eco rounds | MP9 / MAC-10 |
| Primary | Pump shotgun | Close range, holds tight corners | Nova |
| Primary | Sniper rifle | One-shot body kill, slow, scoped | AWP |
| Pistol | Service pistol | Free default sidearm | Glock / USP |
| Pistol | Hand cannon | Expensive, one-tap headshots | Desert Eagle |
| Knife | Knife | Melee, fastest movement | Knife |
| Grenades | High explosive, flashbang, smoke | Utility | HE / flashbang / smoke |

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
- **Getting unstuck:** a bot that tries to walk but gets nowhere for 0.5 s jumps (like a CS bot); after 1.2 s it backs off to the side and finds a new path.
- **Holding fire:** a bot doesn't shoot while a living teammate (you included) is within 0.6 m of its line of fire, whether or not friendly fire is on.
- Measured in a bots-only 3v3 on the test map: defenders are on their spots after about 7 s, attackers are 36 m out of spawn after 10 s, the first fight starts after about 12 s, and rounds end by elimination after 27–47 s.
- **Turning** eases in and out like a hand on a mouse (no constant-speed snapping), so tracking a moving target lags a little.
- **Animation:** procedural walk cycle (legs swing from the hips, arms a little, the body bobs), a placeholder until real animated models (D-039).

### 4.5 Rounds and match

- Two teams **without names** (D-041). Each player sees their own team in **blue** and the enemies in **red**. Underneath, one side attacks and the other defends, which decides where they spawn and who wins on time-out.
- You plus bot teammates vs. a bot team: 1–5 per side, 3v3 by default.
- **Main menu and match setup** (D-064). The game starts on the **main menu**: the title CHIIP and the buttons **Play**, **Practice**, **Settings** and **Quit**, over a slow camera flight across the test map (a calm 80-second lap, 4 to 6 m up, looking over the level; nobody is playing). **Play** opens **match setup**, where you choose: your team size and the enemy team size (1–5 each, you included in yours; 3v3 by default), the bots' difficulty (Easy, **Normal**, Hard), the match length (first to **5**, 10 or 15 rounds), friendly fire (**Off** or On) and the map (every map in the game; today only the test map). A line sums it up ("You and 2 bots against 3 bots. Normal bots, first to 5 rounds, friendly fire off."). **Start** begins the match, **Back** returns. The game remembers your last choices for the next start. **Esc** closes match setup or the settings menu; on the main page it does nothing. In the game, the end screen's **Main menu** button and the console command `disconnect` (as in CS) go back to the menu.
- **Pause menu** (D-065). In the game **Esc** pauses everything: the round timer, the bots, bullets and sounds all stand still, and a panel offers **Resume**, **Settings** (the same settings menu; Esc or Back returns to the pause menu) and **Leave match** (**Leave practice** in the bot arena), which goes back to the main menu. Esc again resumes. Esc does nothing new while the console is open (it closes the console) or after the match is over (the end screen has the screen). While you are paused the Tab scoreboard stays hidden and the HUD stays as it was. This is for playing alone: in multiplayer (M9) nobody can stop the other players, so there the menu will be an overlay that doesn't pause (D-065).
- Round phases *(tune)*: freeze time (5 s; 15 s with buying from M7) → live round (1:55) → round end (5 s). During freeze time you can look around, crouch and reload, but not move, jump or shoot.
- At each round start everyone is back at their side's spawn with full health and a full rifle.
- A round is won by eliminating the other team, or through the bomb (section 4.7: on maps with bomb sites the explosion wins it for the attackers and a defuse for the defenders). If time runs out before a plant, the defending side wins, as in CS. If the last players of both teams die in the same moment, the defenders win too (after a plant: the attackers).
- Whoever dies stays dead until the next round. During the round-end pause the survivors can still move and shoot, but the result stands.
- **After you die in a match you spectate** (D-046), like CS, in first person only:
  - For about **2 s** you still see your own view from where you fell, with "Killed by …", so you see who got you.
  - Then the view moves to a living **teammate**: you see exactly what they see (their eyes, their aim, their recoil kick, their muzzle flash), and hear from where they are. Their health, ammo and weapon replace yours on the HUD, and a line at the bottom says "Spectating Bot2 · click for next". No free look.
  - **Left click** switches to the next living teammate. When the one you watch dies, the view moves on to the next one after **1.5 s**. If no teammate is alive, you stay on the last view, where they fell, and watch the end of the round from there.
  - When the next round starts you are back in your own eyes. You can't watch the other team.
- **Round HUD** (D-047, matches only; practice mode shows none of it). Colors are always relative to you: your team blue, the enemy red.
  - **Top bar, top centre:** your score on the left (blue box), the round timer in the middle with "Round 3" under it, their score on the right (red box). Under each score one small square per player, lit while that player is alive. The timer counts the freeze time down (yellow) before the round and then runs from 1:55 (red in the last 10 s); after the round ends it stays where it stopped (0:00 after a time-out).
  - **Freeze time, centre:** "Round 3 · starts in 4", and your side this half: "You attack: push to the far end" or "You defend: hold your end". After half time "Switching sides" is shown above it, and a team one round from winning gets "Match point" (yours, blue), "Enemy match point" (red) or "Match point for both teams" below it.
  - **Round end, centre:** "Round won" (blue) or "Round lost" (red), and why, said for your side: "Enemy team eliminated" / "Your team was eliminated", "Time ran out: you held your end" / "Time ran out: the defenders held their end".
  - **Kill feed, top right:** one line per death, "Killer > Victim" with each name in its team's color and a gold "HS" after a headshot kill; a death without a killer shows only the victim. Lines that involve you (a kill of yours or your own death) have a darker background and a white outline. The newest line is at the bottom, at most 5 lines show, each fades out after 5 s, and the feed starts empty in every round.
- **Scoreboard** (D-050, hold **Tab**, matches only): while you hold the key a panel appears in the middle of the screen, and it is gone when you let go. It never pauses the game, blocks movement or takes mouse clicks, so you can peek at it while moving. At the top "Round 3" and the score, yours in blue and theirs in red; below it both teams as tables, yours first under a blue header, the enemy under a red one. One row per player: name, kills, deaths, assists and damage (rounded), best first (most kills, then most damage, then the order they joined). Your own row is highlighted and marked "(you)". **Players who are dead this round are dimmed**, so you see at a glance who is still alive. The numbers follow the match while you hold it. It stays closed while the developer console is open and once the match is over (the end screen shows the final table, where nobody is dimmed). Practice mode has no scoreboard.
- **Stats** for the scoreboard: kills (a teamkill counts −1), deaths, assists (more than 40 damage to an enemy someone else kills, as in CS) and damage (health actually removed, so a 142-damage headshot on a 30 HP enemy counts 30).
- **Practice** (the main menu's **Practice** button, or `-- --practice`): today's bot arena without rounds, on the test map; bots and you respawn after 3 s, so there is no spectating. The bots fight at the difficulty you last chose in match setup (Normal at first).
- Match: first to **5** (default), **10** or **15** rounds. Sides swap at half time, after 4, 9 or 14 rounds, so a draw is impossible. The teams keep their numbers and colors; only who attacks and who defends flips, so each team starts the next round at the other end of the map. The longest match is 9, 19 or 29 rounds.
- **How a match ends:** when a team wins its 5th (10th, 15th) round, the usual round-end pause still plays so you see how that round was won. Then everyone is frozen and the **end screen** opens over the scene with the mouse free: "Victory" or "Defeat" for your team, the final score ("yours - theirs", your number blue, theirs red), and a scoreboard with your team first (blue) and the enemy team below (red): one row per player with kills, deaths, assists and damage, best first (kills, then damage), your own row highlighted. Buttons: **Play again** (a fresh match on the same map) and **Main menu** (back to the main menu; it was Quit until the menu existed).
- **Spawns:** each side has five spawn points at its own end of the map. On the test map the defenders start at the north end behind the peek walls and the attackers at the south end of the range, 112 m apart.
- Friendly fire is a match setting: off by default; when on, teammates take a third of the damage, like CS competitive. With it off, bullets pass through teammates (as in CS), so a teammate walking through your spray doesn't block it.
- **Modes** (D-049):
  - **Rounds** (today's mode): one life per round, the bomb objective from M8. Like CS, or CoD's Search & Destroy.
  - **Team respawn** (M8, D-082): like CoD's Team Deathmatch. Both teams start at their ends after 5 s of freeze time. You respawn **3 s** after dying, with full health and ammo, at the map's safest respawn point: as far from the living enemies as possible (40 m and more count the same, so far spots take turns), out of their line of sight, preferably near a teammate. Each enemy killed is a point for the killer's team (teamkills and suicides score nothing). The first team to **50 kills** wins (*tune*; D-083: bots-only 3v3 matches score about 20 kills a minute, so this takes about 4 minutes), or the team with more kills after **10 minutes**; a tie goes to **overtime**, where the next kill wins. The top bar shows the kills, "First to 50" under the timer ("OT" and "Next kill wins" in overtime); no bomb and no spectating. Start it with `-- --respawn` until match setup offers it.
- **Maps** (D-049): three small, fast maps in rotation (M8), built for action like CoD's maps rather than CS's long ones. About 40–60 m across, with three lanes and connections between them, first contact within 5–10 s of spawning, and short sightlines. Every map has two bomb sites and spawn zones, so it works in both modes.

### 4.6 Economy

- Money is earned for round wins, round losses (with a loss bonus that grows), kills and objective actions.
- A buy menu is available during freeze time, inside the buy zone.
- Values are modeled on CS *(tune)*.

### 4.7 Bomb mode

Bomb rounds are the round mode on every map with bomb sites (the three quick maps; the test map has none and keeps plain elimination rounds). CS's rules (D-080, *tune*):

- **Carrying:** at each round start a random attacker has the bomb, strapped to their back where everyone can see it. If the carrier dies, it drops where they fell; the first attacker to walk over it picks it up. Defenders can't. Attackers see a dropped bomb's marker through walls (CS shows it on their radar), and get the message "The bomb was dropped".
- **Planting:** hold **Use (E)** inside a bomb site, standing on the floor, for **3.2 s**. You can look around and crouch, but not move or shoot. Letting go starts it over. Defenders within 20 m hear the key presses.
- **After the plant:** the round clock stops and the timer shows "BOMB"; everyone is told the site ("Bomb planted at A") and sees the bomb's marker. The bomb beeps faster and faster (once a second at first, about 8 times a second at the end) and explodes after **40 s**.
- **Defusing:** a defender holds **Use** within **1.5 m** of the bomb for **10 s** (**5 s** with a defuse kit, sold from M7). The same lock and restart rule as planting; only one defender defuses at a time.
- **Winning:** the explosion wins the round for the attackers, a defuse for the defenders. After the plant, killing every attacker doesn't end the round (the defenders still have to defuse), and killing every defender wins it for the attackers at once. Before the plant, the usual rules: elimination, or the defenders on time-out.
- **The blast:** 500 damage at the bomb, falling off like a bell curve: lethal out to about 13.5 m, 50 damage at about 18 m, nothing beyond about 22 m. Walls don't shield. Nobody gets a kill for it.
- **HUD:** a gold "BOMB" tag above your weapon while you carry it; "Hold E to plant" / "Hold E to defuse" under the crosshair where you can; "Planting" / "Defusing" with a progress bar while you do. Freeze time says "You attack: plant the bomb at A or B" or "You defend: guard A and B"; the round-end banner says "The bomb exploded" or "The bomb was defused".

### 4.8 Audio

In a tactical shooter, sound is part of the gameplay. Footsteps and gunshots must be directional and easy to read. They are retro-styled but clear.

- **Your own footsteps** are clearly audible (−12 dB), so you always know when you're making noise, but quieter than enemy steps.
- **Enemy footsteps** are loud and directional and fade out at 30 m, a bit beyond the 25 m at which bots hear you. Hearing is symmetric: you can hear them as far as they can hear you (D-038).
- **Footsteps are bright** (most energy around 1–6 kHz), so they carry on laptop speakers too.
- Walking (Shift) and crouch-walking are silent for everyone.
- While you spectate a teammate (see 4.5) you hear from where they are, as in CS: the listener is the camera, which sits at their head.
- Three volumes (D-058): **master**, **effects** (footsteps, shots, reloads) and **interface** (menus), so the menu or the effects can be turned down on their own.
- **Footsteps sound like the floor** (D-084): hard (concrete, stone, plaster), gravel (a crunch), metal (a ring) and wood (a hollow knock). Same range and loudness on every floor.
- **Bullets** make a sound where they land, heard within 35 m: a crack on hard surfaces, a thud in gravel, a ping on metal, a thock in wood, a thwack on a body, and a bright "dink" on a head, louder and heard farther, like CS's headshot sound.
- **The bomb** beeps faster and faster once planted, and planting (key presses) and defusing (wire clicks) can be heard 20 m away. Everyone hears a two-tone alert when it's planted, and the explosion.
- **Interface:** menu buttons tick on hover and click when pressed; a two-beep "go" starts each round, and short stingers mark a round won (rising) or lost (falling). Game sounds play on the *Effects* bus, interface sounds on *Interface*.
- All sounds are generated by code (D-020), retro and short.

### 4.9 Classes

Four classes, each with its own look and **one passive perk** (D-052). Classes don't restrict weapons: anyone can buy anything, so the economy stays CS-like. The signature gun is only what the class holds in the class menu. You pick a class at match start and can change it during freeze time; bots get a mix. Perks switch on in M7; until then the classes differ only in looks.

| Class *(working name)* | Build and silhouette | Perk *(tune)* | Signature gun |
|---|---|---|---|
| **Rifleman** | 1.82 m, stocky, upright. High-cut helmet, goggles, plate carrier | **Quick Hands:** reloads and weapon switches 15% faster | AK-style rifle |
| **Bulwark** | 1.92 m, broad, slight hunch. Closed helmet with a gas mask, shoulder plates | **Plated:** with armor on, takes 10% less damage than other classes and the armor wears down 30% slower. No effect without armor | Pump shotgun |
| **Marksman** | 1.88 m, lanky. Long coat, hood, scarf | **Steady:** scoped accuracy recovers 30% faster after moving, and scoping in is 20% faster | Sniper rifle |
| **Scout** | 1.72 m, slim. Beanie, balaclava, glowing goggles, a radio with an antenna | **Light Step:** running footsteps carry 70% as far (a deliberate exception to D-038) | SMG |

- **Silhouette first** (D-053): height, build, posture and headgear make each class recognisable at a glance, even as a dark shape.
- **Team colour** is painted at runtime: every class wears a neutral kit (greys, olive-greys, charcoal; never desert tones, D-031) with team-colour parts such as jacket panels, armbands and a helmet stripe. They show blue on your team and red on the enemy team (D-041).
- **Hit zones follow each body** (D-055): the Bulwark is the biggest target and the Scout the smallest. Perks balance the difference.

## 5. Look and feel

The target is the era of Quake (1996) and Counter-Strike 1.x (1999–2003).

- Low internal render resolution (480 lines), upscaled crisply so pixels stay sharp (D-027, D-048).
- Pixelated textures with nearest-neighbor filtering, so no smoothing. Anisotropic filtering keeps floors sharp into the distance.
- Simple geometry: blocky architecture and low-poly models.
- Characters and weapons: minimalistic and pixelated, in a CS/Quake/CoD-like style. Low-poly models built from rigid pieces, like late-90s shooters, with palette-limited pixel textures, made by a generator (D-054). First person shows 3D arms and gun (D-051).
- World image limited to 16 shades per color channel with light ordered dithering (D-030, D-048).
- Lighting: cool daylight (D-031): neutral white sun, long shadows, light grey-blue haze, warm accents only from lamps and wood. Deliberately *not* a desert/dust look, so Chiip doesn't read as a Counter-Strike copy. Lighting is real-time, with no baked lightmaps (D-085): flat, readable light that keeps the maps editable.
- **Menus and UI** (D-057): one pixel-art look for every menu, the Silkscreen font with square panels and buttons, crisp 2 px borders and no rounded corners or smoothing. Cool dark blue-grey panels, light text and a single icy cyan accent for focus, selection and sliders; team blue and red only mark teams. Deliberately not Counter-Strike's orange and yellow on black. Everything is drawn for a 720-pixel-tall window and scales by the window height (exactly 1.5× at 1080, 2× at 1440), and text sizes sit on the font's pixel grid (16 / 32 / 48 px) so pixels stay whole. The in-game HUD keeps its own simple look.
- **Clarity rule:** enemies must always stand out from the background.

## 6. Controls (default)

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Shoot / scope | Left mouse / right mouse |
| Next teammate (while dead in a match) | Left mouse |
| Jump | Space or mouse wheel down |
| Crouch | Ctrl |
| Walk (silent) | Shift |
| Reload | R |
| Weapons | 1 primary, 2 pistol, 3 knife, 4 grenades, 5 bomb |
| Use: plant / defuse the bomb (hold) | E |
| Buy menu | B |
| Scoreboard (hold, in a match) | Tab |
| Developer console | ` (backtick / tilde key) |
| Pause menu (frees the mouse) | Esc (fixed); Esc again resumes |
| Capture the mouse again (after alt-tab, with no menu open) | Click in the window |
| Settings menu | The main menu's Settings button, the pause menu's Settings button, or the console command `settings` in the game |
| Debug overlay | F3 |

Keys are bound by physical position, so they stay in the same place on any keyboard layout (e.g. Czech QWERTZ). These are the defaults: every action except Esc can be rebound (each with a second key or button) in the settings menu, see section 7; a key belongs to one action, so binding it takes it away from the one that had it, as in CS. Open question: macOS may treat Ctrl + click as a right click, which would clash with crouch + shoot. This is checked in M1 (see [DECISIONS.md](DECISIONS.md)).

## 7. Settings that matter to CS players

Settings are saved in a file (`settings.cfg` in the game's user data folder, D-058) the moment they change and apply at once, with no Apply button. They are the player's own, never part of the match rules. The settings menu (D-059; the main menu's and the pause menu's Settings buttons and the console command `settings` open it) edits them in tabs for Game, Video, Audio, Crosshair and Controls, and the console commands `sensitivity`, `fov`, `volume`, `fps_max` and `settings_reset` do too: whichever changes a value, the other follows. "Reset tab to defaults" in the menu puts one tab back. Defaults are today's behaviour. The file also remembers your last match setup (team sizes, difficulty, length, friendly fire, map; D-064), in its own `[match]` section: those are choices for the next match, not settings of the game, and the menu's "Reset tab" doesn't touch them (the console's `settings_reset` does).

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
| Audio | Master, Effects (footsteps and shots) and Interface (menus) volume, each on its own audio bus | 1.0 each | 0 – 1 |
| Crosshair | Color (swatches or a hex code) and opacity, size (line length), gap, thickness, outline, center dot and dynamic, like CS's crosshair settings; the menu shows a live preview on a dark and a light background (the sizes are in pixels at 720p and scale with the window) | green, 7 px, gap 4, thickness 2, outline on, no dot, static (D-021) | size 1 – 30, gap 0 – 20, thickness 1 – 8 |
| Controls | Keys and mouse buttons of move, jump, crouch, walk, shoot, aim, reload, scoreboard, debug overlay and console, each with a primary and a secondary binding; Esc stays fixed. A key is bound by physical position (D-012). In the menu you click a slot and press the new key or mouse button (Esc cancels, Backspace clears the slot). **A key belongs to one action:** binding it takes it from whatever had it, and the menu says which action lost it (D-059) | section 6 | |

- The crosshair was built in M2 (`ui/crosshair.gd`, D-021). Dynamic mode widens the gap to match the actual inaccuracy cone, e.g. +38 px at 720p for 4.5°.
- A value outside its range is clamped; the file can be edited by hand, and anything unreadable falls back to the default.
- *Later:* viewmodel (weapon) position.

## 8. Out of scope for now

Matchmaking, ranked mode, skins and cosmetics, mobile.

Multiplayer *is* planned, as M9 after the single-player game: one player hosts, friends join and bots fill empty slots (D-033).
