# Red Ace — Development Roadmap

A WWI-inspired arcade dogfighting game built in Godot 4.7 (3D, Jolt physics), loosely inspired by *Master of the Skies: The Red Ace*.

**Goal: a complete, commercial release on Steam.**

Check items off as they're completed. Milestones are ordered so that each one produces something playable.

---

## 0. Pre-production & Foundations

### Design
- [ ] Write a one-page game pitch (tone, setting, target platform, scope)
- [ ] Decide fictional vs. historical setting (factions, nations, plane names)
- [ ] Define core pillars (e.g. "dogfights feel great", "missions are short and varied", "progression keeps you going")
- [ ] Define control schemes: keyboard+mouse, gamepad, joystick
- [ ] Decide target platforms — Steam release: Windows (primary), Steam Deck, optionally Linux / macOS
- [ ] Define difficulty philosophy (arcade assists vs. realistic toggles)
- [ ] Create a rough art direction moodboard (palette, low-poly vs. realistic, sky style)
- [ ] Create an audio direction reference (engine sounds, music style)

### Project setup
- [x] Initialize git repository and first commit
- [x] Set up folder structure (`scenes/`, `scripts/`, `assets/`, `data/`, `ui/`, `audio/`)
- [x] Configure input map (pitch, roll, yaw, throttle, fire, bomb, camera, pause)
- [ ] Set up autoload singletons (GameState, SaveManager, AudioManager, SceneLoader)
- [ ] Choose code conventions (GDScript style, naming, signals vs. direct calls)
- [x] Set up physics layers and collision masks (player, enemy, bullets, ground, targets)
- [x] Set up a debug overlay (FPS, speed, altitude, AI state, toggles)
- [x] Set up a test/sandbox scene for rapid iteration

---

## 1. Milestone: Flight Prototype ("Does flying feel good?")

### Flight model
- [x] Plane controller script (arcade physics: thrust, drag, lift, gravity)
- [x] Pitch / roll / yaw control with tunable rates
- [x] Throttle control with min/max speed
- [x] Speed-dependent control authority (sluggish when slow)
- [x] Stall behavior at low speed (nose drop, recovery)
- [x] Ground collision and crash detection
- [ ] Takeoff and landing support (or air-start option)
- [x] Tunable per-aircraft stats resource (speed, turn rate, climb rate, health)
- [ ] Optional assists: auto-level ✅, stall warning ✅, auto-throttle

### Camera
- [x] Chase camera with smoothing/lag
- [x] Cockpit camera
- [x] Free look (mouse/right stick)
- [ ] Target-lock camera (look at nearest enemy / padlock view)
- [x] Camera shake on damage and gunfire
- [x] Field-of-view change with speed

### Test environment
- [x] Simple heightmap terrain
- [x] Sky (procedural sky / skybox) and sun lighting
- [x] Distance fog
- [x] World boundary handling (turn-back warning or invisible wall)
- [x] Placeholder biplane model built from primitives

---

## 2. Milestone: Combat Prototype ("Is dogfighting fun?")

### Weapons
- [x] Machine guns (fast projectiles or raycasts) with tracers
- [x] Fire rate, spread, and bullet travel time
- [x] Gun overheating / jamming mechanic
- [x] Ammo count
- [ ] Ammo resupply rules (e.g. land at friendly airfield)
- [x] Bombs (drop physics, explosion radius) with a bomb sight
- [ ] Optional: rockets (Le Prieur style) for balloon busting
- [x] Hit detection and hit feedback (sparks, hit marker)
- [ ] Hit sounds (see Audio)

### Damage model
- [x] Health system per aircraft
- [x] Component damage (engine, wings, tail, pilot) affecting handling
- [x] Visual damage states: smoke and fire
- [ ] Visual damage states: bullet holes, missing parts
- [x] Death states: explode, spiral down, crash-land
- [x] Player bail-out / mission failure on death

