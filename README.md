# Ultrajump

A base for a 3D platformer with a deep, expressive, momentum-driven moveset in
the spirit of Super Mario 64, rebuilt on a modern engine without the old
constraints. It includes a character controller with punches and kicks, a
procedurally animated placeholder character, a calm platforming camera, and a
**movement gym**: a test level full of challenges, stars and coins, with debug
tools for tuning how everything feels.

Built with **Godot 4.7** (4.7.2 stable), GDScript, Jolt physics.

![A kick smashing a crate, a pillar hop over lava, a bounce pad launch and the parkour time trial](docs/screenshot.png)

## Getting started

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build; no .NET needed).
2. Open the project (`project.godot`) and press **F5** to play.
3. Press **F1** in game to show or hide the controls, move list and stations.

## Controls

| Action | Keyboard & mouse | Gamepad |
| --- | --- | --- |
| Move | WASD | Left stick |
| Camera | Mouse, arrow keys | Right stick |
| Jump | Space | A |
| Crouch / ground pound | Shift, C | LT, RT, B |
| Attack / dive | E, left click | X |
| Spin | Q, right click | Y, RB |
| Walk (slow) | Ctrl | (tilt the stick less) |
| Recenter camera | Tab, middle click | LB |
| Respawn (last checkpoint) | R | Back |
| Free / capture the mouse | Esc / click | Start |

All bindings live in *Project Settings → Input Map*.

## Moveset

| Move | How |
| --- | --- |
| Run | Speed builds along your facing direction. Turns are tight when slow and wide when fast. |
| Skid & **side flip** | Reverse the stick at speed to skid; jump during the skid to side flip, or attack to turn and punch. |
| **Single / double / triple jump** | Jump again right as you land. The third jump needs running speed. Hold jump longer to jump higher. |
| **Backflip** | Crouch while standing, then jump. With your back against a ledge lower than the flip, it carries you up onto it. |
| Crouch slide & **long jump** | Crouch while running to slide (slopes speed you up), then jump. Keep crouch held when you land to chain another: chained long jumps build up to their top speed. |
| **Punch, punch, kick** | Attack on the ground. Keep pressing for the full combo; jump to cancel out of it. |
| **Slide kick** | Attack during a crouch slide: a low, fast kick along the ground. |
| **Dive** & **rollout** | Attack in the air, or while sprinting at full speed. Land in a belly slide and jump to roll out. Diving head-first into a wall bonks you. |
| **Ground pound** | Crouch in the air. Jump the moment you land for the **ground pound jump**, or attack during it to cancel into a dive. |
| **Wall kick** | Hit a wall mid-air at speed and jump *right as you touch it*: you have 0.12 s after the hit (a press up to 0.05 s early counts too). Miss the moment and you bounce off, and that wall won't take you again until you land (or kick off another wall). Kick back and forth between two walls to climb. |
| **Ledge grab** | Jump at a ledge to hang. Push toward it to climb, jump to hop up, pull away or crouch to drop. Barely missed ledges are mantled automatically. |
| **Air spin** | Spin in the air for a little lift and extra control, once per jump. Spinning on the ground hits things around you. |
| Steep slopes | Slopes steeper than 46° make you slide; jump to hop off. |
| Also | Coyote time, jump buffering, stair stepping, moving platforms, variable jump height. |