### Enemy AI (air)
- [x] AI state machine: patrol → detect → engage → evade → flee/retreat
- [x] Pursuit steering (lead target, get on tail)
- [x] Defensive maneuvers (break turns, climbs, dives)
- [x] Terrain avoidance
- [x] Accuracy / reaction tuned by skill level (rookie, veteran, ace)
- [ ] Wingman/formation flying
- [x] Target selection (player vs. allies)
- [ ] Named enemy aces with unique behavior (boss fights)
- [ ] Smarter tactics: climbing/diving attacks, energy fighting (evenly matched AIs currently circle forever)

### HUD (prototype)
- [x] Speed and altitude indicators
- [x] Throttle indicator
- [x] Gun heat / ammo gauge
- [x] Health / damage indicator
- [x] Crosshair and lead indicator (optional assist)
- [x] Off-screen enemy arrows
- [ ] Simple radar or compass

---

## 3. Milestone: Mission System ("One complete mission")

### Mission framework
- [x] Mission format: each mission is a scene with Objective nodes, built in the editor
- [ ] Objective types:
  - [x] Destroy all enemy aircraft
  - [x] Destroy ground targets (tanks, AA guns, trucks, trains)
  - [x] Bomb a structure (factory, bridge, depot)
  - [x] Destroy observation balloons
  - [ ] Escort / protect a friendly (bomber, recon plane)
  - [ ] Defend a location (airfield, trench line)
  - [x] Reach waypoint
  - [ ] Recon photo
  - [ ] Rescue / cover downed pilot
  - [ ] Duel a named ace
- [x] Primary vs. optional (bonus) objectives
- [x] Objective-complete triggers (next objective starts, enemies spawn)
- [ ] More triggers: area enter, timers
- [x] Wave/spawn system for enemies
- [x] Mission success/failure conditions
- [x] Mission timer and scoring
- [x] In-mission radio messages / dialogue lines

### Ground units & structures
- [x] Tanks (moving along paths)
- [x] AA guns with flak bursts (shoot at player)
- [x] Trucks / convoys
- [ ] Trains
- [x] Observation balloons
- [x] Buildings: supply sheds, fuel tanks (destructible)
- [ ] More buildings: factories, hangars, bridges
- [ ] Trenches and infantry (visual dressing)
- [ ] Friendly airfield (landing/repair zone)

### Mission flow
- [x] Briefing screen (map, objectives)
- [ ] Plane select on briefing
- [x] Loading screen
- [x] In-mission pause menu (resume, restart, settings, quit)
- [x] Debriefing screen (score, kills, accuracy, rank progress)

---

## 4. Milestone: Campaign & Progression ("Vertical slice")

### Campaign
- [ ] Campaign structure: ~3 theaters × ~8 missions (≈25 missions)
- [ ] Mission unlock order
- [ ] Story outline (protagonist, rival ace, war arc)
- [ ] Inter-mission story text / cutscene stills
- [ ] Theater 1 missions (tutorial-ish, easy)
- [ ] Theater 2 missions (mid difficulty, new mechanics)
- [ ] Theater 3 missions (hard, final ace duel)
- [ ] Final boss mission

### Progression
- [ ] Rank system (e.g. Corporal → Colonel) with thresholds
- [ ] Medals / awards for achievements
- [ ] Aircraft unlocks tied to rank/campaign progress
- [ ] Optional: aircraft upgrades (engine, guns, armor)
- [ ] Optional: plane paint schemes / liveries
- [ ] Pilot stats tracking (kills, missions, accuracy)

### Aircraft roster (fictionalized WWI-inspired)
- [ ] Starter pusher fighter (DH.2-inspired)
- [ ] Light agile scout (Bristol Scout-inspired)
- [ ] Nimble dogfighter (Camel-inspired)
- [ ] Fast sturdy fighter (SPAD-inspired)
- [ ] Late-game top fighter
- [ ] Two-seater with rear gunner (optional)
- [ ] Enemy fighter types (Fokker / Albatros-inspired)
- [ ] Enemy bombers (Gotha-inspired) and zeppelins
- [ ] Distinct handling stats for each

---

## 5. World & Environments