Punches, kicks, dives, slide kicks, spins and ground pounds all hit things:
they break crates, and anything else that implements `take_hit()` (see
[How attacks hit things](#how-attacks-hit-things)).

## The movement gym

The default scene is a grey-box test level with a 1 m grid (bold every 5 m) on
every surface, so heights and distances can be read at a glance. Press
**1–9** and **0** for the first ten stations, **PgUp / PgDn** to cycle
through all of them:

| # | Station | What's there |
| --- | --- | --- |
| 1 | **Spawn** | A ring of coins. |
| 2 | **Jump heights** | Pillars from 1 m to 7 m. |
| 3 | **Long jump runway** | Gaps of 6, 8, 10 and 12 m. The last two need chained long jumps. ★ |
| 4 | **Wall kicks** | A 16 m shaft (★ on the roof), and a wall with small ledges. |
| 5 | **Slopes & stairs** | 15°, 30°, 45° and 55° ramps, two flights of stairs, a slide hill. |
| 6 | **Ledges** | 2.4 m (mantle), 3.2 m and 4.0 m (grab). |
| 7 | **Crate yard** | Eight crates, some stacked, some hiding coins. Break them all for a ★. |
| 8 | **Moving platforms** | A shuttle, an elevator and a spinner. |
| 9 | **Tower course** | A spiral of steps up a 20 m tower. ★ |
| 0 | **Parkour time trial** | Steps, a long jump, a wall kick chimney, drops and a shuttle over lava, against the clock. Beat 30 s for the ★. |
| · | **Wall kick chimney** | 22 m of timed wall kicks. ★ |
| · | **Pillar hop** | Eight narrow pillars over lava. ★ |
| · | **Sky islands** | Bounce pads (ground pound onto one to go higher) up to floating islands. ★ |
| · | **Backflip cliffs** | Three 4.5 m steps, one backflip each. ★ |

There are **9 stars** and plenty of coins; the counters sit at the top of the
screen. Lava sends you back to the last **checkpoint** flag you touched
(teleporting to a station also sets it). Every challenge is checked by
`tests/gym_tests.gd`, which plays through each one and collects its star.

## The camera

The camera is built to stay calm and predictable:

- It only turns when you turn it. Swinging behind the player on its own is
  available, but off: see *Auto Align* on the `PlayerCamera` node.
- On the ground it follows closely. In the air it holds its height until you
  climb or fall out of a comfortable band, so jump arcs read clearly and small
  hops don't bob the view.
- When a wall gets in the way it slides in quickly but never snaps, and eases
  back out once the view has stayed clear for a moment.
- The field of view only widens at very high speed (long jumps), and slowly.

`tests/camera_metrics.gd` drives scripted runs through the gym without
touching the camera and measures how much it moved on its own: rotation nobody
asked for, jumps in distance, how far the character drifts from the center of
the screen, and FOV swings.

## Tuning the feel

Every number behind the movement lives in one resource,
`player/default_movement.tres` (script: `player/movement_settings.gd`). Jump
strengths are written as the height they reach, in meters, rather than as raw
velocities, so they stay meaningful when you change gravity. The wall kick
timing and the attacks have their own groups (*Wall Kick*, *Attacks*). For
example, raise `ground_dive_min_speed` above the run speed to make the attack
button always punch on the ground.

In game:

| Key | Tool |
| --- | --- |
| **F2** | **Tuning panel**: a slider for every setting, grouped by move, applied instantly. **Save** writes the values back to the `.tres` (when running from the editor). **Revert** reloads the saved values, **Defaults** restores the script defaults. |
| **F3** | Slow motion: cycles 1×, 0.5×, 0.25×, 0.1×. |
| **F4** | Trajectory trail: your recent path, colored by move. |
| **F5** | Hide or show the readout (state, speed, jump chain and the height, distance and airtime of your last jump). |

You can also select the Player in the editor and edit its `settings` in the
inspector; each value has a tooltip. Camera settings are on the
`PlayerCamera` node.

## Project layout

```
main/                 Entry scene: level + player + camera + HUD, respawn and stations
  game_state.gd       Autoload: coins, stars, checkpoint, time trials
  warm_up.gd          Loading cover that precaches sounds and shaders
player/
  player.gd           CharacterBody3D: input buffering and the helpers states share
  player_input.gd     Per-tick input snapshot (camera-relative; can be scripted)
  movement_settings.gd, default_movement.tres
  states/             One node per state, run by state_machine.gd
    ground_state.gd, air_state.gd   Shared ground / airborne behavior
  model/              Procedural character: look and animation
  effects/            Particles and sound effects
camera/               Third-person platforming camera
levels/
  movement_gym.tscn   The test level
  props/              Blocks, moving platforms, coins, stars, crates, bounce
                      pads, hazards, checkpoints, time trial gates
audio/                Synth: generates the placeholder sound effects
ui/                   HUD, debug readouts and tuning panel
debug/                Trajectory trail
tests/                Headless test suites
tools/                Script that generated the movement gym
```

### Engine setup

- **Jolt** physics, stepped at **120 Hz** with **physics interpolation** on,
  so movement is responsive and smooth at any frame rate. The camera follows
  the interpolated transform every rendered frame.
- **Forward+** renderer, 4× MSAA. The character's collider is a cylinder
  (flat feet: stable on ledge edges, predictable on steps).
- Physics layers: 1 = World (everything the player and camera collide with),
  2 = Player, 3 = Hittable (what attacks hit), 4 = Pickups.
- One autoload, **`GameState`**, holds the run's progress and announces
  changes with signals; the HUD only listens to it.

### No first-time stutter

Godot compiles a material's shaders the first time it is drawn, and the
level's sounds are synthesized the first time they play. Left alone, that
stalls a frame the first time you land a ground pound, grab a coin, smash a
crate or collect a star. So the game starts behind a brief black cover
(`main/warm_up.gd`) that:

- builds every procedural sound (`Synth.prepare()`),
- draws one of each effect right in front of the camera for a few frames
  (particles, the ground pound shockwave, crate debris, a collected star, a
  raised checkpoint flag) so their shaders and pipelines compile then,
- draws every character the HUD's clock and notifications use,

then clears them away and fades in. Materials already in the level compile
while it loads. If you add an effect or a material that first appears
mid-game, give it a `warm_up()` and call it from `WarmUp.run()`;
`tests/first_use_check.gd` (below) tells you if anything still compiles
during play. Godot also keeps shader and pipeline caches on disk, so later
launches load faster.

### How the character is put together

- **`Player`** holds what every state shares: the input snapshot and press
  buffers (coyote time, jump buffering), and helpers such as `run_move()`,
  `air_move()`, `apply_gravity()`, `find_ledge()`, `strike()` and stair
  stepping.
- **States** (`player/states/`) are small nodes under `Player/StateMachine`,
  one per move. Each implements `enter()`, `physics_update()` and `exit()`, and
  hands over with `transition_to(&"StateName", {message})`. Most build on
  `GroundState` or `AirState`; an air state mostly sets a few flags (gravity
  scale, air control, what it can cancel into) in `enter()`.
- **Visuals, sound and particles only listen** to the player's signals
  (`jumped`, `landed`, `attacked`, `state_changed`, …) and never affect
  movement. Replace `player/model` with an imported, animated character
  without touching gameplay code.
- **`PlayerInput`** is the only place that reads devices. Set
  `player.input.scripted = true` to drive the character from code: the tests
  do this, and it works the same way for replays, cutscenes or AI.

### How attacks hit things

An attack calls `player.strike()` while it's active, which checks a sphere in
front of (or around) the player for bodies and areas on the **Hittable**
layer. Anything found gets `take_hit(hit)` called once per attack, with
`hit.kind` (`&"punch_1"`, `&"kick"`, `&"dive"`, `&"ground_pound"`, …),
`hit.direction`, `hit.position` and `hit.attacker`. To make an enemy or a
switch, put it on layer 3 and give it a `take_hit(hit: Dictionary)` method.

### Adding a move

1. Add a setting group for it in `movement_settings.gd`.
2. Create `player/states/my_move.gd` extending `AirState` (or `GroundState` /
   `PlayerState`), and add a node with that script under
   `Player/StateMachine` in `player/player.tscn`.
3. Trigger it from an existing state with `transition_to(&"MyMove")`.
4. Give it a pose in `player_model.gd` (`_animate`) and optionally a sound in
   `player_audio.gd`.
5. Add a test in `tests/movement_tests.gd`.

## Tests

Four headless suites and one on-screen check; run them from the project
folder. The exit code is the number of failed checks.

```sh
# Every move: heights against the settings, distances, timed wall kicks,
# the punch combo, ledges, stairs, slopes, moving platforms and more.
godot --headless --fixed-fps 120 -s res://tests/movement_tests.gd

# The props: coins, stars, crates (and stacks), bounce pads, lava,
# checkpoints and time trials.
godot --headless --fixed-fps 120 -s res://tests/gameplay_tests.gd

# Plays every challenge in the gym and collects all nine stars.
godot --headless --fixed-fps 120 -s res://tests/gym_tests.gd

# How much the camera moves on its own (--strict fails past the comfort limits).
godot --headless --fixed-fps 60 -s res://tests/camera_metrics.gd -- --strict

# First-time stutter: plays one of every effect-triggering event and reports
# anything compiled during play and the slowest frame. Needs a real renderer
# (no --headless); it opens a window.
godot --fixed-fps 60 -s res://tests/first_use_check.gd
```

Expected values are read from the settings, so the movement tests keep
passing while you tune; the gym suite tells you if a change makes a challenge
impossible.

## Rebuilding the gym

`levels/movement_gym.tscn` was generated by `tools/build_movement_gym.gd`.
Edit the scene directly: blocks and props are `@tool` nodes whose shape, size
and color update live in the editor. Re-running the script **overwrites** the
scene:

```sh
godot --headless -s res://tools/build_movement_gym.gd
```

## Ideas for what's next

- Replace the placeholder model and synthesized sounds with real assets.
- Enemies built on `take_hit()`, and a few real levels using the props.
- More moves: swimming, poles and ropes, cap-throw-style tools, rolling.
- Save stars, coins and best times between sessions.
- Tune the numbers with the F2 panel until it feels right.