- [ ] Terrain tooling (heightmap import, or Terrain3D plugin)
- [ ] Theater 1 map (e.g. green farmland)
- [ ] Theater 2 map (e.g. muddy trench front / no man's land)
- [ ] Theater 3 map (e.g. mountains, coastline, or snow)
- [ ] Terrain texturing (splat maps: grass, mud, rock, roads)
- [ ] Vegetation (trees, hedges) with LOD / multimesh
- [ ] Villages, farms, churches, windmills
- [ ] Rivers and lakes (water shader)
- [ ] Volumetric or billboard clouds (fly through them)
- [ ] Time of day variants (dawn, noon, dusk)
- [ ] Weather variants (clear, overcast, rain, fog)
- [ ] Map boundaries that look natural

---

## 6. Art & Visual Effects

### Models
- [ ] Final player aircraft models (low-poly, consistent style)
- [ ] Enemy aircraft models
- [ ] Animated parts: propeller, control surfaces, pilot head
- [ ] Ground vehicles, guns, balloons, zeppelins
- [ ] Buildings and props (destroyed variants)
- [ ] Cockpit interiors with gauges

### VFX
- [ ] Muzzle flash and tracers
- [ ] Bullet impacts (dirt, wood, metal, water)
- [ ] Explosions (air and ground)
- [ ] Flak bursts
- [ ] Smoke and fire trails from damaged planes
- [ ] Engine exhaust
- [ ] Wingtip vapor / speed lines (optional)
- [ ] Debris and falling parts
- [ ] Crash dust/fire on ground

### Rendering
- [ ] Lighting and shadow setup per map
- [ ] Post-processing (bloom, color grading, slight film grain for period feel)
- [ ] LOD for aircraft and terrain
- [ ] Performance budget (draw calls, poly counts)

---

## 7. Audio

- [ ] Engine sound loop with pitch/volume tied to throttle and speed
- [ ] Unique engine sounds per aircraft type
- [ ] Machine gun sounds (player and enemy, distance falloff)
- [ ] Bullet hits / ricochets / whizz-by sounds
- [ ] Explosions, flak, bombs
- [ ] Wind noise based on speed
- [ ] Stall / damage warnings, engine sputter
- [ ] 3D positional audio for enemies
- [ ] UI sounds (menu clicks, rank up, medal)
- [ ] Music: main menu theme
- [ ] Music: in-mission (calm/combat dynamic switching)
- [ ] Music: victory / defeat stingers
- [ ] Radio voice lines (optional, or text-only)
- [ ] Audio bus setup and mixing (Master, Music, SFX, Voice)

---

## 8. UI & Menus

- [ ] Title / splash screen
- [x] Basic main menu (Mission 1, Free flight, Quit)
- [ ] Full main menu (Campaign, Quick Battle, Settings, Credits, Quit)
- [ ] Campaign map / mission select screen
- [ ] Hangar screen (choose plane, view stats, liveries)
- [ ] Briefing and debriefing screens (final art)
- [ ] Pilot profile / service record (rank, medals, stats)
- [ ] Settings menu:
  - [ ] Graphics (resolution, fullscreen, quality presets, vsync)
  - [ ] Audio (volume sliders per bus)
  - [ ] Controls (rebinding, sensitivity, invert Y)
  - [ ] Gameplay (difficulty, assists, HUD options)
- [ ] Final HUD art and layout
- [ ] Controller-navigable menus
- [ ] Credits screen
- [ ] Consistent UI theme (period-style fonts, paper/leather textures)

---

## 9. Extra Game Modes (post-campaign)

- [ ] Quick Battle / Instant Action (pick plane, enemies, map)
- [ ] Survival / endless waves mode
- [ ] Ace duel mode (1v1 against named aces)
- [ ] Training / tutorial missions
- [ ] Optional: play the enemy side (like *Red Ace Squadron*)
- [ ] Optional: local split-screen
- [ ] Optional: online multiplayer (dogfight, co-op)

---

## 10. Systems & Tech

- [ ] Save/load system (campaign progress, unlocks, settings)
- [ ] Multiple save slots
- [x] Scene loading with progress (threaded loading)
- [x] Object pooling for bullets, effects, debris
- [ ] Input handling for keyboard/mouse, gamepad, joystick (with dead zones)
- [ ] Rumble / haptics for gamepad
- [ ] Pause handling (process modes)
- [ ] Localization support (string tables) — even if English only at first
- [ ] Accessibility: subtitles, colorblind-safe HUD, remappable controls
- [ ] Error logging and crash handling

---

## 11. Balancing & Playtesting

- [ ] Tune flight model per aircraft
- [ ] Tune AI difficulty curve across campaign
- [ ] Tune weapon damage, heat, and ammo
- [ ] Tune scoring and rank progression pace
- [ ] Difficulty levels (Easy / Normal / Hard / Ace)
- [ ] Internal playtest passes per milestone
- [ ] External playtests with feedback form
- [ ] Fix pacing issues in missions (too long, too empty, too hard)

---

## 12. Optimization & QA

- [ ] Profile CPU (AI, physics, bullets)
- [ ] Profile GPU (terrain, vegetation, clouds, particles)
- [ ] Hit target framerate on minimum-spec hardware
- [ ] Test on all target platforms
- [ ] Test all input devices
- [ ] Bug tracking list and triage
- [ ] Full campaign playthrough without blockers
- [ ] Save compatibility testing
- [ ] Edge cases: alt-tab, resolution changes, controller disconnect

---

## 13. Legal & Business (start early)

- [ ] Final game name — check it doesn't conflict with existing trademarks or Steam titles ("Red Ace" is taken by the original series)
- [ ] Use fictional names for aircraft/factions, or verify real manufacturer names are safe to use
- [ ] Every third-party asset (models, textures, sounds, music, fonts) has a license allowing commercial use — keep a license log
- [ ] Godot engine MIT license notice included in credits/about
- [ ] Decide release as individual or registered business
- [ ] Privacy policy (needed if any data/analytics is collected)
- [ ] EULA (Steam's default is fine unless you need more)

---

## 14. Steam Integration

- [ ] Steamworks partner account (identity, bank and tax info)
- [ ] Pay Steam Direct app fee ($100 per game, recouped after $1,000 in revenue)
- [ ] Integrate Steamworks SDK (e.g. GodotSteam addon)
- [ ] Steam achievements (design list, icons, wire up triggers)
- [ ] Steam Cloud saves
- [ ] Steam Input / controller configuration
- [ ] Steam leaderboards (optional: score per mission, survival mode)
- [ ] Steam Deck: test, readable UI at 1280×800, gamepad-only playable, aim for "Verified"
- [ ] Rich presence (optional)
- [ ] Set up depots and upload builds via SteamPipe
- [ ] Beta branch for testers
- [ ] Content survey and age ratings questionnaire completed

---

## 15. Steam Store Page & Marketing

- [ ] Capsule art in all required sizes (header, small, main, vertical, library hero, logo)
- [ ] 5+ screenshots that show gameplay (not menus)
- [ ] Gameplay trailer (first 5 seconds show action)
- [ ] Short and long descriptions, tags, system requirements
- [ ] Publish a "Coming Soon" page early (months before launch) to collect wishlists
- [ ] Playable demo
- [ ] Join a Steam Next Fest with the demo
- [ ] Devlog / social media presence (YouTube, X/Bluesky, Reddit, TikTok)
- [ ] Discord server for community and playtesters
- [ ] Press kit and outreach to content creators / press
- [ ] Decide price, regional pricing, and launch discount
- [ ] Store page submitted for Valve review (allow several business days)
- [ ] Build submitted for Valve review before launch (allow several business days)

---

## 16. Release

- [ ] Game icon, window title, and version number
- [ ] Windows export (primary), plus Linux / macOS if supporting them (macOS needs code signing + notarization)
- [ ] Credits including all third-party asset attributions
- [ ] Release candidate build passes full QA checklist
- [ ] Changelog / patch notes
- [ ] Launch day: set release live, post announcement, monitor reviews and forums
- [ ] Hotfix plan for the first week

---

## 17. Post-Launch (optional)

- [ ] Bug fix patches based on player reports
- [ ] Respond to Steam reviews and community discussions
- [ ] New missions / theater DLC
- [ ] New aircraft
- [ ] Mod support / Steam Workshop (custom missions via data files)
- [ ] Seasonal sales participation
