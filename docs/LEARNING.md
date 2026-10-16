# Learning Godot, coming from Unity

> Notes on Godot concepts as Chiip uses them. Each milestone adds a section with what was new and where it's used in the project.
>
> Last updated: 2026-10-16

## Unity → Godot cheat sheet

| Unity | Godot | Notes |
|---|---|---|
| GameObject | Node | Everything in Godot is a node in a tree |
| Component | Child node | A node has one script; extra behaviour is added as child nodes |
| Prefab | Scene (`.tscn`) | Any scene can be instanced inside another scene |
| Scene | Scene | Same file type as a "prefab": a level is just a bigger scene |
| MonoBehaviour | Script attached to a node | `extends CharacterBody3D`, `extends Node3D`, … |
| `Awake()` / `Start()` | `_init()` / `_ready()` | `_ready()` runs once the node and its children are in the tree |
| `Update()` | `_process(delta)` | Runs every frame |
| `FixedUpdate()` | `_physics_process(delta)` | Fixed rate, 60 Hz by default. Movement and shooting go here |
| `[SerializeField]` / public field | `@export var` | Shows the variable in the Inspector |
| ScriptableObject | Resource (`.tres`) | Data files, e.g. weapon stats |
| UnityEvent / C# event | Signal | `signal died`, then `died.emit()` and `died.connect(...)` |
| Singleton / `DontDestroyOnLoad` | Autoload | Global nodes that survive scene changes |
| Tags | Groups | `add_to_group("bots")`, `get_tree().get_nodes_in_group("bots")` |
| Layers | Physics layers and masks | Named in Project Settings |
| CharacterController | `CharacterBody3D` + `move_and_slide()` | |
| `Physics.Raycast` | `RayCast3D` node or `intersect_ray()` | |
| NavMesh / NavMeshAgent | `NavigationRegion3D` / `NavigationAgent3D` | |
| Canvas / UI | Control nodes (under a `CanvasLayer`) | |
| Input Manager / Input System | Input Map + the `Input` singleton | Actions defined in Project Settings |
| `GetComponent<T>()` | `get_node("Path")` / `$Path` | Often stored with `@onready var` |
| `Instantiate(prefab)` | `scene.instantiate()` + `add_child()` | |
| `Destroy()` | `queue_free()` | |
| Coroutines / `yield` | `await` | e.g. `await get_tree().create_timer(1.0).timeout` |
| Animator | `AnimationPlayer` / `AnimationTree` | |
| Shader Graph | Visual Shader / Godot shading language | |
| Asset Store | Asset Library (AssetLib) | Free, open-source plugins |

## Key differences to keep in mind

- **Node tree instead of GameObject + components.** You build behaviour by combining nodes, not by stacking components on one object.
- **No prefab/scene split.** A scene can be a whole level or a single bullet hole.
- **Axes:** Y is up (same as Unity), but forward is −Z (Unity's forward is +Z).
- **GDScript looks like Python:** indentation instead of braces, `func`, `var`, with optional static types (which we always use in Chiip).
- **Small editor, fast iteration:** the editor starts in seconds and scripts reload without recompiling.

## Milestone notes

### M1 — Project setup & movement

**The project file and `res://`**
- A Godot project is just a folder containing `project.godot`, a text file holding all project settings (Unity spreads these across many `ProjectSettings/*.asset` files). You edit it via *Project → Project Settings* in the editor.
- Inside the game, paths start with `res://`, which means the project folder. For example, `res://player/player.tscn`.
- The `.godot/` folder is Godot's cache (like Unity's `Library/`). It's rebuilt automatically, so git ignores it.
- `*.import` files sit next to assets (e.g. `icon.svg.import`) and store how an asset is imported, similar to Unity's `.meta` files. They're committed to git.

**Input Map**
- Actions are named inputs (`jump`, `crouch`, …) defined in *Project Settings → Input Map*, each with one or more bindings. Unity's old Input Manager axes and the new Input System's actions work the same way.
- Code asks about actions, never keys: `Input.is_action_pressed("crouch")`, or for movement `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`, which returns a `Vector2` (like Unity's `Input.GetAxis` for two axes at once).
- A binding can be a *physical* key (its position on the keyboard) or a *keycode* (the letter). Chiip uses physical keys so layouts like Czech QWERTZ work.

**Scenes are text files**
- A `.tscn` file is a scene saved as readable text: a list of nodes with their properties, plus the resources they use (materials, shapes). Unity's `.unity` and `.prefab` YAML files are similar, but `.tscn` is much easier to read and diff in git.
- `[ext_resource]` lines point to other files (e.g. the shader), `[sub_resource]` lines are resources stored inside the scene (e.g. materials), and `[node]` lines build the tree.

**CSG for blockouts** (`maps/test_map.tscn`)
- `CSGBox3D` is a box you can resize in the editor. With *Use Collision* on, it's also solid. Godot's built-in alternative to ProBuilder.
- CSG shapes combine: a child with *Operation = Subtraction* cuts a hole into its parent. That's how the crouch tunnel is made.
- `StaticBody3D` + `CollisionShape3D` is a solid object without a mesh, like a Unity GameObject with only a Collider. The invisible stair ramp is one.
- `Label3D` draws text in the 3D world; with *Billboard* on it always faces the camera.

**Shaders** (`shaders/prototype_grid.gdshader`)
- Godot shaders are written in a GLSL-like language. `vertex()` runs per vertex and `fragment()` per pixel. A `ShaderMaterial` uses the shader and sets its `uniform` values, which show up in the Inspector (like material properties in Unity).

**Scripts and the player** (`player/player.gd`)
- A script `extends` a node type (`extends CharacterBody3D`) and is attached to a node of that type, like a MonoBehaviour that *is* the object rather than sitting on it. `class_name Player` gives it a global type name you can use elsewhere, e.g. `var player: Player`.
- `@export var max_speed: float = 6.35` shows the variable in the Inspector, like `[SerializeField]`. `@export_group("Ground")` groups exports under a heading.
- `@onready var _head: Node3D = $Head` finds a child node when the scene is ready. `$Head` is shorthand for `get_node("Head")`, like a cached `transform.Find("Head")`.
- Callbacks: `_ready()` ≈ `Start()`, `_process()` ≈ `Update()`, `_physics_process()` ≈ `FixedUpdate()`, and `_unhandled_input(event)` receives input events that no UI has used.
- Names starting with `_` are private by convention. GDScript doesn't enforce it.
- Godot 4.4+ creates a `.uid` file next to each script (`player.gd.uid`) holding a stable ID, so references survive renames. Commit these files.

**CharacterBody3D** (Unity: CharacterController)
- You set `velocity` yourself and call `move_and_slide()`, which moves the body, slides along walls and updates `is_on_floor()`.
- `get_gravity()` returns the project gravity (20.32 m/s² in Chiip).

**Polling vs. events**
- *Polling*: ask every tick whether a key is held, e.g. `Input.is_action_pressed("crouch")`. Good for things that last (moving, crouching).
- *Events*: `_unhandled_input(event)` is called once per key press. Good for one-off actions (jumping). A mouse-wheel "press" only exists as an event, because it presses and releases instantly.

**Asking "would I fit?"**
- `test_move(transform, motion)` checks whether the body *would* hit something if moved, without moving it. Unity's equivalent is `CapsuleCast`. The player uses it before standing up.

**Coroutines with `await`** (`tests/movement_test.gd`)
- `await get_tree().physics_frame` pauses a function until the next physics tick, like `yield return new WaitForFixedUpdate()` in a Unity coroutine. Any function that uses `await` becomes a coroutine, and callers `await` it too.

**2D UI on top of 3D** (`ui/debug_overlay.tscn`)
- A `CanvasLayer` draws its children on top of the 3D view, like a Screen Space Overlay Canvas in Unity. UI elements are `Control` nodes. `Label` is a text element, like Unity's Text/TextMeshPro.
- Per-node style changes are *theme overrides* (font, size, colors) in the Inspector.

**Pointing one node at another**
- `@export var player: Player` lets you drag the Player node into the overlay's Inspector slot, like assigning a reference in Unity's Inspector. In the `.tscn` file this is saved as a node path, and the node's header lists it under `node_paths`. The editor handles this for you.

**Instancing scenes**
- `player.tscn` is its own scene. The test map contains an *instance* of it, like placing a prefab. Changes to `player.tscn` apply to every instance.

**Physics ticks and interpolation**
- `_physics_process(delta)` runs at a fixed rate, 128 times per second in Chiip, like Unity's `FixedUpdate()`. `_process(delta)` runs once per rendered frame, like `Update()`.
- *Physics interpolation* draws physics objects smoothly between two ticks, similar to Unity's Rigidbody *Interpolate* option, but switched on for the whole project.

### M2 — Shooting

**Resources: data files** (`weapons/weapon_data.gd`, `weapons/rifle.tres`)
- A script that `extends Resource` defines a data type, like a ScriptableObject class in Unity. A `.tres` file is one saved instance, like a ScriptableObject asset. Double-click it in the FileSystem dock to edit it in the Inspector.
- Resources are shared: every weapon that uses `rifle.tres` reads the same object. Call `.duplicate()` to get a private copy (the tests do this to change values).
- A class with only constants (`systems/physics_layers.gd`) needs no `extends`; it's handy for named numbers like `PhysicsLayers.HITBOXES`.

**Signals** (`weapons/weapon.gd`)
- Declare with `signal ammo_changed(magazine: int, reserve: int)`, emit with `ammo_changed.emit(29, 90)`, and listen with `weapon.ammo_changed.connect(_on_ammo_changed)`. Like C# events or UnityEvents.
- The emitter doesn't know who's listening, so the weapon doesn't depend on the HUD. Signals can also be connected in the editor (*Node* dock → *Signals*).

**Raycasts** (`Weapon._shoot_bullet`)
- `get_world_3d().direct_space_state.intersect_ray(query)` is Unity's `Physics.Raycast`. The query (`PhysicsRayQueryParameters3D`) holds the start, end and collision mask. Set `collide_with_areas = true` to also hit `Area3D`s, such as hitboxes.
- The result is a `Dictionary` with `position`, `normal`, `collider`, …, and it's empty when nothing was hit.
- There's also a `RayCast3D` node, a ray that's always on and is good for constant checks. One-off queries like shots use `intersect_ray`.

**Random numbers you can repeat** (`Weapon.rng`)
- `randf()` uses a global generator, like `UnityEngine.Random.value`. A `RandomNumberGenerator` object has its own `seed`: the same seed gives the same numbers every run, like `new System.Random(seed)`. The weapon uses its own generator for spread, so tests can make shots repeatable.
- `inverse_lerp(a, b, value)` tells where a value sits between a and b (0 to 1), like `Mathf.InverseLerp`. It turns movement speed into "how much of the running penalty applies".

**Smooth following** (`Weapon._process`)
- `value = value.lerp(target, 1.0 - exp(-speed * delta))` moves a value smoothly toward a target, and behaves the same at any frame rate. Like `Vector2.Lerp` with a frame-rate-independent factor, or `Mathf.SmoothDamp`.

**Lambdas** (anonymous functions)
- `weapon.fired.connect(func(n: int) -> void: shots.append(n))` connects a signal to an inline function, like a C# lambda.
- Careful: GDScript lambdas *copy* local variables they use. Assigning to a captured `int` or `Vector2` inside the lambda doesn't change the outer variable, but changing the contents of a captured `Array` or `Dictionary` works because those are shared. C# lambdas share captured variables, so this differs.

**Area3D and enums** (`weapons/hitbox.gd`)
- An `Area3D` is a volume that detects things but doesn't block them, like a Unity collider with *Is Trigger* on. Hitboxes are areas, so bullets (rays with `collide_with_areas`) find them while players walk through.
- `enum Zone { HEAD, STOMACH, … }` works like a C# enum. `@export var zone: Zone` shows a dropdown in the Inspector, and the `.tscn` stores the number (HEAD = 0, STOMACH = 1, …).

**Tweens** (`TargetDummy._show_damage_number`)
- `create_tween()` animates properties over time without an animation file, like DOTween in Unity. `tween_property(label, "modulate:a", 0.0, 0.9)` fades the alpha to 0 over 0.9 s. `set_parallel()` runs steps together, and `chain()` continues one after another.

**Drawing UI in code** (`ui/crosshair.gd`)
- A `Control` can draw itself in `_draw()` with calls like `draw_rect()` and `draw_line()`, similar to Unity's `OnGUI` / `GL` drawing but kept as a retained drawing. Call `queue_redraw()` when it needs to change.
- *Anchors* pin a Control to parts of its parent: the crosshair fills the screen (*Full Rect*), and the ammo counter sticks to the bottom-right corner, like RectTransform anchors in Unity.
- `mouse_filter = Ignore` lets clicks pass through a Control. Otherwise a full-screen Control would swallow mouse clicks meant for the game.

**Building models from primitives** (`weapons/rifle.tscn`)
- `MeshInstance3D` + a primitive mesh (`BoxMesh`, `CylinderMesh`, `QuadMesh`) gives quick placeholder models without a 3D modelling tool, like Unity's built-in cube and cylinder.
- *Cast Shadow = Off* on the first-person gun avoids a floating gun shadow on the floor.
- An `OmniLight3D` is a point light. Switching it on for 0.04 s per shot makes the muzzle flash light up nearby walls.

**Sound** (`weapons/rifle.tscn`, `tools/generate_sounds.gd`)
- `AudioStreamPlayer` plays a sound without position, which is right for your own gun. `AudioStreamPlayer3D` plays it from a point in the world (bots' guns in M4), like an AudioSource with Spatial Blend 1 in Unity.
- *Max Polyphony* lets one player overlap several copies of a sound, so fast shots don't cut each other off.
- Sounds can be generated in code: fill an `AudioStreamWAV` with samples and call `save_to_wav()`.

**Tool scripts**
- A script that `extends SceneTree` can run on its own with `--script`, without opening a scene, like a Unity editor script run from the command line. Chiip keeps these in `tools/`.

**Spawning scenes** (`Weapon._spawn_impact`)
- `const IMPACT_SCENE := preload("res://weapons/bullet_impact.tscn")` loads a scene when the script loads. `IMPACT_SCENE.instantiate()` + `add_child()` is Unity's `Instantiate(prefab, parent)`, and `queue_free()` is `Destroy()`.
- `look_at(target, up)` turns a node so its −Z axis points at the target.
- `CPUParticles3D` with *One Shot* and *Explosiveness 1* emits a single burst, like a Unity Particle System burst.

**Children process after their parent**
- In a frame or physics tick, Godot calls `_process` / `_physics_process` from the top of the tree down. The player sets `weapon.trigger_held` and the weapon (its child) uses it in the same tick. Unity has no such guaranteed order without Script Execution Order settings.

### M3 — Retro look & map tools

**Viewports: rendering at a low resolution** (`main.tscn`)
- A `SubViewport` is an off-screen render target with its own size, like a Unity RenderTexture with a camera rendering into it. A camera inside it renders into it, not to the screen.
- A `SubViewportContainer` shows a SubViewport on screen. With *Stretch* on, the SubViewport follows the container's size divided by *Stretch Shrink* (2 = half resolution), and the container passes mouse and keyboard input through to it.
- *Texture Filter = Nearest* on the container scales the small image up with hard pixel edges instead of blurring it.
- The window itself can also render at a fixed low size and scale up (`content_scale_mode = viewport`, *Stretch → Mode = viewport* in Project Settings), which pixelates everything, UI included.

**Images in code** (`tools/make_retro_texture.gd`)
- `Image` is pixel data you can load, edit and save (`load_from_file`, `get_pixel`/`set_pixel`, `resize`, `save_png`), like Unity's `Texture2D` with `GetPixel`/`SetPixel` but without the GPU side. A `Texture2D` is what the GPU uses; Godot makes one when it imports a PNG.
- Each imported asset has a `.import` file with its settings. For pixel textures: *Compress → Lossless* (no blurry GPU compression) and *Mipmaps → Generate* (smaller copies for distant surfaces, which stops shimmering).

**Fonts and addons**
- A `.ttf` file becomes a `FontFile` on import. For pixel fonts, switch off *Antialiasing*, *Hinting* and *Subpixel Positioning* in the import settings, and use sizes on the font's pixel grid (multiples of 8 for Silkscreen).
- *Project Settings → GUI → Theme → Custom Font* sets the default font for all UI, like a default TMP font asset in Unity.
- `Label3D` with *Fixed Size* keeps the same size on screen at any distance, like a world-space name tag.
- An addon is a folder in `addons/` with a `plugin.cfg`. Enabling it in *Project Settings → Plugins* adds its node types (e.g. `FuncGodotMap`) and editor tools, like a Unity package.

**Triplanar materials** (`assets/materials/*.tres`)
- *Triplanar* mapping projects a texture from the three axes instead of using the mesh's UVs, and picks the projection that best faces each surface. With *World Triplanar* the projection uses world position, so textures line up across neighbouring boxes and never stretch when a box is resized. Very handy for CSG blockouts.
- *UV1 Scale* sets how many times the texture repeats per metre (0.6152 = once every 1.63 m).
- *Texture Filter → Nearest Mipmap* gives sharp pixels up close and smaller pre-shrunk copies far away, so distant surfaces don't shimmer. Quake looked like this.

**Environment and lights** (`maps/test_map.tscn`)
- The `WorldEnvironment` node holds an `Environment`: sky, ambient light, fog, tonemapping and color adjustments, all in one place, like Unity's Lighting window plus a post-processing volume.
- *Ambient light* is the light that fills shadows. Less of it means darker, moodier shadows.
- Fog is exponential: it thickens with distance at the rate of *Density*, and *Sky Affect* sets how much it covers the sky.
- `DirectionalLight3D` is the sun (only its rotation matters). `OmniLight3D` is a point light with a *Range*, like Unity's Directional and Point lights.

**Full-screen effects** (`shaders/palette_limit.gdshader`)
- A `canvas_item` shader on a full-screen `ColorRect` can read what's already drawn with `hint_screen_texture` and change it, like a Unity post-processing effect or a full-screen render pass.
- Put inside the world's `SubViewport`, it only changes the 3D image; the HUD outside stays untouched.

**TrenchBroom maps and func_godot** (`maps/comparison/`)
- A `.map` file is plain text. Each *brush* is a convex block defined by planes (three points each) plus a texture name and alignment. That's how Quake and CS (via Hammer) maps are made.
- func_godot's `FuncGodotMap` node reads a `.map` and builds normal Godot nodes from it: a `StaticBody3D` with collision, and a `MeshInstance3D` with one surface per texture. It can also unwrap *lightmap UVs* (a second UV set, `UV2`) so lighting can be baked.
- Tool buttons such as *Build Map* are `@export_tool_button` properties: buttons in the Inspector that run code in the editor.

**Instancing a scene from code** (`main.gd`)
- `load("res://maps/x.tscn").instantiate()` + `add_child()` puts a whole map into the running game, like `Instantiate()` with a prefab, or additive scene loading in Unity.
- `OS.get_cmdline_user_args()` returns the arguments after `--` on the command line.

### M4 — Bots

**Base classes and overriding** (`characters/character_controller.gd`)
- `class_name PlayerController extends CharacterController` inherits all of `CharacterController`, and can replace (override) its methods by defining them again, like a C# subclass overriding a `virtual` method. GDScript has no `virtual` keyword: any method can be overridden.
- Code that only knows the base type (`Character` calls `_controller.get_input()`) automatically runs the subclass's version.

**Inherited scenes** (`player/player.tscn`)
- A scene can *inherit* another scene, like a Unity prefab variant. `player.tscn` starts from `characters/character.tscn` and adds a camera, the rifle and a controller; a change to the base (e.g. the capsule size) applies to the player and every bot.
- In the editor: *Scene → New Inherited Scene*. Inherited nodes appear yellow-ish in the scene tree, and changed properties show a revert arrow.
- In the `.tscn` file, the root node has `instance=ExtResource(...)` and no `type`.

**Groups and material overrides** (`characters/soldier_body.tscn`, `Character._set_up_body`; the soldier body was retired in M6, D-074)
- A node can belong to named *groups* (`groups=["team_colored"]`), like Unity tags but a node can have many. `node.is_in_group("team_colored")` checks it; `get_tree().get_nodes_in_group(...)` finds them all.
- `MeshInstance3D.material_override` replaces a mesh's material on just that instance, so every character can wear its own team color while sharing one mesh.
- Hiding a node (`visible = false`) only affects drawing. Physics and areas keep working, which is how your own hit zones stay active while your body is invisible to you.

**Navigation meshes** (`maps/test_map_navmesh.tres`)
- A `NavigationRegion3D` holds a `NavigationMesh`: the walkable floor, worked out ("baked") from the level's solid geometry for an agent of a given height, radius, step height and maximum slope. Like Unity's NavMesh Surface.
- Baking looks at the nodes in a *group* (here `navigation_source`) and their children, and only at static colliders on the chosen physics layers, so labels, lamps and the player don't count.
- Sizes are rounded to the voxel grid (`cell_size`, `cell_height`), so pick multiples of it (2.0 m height, 0.25 m step) to avoid surprises.
- `NavigationServer3D.map_get_path(map, from, to, true)` returns a path as points. A `NavigationAgent3D` (next task) does this for a moving character and tells it the next point to walk to.

**Walking a path** (`bots/bot_controller.gd`)
- A `NavigationAgent3D` (child of the character) takes a `target_position`, asks the navigation mesh for a path, and gives the next point to walk to with `get_next_path_position()`. Call it every physics tick: it also notices when a waypoint is reached. `is_navigation_finished()` says when it has arrived. Like Unity's NavMeshAgent, but it doesn't move anything itself; the bot turns the direction into movement keys.
- `angle_difference(from, to)` gives the shortest signed turn between two angles (handles wrapping past 180°), handy for turning at a limited speed.

**Static variables and a "bus" for events** (`systems/noises.gd`)
- `static var` belongs to the class, not to an instance, like `static` in C#. `Noises` keeps one shared instance in a static variable, so any script can call `Noises.make_noise(...)` and any bot can connect to `Noises.get_bus().noise_made`. This is an *event bus*: senders and listeners don't need to know each other.
- Godot's usual tool for global objects is an *autoload* (Project Settings → Autoload), a node that's always in the scene tree, like a Unity singleton with `DontDestroyOnLoad`. But autoloads aren't loaded when Godot runs a `--script`, which our tools and checks do, so Chiip uses the static approach for things those scripts touch.

**Vision with raycasts** (`bots/bot_senses.gd`)
- "Can I see you?" = within range, within the view cone (the angle between where I look and where you are), and a ray from my eyes to your head or chest hits nothing on the world layer.

**A state machine with `enum` and `match`** (`bots/bot_controller.gd`)
- `enum State { PATROL, ENGAGE, SEARCH }` lists the modes; `var state: State` holds the current one; `match state:` runs the code for it, like a C# `switch`.
- Keep *deciding* (which state, `_update_state()`) separate from *doing* (`_patrol()`, `_engage()`, `_search()`). That makes it easy to see why a bot did something.
- Data files (`bots/difficulty_*.tres`) hold the tuning numbers, so you can make a bot harder in the Inspector without touching code.

**Sound in 3D** (`characters/character.tscn`, `weapons/rifle.tscn`)
- `AudioStreamPlayer3D` plays a sound from its position; volume and left/right panning follow the listener (the current camera). *Unit Size* sets how far it stays loud, *Max Distance* where it fades out completely. Like a Unity AudioSource with Spatial Blend 1.
- `AudioStreamRandomizer` is a sound resource that picks one of several streams each time it plays, with random pitch and volume, so repeated sounds don't sound like a loop. Like a Unity audio "random container".

**Tweens on physics ticks and timers** (`Character._die`, `ArenaRules`)
- `create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)` runs a tween on physics ticks, so physics interpolation smooths it like other movement. Use it for anything that moves a physics-interpolated node.
- `await get_tree().create_timer(3.0).timeout` waits 3 seconds without blocking the game, like `yield return new WaitForSeconds(3)` in a Unity coroutine.
- `func.bind(extra)` adds an argument to a signal connection: `bot.died.connect(_on_died.bind(bot))` tells the handler *which* bot died.

**Input order and a text field** (`ui/dev_console.gd`)
- Input events go through `_input()` first, then the UI (Controls such as a `LineEdit` text field), then `_unhandled_input()`. The console catches its own key in `_input()` and calls `get_viewport().set_input_as_handled()`, so the key doesn't also type a character or reach the game.
- `LineEdit` is a one-line text box; its `text_submitted` signal fires on Enter.
- A `Dictionary` of `Callable`s maps command names to functions, so adding a command is one `register_command()` line.

**Procedural animation** (`characters/soldier_body.gd`, retired in M6, D-074)
- Animation doesn't have to come from animation files. Rotating a *pivot* node (a `Node3D` at the hip) swings everything under it, the leg mesh and its hit zone, like a joint. `sin(phase)` gives a back-and-forth swing, and `phase` advances with distance walked, so the legs keep time with the footsteps. Unity would use an Animator; this is the code-only equivalent for placeholders.

**Smoothing toward a target** (`BotController._turn_toward`)
- `value += (target - value) * (1 - exp(-rate * delta))` covers a share of the remaining distance each tick: fast when far, gentle when close, and the same at any tick rate. Capping the step adds a maximum speed. It feels much more human than moving at a constant speed.

### M5 — Rounds & game flow

**Property setters** (`Character.team`)
- A `var` can run code when it's assigned: `@export var team: int = 0:` followed by an indented `set(value):` block. It's like a C# property with a `set` accessor, but the field and the property are the same name, and inside the setter `team = value` stores the value (it doesn't call the setter again). Here it recolors the body whenever `team` changes.
- A setter on an `@export` variable also runs when a scene file loads, *before* the node is ready, when `@onready` variables and child nodes don't exist yet. `is_node_ready()` tells you whether `_ready()` has run, so the setter does its work only then, and `_ready()` does it for the starting value.

**The SceneTree from static code** (`systems/teams.gd`)
- A class made only of `static` functions (like a C# static class) has no node, so it has no `get_tree()`. `Engine.get_main_loop() as SceneTree` returns the running game's tree from anywhere, and it's `null` when there isn't one, so check before using it. `Teams.set_viewer_team()` uses it to find every node in the `characters` group and recolor it.

**Game state with signals** (`systems/round_manager.gd`)
- One node owns the state (phase, timer, alive counts, score) and *announces* each change with a signal: `round_started`, `phase_changed`, `round_ended`, `character_killed`. Anything that shows the state (HUD, kill feed, scoreboard) connects to those and never changes the state itself. In Unity you'd use C# events or UnityEvents on a GameManager the same way.
- Signal parameters can be typed with the emitter's own enums (`signal round_ended(winner: int, reason: EndReason)`), and listeners refer to them as `RoundManager.EndReason`.

**`call_deferred()`**
- `_check_elimination.call_deferred()` runs the function at the end of the current frame instead of now, after every node has finished its physics tick. Like a Unity coroutine that waits `WaitForEndOfFrame`, without the coroutine. Here it lets two players who kill each other in the same tick both die before the round result is decided.
- `RoundManager._ready()` also defers starting the match: when a node's `_ready()` runs, its siblings later in the scene may not be ready yet.

**Inner classes** (`RoundManager.Stats`)
- `class Stats:` inside a script declares a small class, like a nested C# class. Outside it's `RoundManager.Stats`. It's a `RefCounted` object (freed automatically when nothing refers to it), handy for a typed bundle of numbers instead of a Dictionary with string keys.

**Teleporting a physics body**
- Setting `global_position` on a `CharacterBody3D` doesn't move it inside the physics engine (Jolt) right away: the engine picks up the new position at the next physics step. Until then, other bodies' `move_and_slide()` still collide with the *old* position. When the round manager teleports everyone in one tick, a bot could be pushed off its spawn by where a teammate stood a moment ago. `Character.respawn()` therefore makes the character skip moving for the rest of that tick. In Unity, `Rigidbody.position` and `Physics.SyncTransforms()` deal with the same problem.

**Geometry helpers** (`BotController._skip_passed_waypoints()`)
- `Geometry2D` and `Geometry3D` are static helper classes for common maths, like parts of Unity's `Vector3`/`Mathf`/`Physics` utilities: `Geometry2D.get_closest_point_to_segment(point, a, b)` finds the nearest point on a line segment, used to tell which leg of its route a bot is on.

**A typing quirk with enums**
- `Teams` and `Character` refer to each other (`Teams.damage_factor(victim: Character, …)`, `Character` calls `Teams`). In that kind of cycle GDScript can treat `Teams.Side` written in a third script as a different type from `Side` inside `Teams`, and refuse the call ("argument should be Side but is Teams.Side"). `Teams.spawn_group()` takes the side as an `int` to avoid it. Enums are ints underneath, so nothing is lost but the type check.

**UI containers** (`ui/match_end_screen.tscn`)
- A `Container` places its children itself: you don't set their positions, you set sizes and spacing. `VBoxContainer` stacks children top to bottom, `HBoxContainer` left to right, `MarginContainer` adds padding around one child, and `PanelContainer` draws a background behind its child. They replace Unity's Vertical/Horizontal Layout Group, Content Size Fitter and padding settings. A container is as big as its children's *minimum sizes* need (`custom_minimum_size` sets a floor), and a child with `size_flags_horizontal = SIZE_EXPAND_FILL` takes the free space left over, like "Control Child Size" and flexible width in Unity. The scoreboard is built from code: one `PanelContainer` → `MarginContainer` → `HBoxContainer` of `Label`s per player.
- A container can't be moved by offsets, so `UiScale` (which scales offsets) isn't enough. The screen scales font sizes, minimum sizes and the spacing "theme constants" (`separation`, `margin_left`…) instead, and remembers each control's original values in `set_meta()`, like `UiScale` does.
- A node centered with anchors (`anchors_preset = 8`, `grow_horizontal`/`grow_vertical` = both) keeps its minimum size and grows from the middle, so the panel stays centered however many rows it holds.

**`Button.pressed`** (`MatchEndScreen`)
- A `Button` emits `pressed` when clicked (or activated with Enter/Space while it has focus). `button.pressed.connect(handler)` is Unity's `button.onClick.AddListener(handler)`; in a scene you can also connect it in the editor's Node tab. `grab_focus()` gives the keyboard focus to a button. Here the buttons just re-emit their own signals (`play_again_pressed`, `quit_pressed`) so the screen doesn't need to know what the game does with them.

**`mouse_filter`** (`Background` in the match-end screen)
- Every `Control` has a `mouse_filter`: `STOP` takes mouse events and ends them there, `PASS` takes them and also offers them to its parent, `IGNORE` lets them fall through. That's Unity's *Raycast Target*, with three modes instead of on/off. Events a `STOP` control took never reach `_unhandled_input`, which is why a full-screen `STOP` background keeps clicks from reaching the `PlayerController`. Labels default to `IGNORE`, buttons and panels to `STOP`.

**`scene_file_path`** (`main.restart_match()`)
- Any node that is the root of an instanced scene knows which file it came from: `node.scene_file_path` (e.g. `res://maps/test_map.tscn`). `restart_match()` loads the current map again from that path. Unity has no direct equivalent; you'd keep the scene name or prefab reference yourself.

**Following a node's drawn position and rotation** (`PlayerController._process`, spectating)
- With physics interpolation on, a node's `global_position` is where the last physics tick left it, while what you *see* is smoothed between ticks. `node.get_global_transform_interpolated()` returns the drawn transform, so a camera that follows something (your own head, or a teammate's while you spectate) reads that instead of the tick position. In Unity, with Rigidbody *Interpolate* the Transform you read already holds the smoothed value; Godot keeps the two apart.
- `transform.basis.get_euler()` turns a rotation back into angles (x = pitch, y = yaw, z = roll, applied in the order Y, X, Z, like Unity's Euler order). The camera takes the teammate's head rotation this way and adds the recoil kick to the angles.

**Hiding a parent hides its children** (`Weapon.visible`)
- `visible = false` on a `Node3D` hides it and everything below it (meshes, the muzzle-flash light), like `SetActive(false)` on a GameObject, except physics, areas and sounds keep working. That is why one line hides your whole first-person rifle: the `Weapon` node is the parent of its model. A node under a hidden parent reports `is_visible_in_tree() == false` even when its own `visible` is true.

**`is_instance_valid()`** (`PlayerController._physics_process`)
- A variable that holds a node keeps pointing at it after it's freed, and calling anything on it then is an error. `is_instance_valid(node)` says whether it still exists. In Godot 4.7 a freed node also compares `== null` as true (measured in M5 task 7), much like Unity's overloaded `==` for destroyed objects, but `is_instance_valid()` says what you mean and is the safe habit before touching a node that may have been freed.

**`get_nodes_in_group()` returns scene-tree order**
- The nodes of a group come back in the order they stand in the scene tree, the same every time. Spectating relies on it for a stable "next teammate", with no list to keep.

**Simulating input in a test** (`tests/round_test.gd`)
- `Input.parse_input_event(event)` pushes an event (e.g. an `InputEventMouseButton`) through the same path real input takes, so `_unhandled_input()` sees it. Unity's Input System has `InputTestFixture` for this. In a headless run there is no display server, so `Input.mouse_mode` always reads *visible*: the test treats every click as the click that recaptures the mouse, and the real click is checked in a windowed run.

**A tween that waits, fades and cleans up** (`KillFeed.add_kill`)
- Tween steps run one after another by default: `tween_interval(5.0)` waits, `tween_property(line, "modulate:a", 0.0, 0.5)` fades, `tween_callback(func)` calls a function at the end (here: remove the line). It is DOTween's `AppendInterval().Append(DOFade(...)).AppendCallback(...)`. A tween made with `line.create_tween()` belongs to that node and ends when the node is freed, so a line pushed out early needs no cleanup of its tween.
- `modulate` multiplies the colors of a node *and all its children*, so one `modulate:a` on the line's panel fades the panel and all its labels together. In Unity you would need a `CanvasGroup` for that.

**`StyleBoxFlat`: backgrounds without a texture** (`KillFeed`, `RoundHud`)
- A `PanelContainer` draws a `StyleBox` behind its child. `StyleBoxFlat` is a plain color with an optional border (`set_border_width_all(2)`, `border_color`) and corner radius; `panel.add_theme_stylebox_override("panel", style)` sets it. It replaces a Unity `Image` with a color or a 9-sliced sprite, plus an `Outline` component. The kill feed uses two shared styles: dark, and dark with a white border for your own lines.

**Aligning inside containers** (kill feed lines, the top bar)
- Children of a `VBoxContainer` stretch to its width by default. `size_flags_horizontal = Control.SIZE_SHRINK_END` makes a child only as wide as it needs and pushes it to the right: that is how lines of different lengths stay right-aligned. In Unity this is the Layout Group's *Child Alignment* plus *Control Child Size*.
- A control anchored to an edge with zero width and `grow_horizontal = GROW_DIRECTION_BEGIN` (left) or `BOTH` (centered) grows from its anchor as far as its children need. The top bar is centered that way, the kill feed grows leftwards from the right edge, so neither needs a fixed width.
- `visible = false` on a child of a container takes it out of the layout (the others close the gap), like `SetActive(false)` under a Layout Group. The center messages use this for lines that have no text. A hidden control still runs `_process`, though: only `set_process(false)` stops it (in Unity, disabling the GameObject stops `Update`).

**Signals as values, and disconnecting** (`RoundHud.set_round_manager`)
- A `Signal` can be kept in a variable or array: `[[manager.phase_changed, _on_phase_changed], …]`, then `sig.connect(callable)`, `sig.is_connected(callable)` and `sig.disconnect(callable)` work on each pair. It is `event += handler` and `event -= handler` from C#. Connecting the same callable twice is an error in Godot (a C# event would just call it twice), so check `is_connected()` or disconnect first.
- Connections end by themselves when either side is freed. A map that is replaced is only `queue_free()`d, so its round manager still lives to the end of the frame: the HUD, which outlives maps, disconnects from it explicitly when it is handed the next one.
- `sig.get_connections()` lists the connections as dictionaries (`signal`, `callable`, `flags`), and `Callable.get_object()` says whose method it is. The test uses them to count how many signals the HUD listens to (5, never 10).

**`find_child` and `owned`** (`tests/round_test.gd`)
- `node.find_child("Killer", true, false)` searches the whole subtree for a node by name; `find_children("*", "Control", true, false)` finds all nodes of a type. The last argument, `owned`, must be `false` for nodes created from code: by default only nodes that belong to a saved scene (they have an owner) are found. Unity's closest are `Transform.Find` and `GetComponentsInChildren`.

**Does the font have this character?** (`Font.has_char()`)
- `font.has_char(0x2192)` says whether a font can draw a character. Silkscreen has no arrow "→", so the kill feed uses ">" (it does have "·", "×" and "»"); a missing glyph is drawn as a box or skipped. Check a font before putting a symbol in a label. Unity's TextMeshPro shows the same problem as missing-glyph warnings and solves it with fallback fonts.

**`@warning_ignore`** (`RoundHud.format_time`)
- `total / 60` with two ints truncates, and GDScript warns about it (`INTEGER_DIVISION`). `@warning_ignore("integer_division")` on the line above says "I meant that". C# divides ints silently.

**One scene used in two places, with a property changed on the instance** (`ui/scoreboard_table.tscn`)
- The scoreboard table is its own scene, instanced inside the hold-Tab overlay and inside the match-end screen. In a `.tscn` an instance is `[node name="Table" parent="..." instance=ExtResource("table_scene")]`, and any `@export` of its root can be set right under it: the match-end screen says `dim_dead = false`, the overlay leaves the default. That is a Unity nested prefab with an *override* on one instance: the scene stays the single place to change the look, and each user only states how it differs. In the editor you change it in the Inspector of the instanced node (a changed value gets a revert arrow).

**`CenterContainer`** (`ui/scoreboard.tscn`)
- A `CenterContainer` centers its child at the child's minimum size, however big the window is or how many rows the child grows to. Anchored to the full screen, it is the simple way to put a panel in the middle without anchor and offset arithmetic (Unity: anchors at the center with a pivot of 0.5, or a Layout Group with *Child Alignment* middle). It also keeps the panel's parent a container, which matters for `UiScale.apply_tree()`: that scales the offsets of controls that are *not* in a container, and a centered panel's offsets are worked out by the layout, so they must not be remembered and scaled.

**`CanvasLayer.layer` is the draw order** (`Scoreboard`)
- A `CanvasLayer`'s `layer` number decides what draws on top: higher is in front, like a Unity Canvas's *Sort Order*. The HUD sits on the default layer 1, the scoreboard on 3, the match-end screen on 5 and the console on 10, so Tab never covers the end screen or the console, whatever the order of the nodes in the scene tree.

**Arrays compare by value** (`ScoreboardTable.refresh`)
- `[1, "a"] == [1, "a"]` is `true`: `==` on arrays and dictionaries compares them element by element (and the elements that are nodes by identity). A C# `List` would compare references. The table builds a small "signature" array of everything it shows (names, kills, deaths, alive, …) each time `refresh()` runs and rebuilds its rows only when it differs from the last one, so asking for a refresh every frame costs almost nothing.

**Holding an action in a test** (`tests/round_test.gd`)
- `Input.action_press("scoreboard")` makes the game see the action as held, as if the key were down, until `Input.action_release("scoreboard")`; `Input.is_action_pressed()` and every script that polls it react. Unity's Input System test fixture has `Press()` and `Release()` for the same. The Tab binding itself is tested the other way round, by sending a real key press through `Input.parse_input_event()` and reading the action.

**`:=` can't infer a type from a Variant**
- `var x := dictionary[key]`, `var x := array.map(...)[0]` or `var x := array_of_untyped[3]` are parse errors ("Cannot infer the type"), because the value is a `Variant`. Write the type: `var x: String = …`. C# always knows what a `List<string>` indexer returns; GDScript only knows it for typed arrays (`Array[Character]`) and typed functions, so there `:=` works and for the rest you name the type.

**A `Theme` resource: styling every control from one place** (`ui/chiip_theme.tres`)
- A `Theme` is a resource that holds named *items* for *theme types*: colors, constants (spacing and other whole numbers), fonts, font sizes, icons (textures) and styleboxes. A control looks each one up by name in the type of its class: a `Button` asks the theme for `font_color`, `normal`, `hover`, `focus`... in the type "Button". It is the closest thing to a Unity UI Toolkit style sheet (USS): one file decides how every button looks, instead of copying the styling onto every button prefab as in uGUI. The lookup also walks up the class chain (a `CheckBox` is a `Button`), which is why a theme that styles "Button" will make check boxes look like buttons unless they get styles of their own, as ours do.
- Where a control finds an item, in order: an override on the node itself (`add_theme_color_override()`, or "Theme Overrides" in the Inspector), the `theme` property of the node or its closest ancestor that has one, the *project theme* (*Project Settings → GUI → Theme → Custom*, our `chiip_theme.tres`) and finally Godot's built-in default theme. `control.get_theme_color("font_color")` (and `get_theme_font_size`, `get_theme_stylebox`...) returns what a control would use, so a test can read a look back without taking a screenshot.
- `Control.theme` is passed down to all the controls below it, but not through a node that isn't a `Control`: a `CanvasLayer` (our HUD, scoreboard and match-end screen) stops it, so the theme is handed to the controls just under the layer. Popups are windows (`PopupMenu` in an `OptionButton`), and they take the theme of the control that owns them.

**Type variations: named looks for roles** (`theme_type_variation`)
- A *type variation* is a theme type that says "I am a `Label`, but with these items changed": `TitleLabel` is a label with a 48 px font. A node chooses one with its *Theme Type Variation* property (`theme_type_variation = &"TitleLabel"`), and anything the variation doesn't list comes from the base type. It is what Unity's USS classes (`.title`) or uGUI prefab variants do for a label: the scene says what the thing *is*, the theme says how it looks, and a restyle is one edit. Variations are also how a container's spacing is named (`ContentBox` is a `VBoxContainer` with a separation of 8), which leaves plain containers on Godot's defaults.

**More `StyleBox` types** (`tools/make_ui_theme.gd`)
- `StyleBoxFlat` (a color, borders, optional rounded corners) was introduced with the kill feed; the theme also uses `StyleBoxEmpty` (draws nothing, but still holds content margins), `StyleBoxLine` (a separator) and a focus ring: a `StyleBoxFlat` with `draw_center = false`, drawn on top of the control's normal look while it has the keyboard focus. *Content margins* are the space between a stylebox's edge and what it holds (a button's padding); *expand margins* let it draw outside its own rectangle (our selected tab covers the page's top border with one). In Unity the same split is padding on a layout group versus the border slice of a 9-sliced sprite.

**Scaling a theme instead of a node** (`ui/ui_theme.gd`)
- Everything in a theme is plain data, so a scaled copy can be built in code: a new `Theme`, then for each type `get_font_size_list()`, `get_stylebox_list()`, `get_icon_list()`... copied with every number multiplied (`set_font_size()`, `set_stylebox()` with a `duplicate()` whose `border_width_*` and `content_margin_*` are scaled). Assign that copy to the menu's root `Control` and every control below it picks it up, whatever it is: fonts, borders, margins and icons all change together. Unity's *Canvas Scaler* instead scales the whole canvas as pixels, which would blur pixel art at 1.5×; scaling the data keeps every pixel whole.
- `Resource.duplicate()` copies a resource (a stylebox) so the original isn't changed. `texture.get_image()` is not safe in that way: it can return the texture's own image, so `Image.resize()` on it changes it for everyone who uses the texture; call `duplicate()` on the image first. (This bit us in the first version; a test now catches it.) `Image.resize(w, h, Image.INTERPOLATE_NEAREST)` resizes without blending colors, which keeps pixel art crisp.
- Fonts have a pixel grid too: Silkscreen is drawn on 1/8 em, so at 16 px every font pixel is 2 × 2 screen pixels, and at 24 × 1.5 = 36 px it would be 4.5, which looks uneven. Text sizes that are multiples of 16 stay on whole pixels at 1.5× and 2×.

**Building a resource from a tool script** (`tools/make_ui_theme.gd`, `tools/generate_ui_icons.gd`)
- Like the sound tool, a script that `extends SceneTree` can make assets: `Image.create()`, `fill_rect()` and `save_png()` draw the icons; `Theme.new()` plus `set_color()`, `set_stylebox()`... then `ResourceSaver.save(theme, "res://ui/chiip_theme.tres")` writes a text resource that the editor opens like any other (its Theme editor shows it). Setting `resource_scene_unique_id` on a subresource gives it a readable name in the saved file (`button_normal`) instead of a random one, so a regenerated file doesn't change everywhere. The generated file is the output; the script is the source (a pattern like a Unity editor script that builds assets).

**A popup closes when its window loses focus** (`ui/theme_preview.gd`)
- A `PopupMenu` hides itself as soon as the window gets or loses keyboard focus, and a window launched from a terminal gains it a few frames late. The preview therefore waits until `get_window().has_focus()` has been true for a while before it calls `OptionButton.show_popup()`, which is why its drop-down stays open for a screenshot.

**`ConfigFile` and `user://`: saving settings** (`systems/settings.gd`)
- `user://` is a folder Godot makes for your game, outside the project: on macOS `~/Library/Application Support/Godot/app_userdata/Chiip/`. It's where a game keeps anything the player creates (settings, saves), because `res://` is read-only in an exported game. That is `Application.persistentDataPath` in Unity. `ProjectSettings.globalize_path("user://settings.cfg")` shows the real path.
- A `ConfigFile` is Godot's INI-style file: `config.set_value("video", "vsync", true)`, `config.save(path)`, `config.load(path)` (returns an `Error`: `OK`, `ERR_FILE_NOT_FOUND`, `ERR_PARSE_ERROR`), `config.get_value("video", "vsync", default)`. It stores any Godot value (numbers, bools, `Color(...)`, arrays) as text, so the player can open and fix the file by hand. It replaces Unity's `PlayerPrefs`, which hides its values in the registry or a plist. Two traps: `get_value` without a default is an error for a missing key, and a typed array is written as `Array[String](["a"])`, so build a plain `Array` if you want the file to read well. The file can't be half-read: one syntax error makes `load()` fail and print an error, so the code starts over from defaults.

**Properties with a getter and a setter, and no variable behind them** (`Settings.sensitivity`)
- `var sensitivity: float:` followed by `get: return _values[&"sensitivity"]` and `set(value): set_value(&"sensitivity", value)` is a C# property `{ get => ...; set => ... }` with no backing field: reading and writing go through code, here a dictionary that also clamps, applies, signals and saves. `Character.team` (above) had a setter on a real variable; this one has none. From outside it looks like a field: `settings.sensitivity = 2.0`.

**Audio buses** (`default_bus_layout.tres`, `Settings`)
- All sound goes through *buses*, like Unity's AudioMixer groups. `default_bus_layout.tres` (an `AudioBusLayout`, loaded at startup) lists them: Master, Effects and Interface, the last two *sending* to Master, so Master's volume scales everything. An `AudioStreamPlayer` (or `AudioStreamPlayer3D`) picks its bus with its `bus` property (in a scene: `bus = &"Effects"`). Code finds a bus by name: `AudioServer.get_bus_index(&"Effects")`, then `AudioServer.set_bus_volume_db(index, db)` and `set_bus_mute(index, true)`. Unity needs an *exposed parameter* on the mixer to do this from a script; Godot's buses are reachable directly. Volumes are decibels, and a slider is linear (0 to 1), so `linear_to_db(0.5)` gives −6 dB; 0 is minus infinity, so the code mutes the bus instead.
- The editor's *Audio* panel (bottom) edits this file. Check that no bus is muted or turned down before committing it: one muted by accident ships silence (`settings_test` checks the layout).

**`InputMap` at runtime: rebinding keys** (`Settings.set_binding`)
- The Input Map of the project settings is also an object you can change while the game runs: `InputMap.action_get_events("jump")` lists an action's events, `action_erase_events(action)` clears it and `action_add_event(action, event)` adds a key or button. Code that asks `Input.is_action_pressed("jump")` follows at once. Unity's new Input System does the same with `InputAction.PerformInteractiveRebinding()` and binding overrides; here there's no rebinding helper, so the code makes the events itself.
- `InputEventKey.physical_keycode` is the key's place on the keyboard (WASD stay put on a Czech layout), `keycode` the letter it makes; bindings made in the editor and ours use the physical one. An event built in code needs `device = -1` ("any device"), or it is ignored. A real key press from the keyboard has the device and modifier state of that press, so the settings copy only the key into a clean event before storing it.

**`DisplayServer` and `Engine`: window mode, V-Sync, frame limit** (`Settings`)
- `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` (back with `WINDOW_MODE_WINDOWED`) switches fullscreen, `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)` turns V-Sync on or off, and `Engine.max_fps = 144` caps the frame rate (0 is unlimited). They are Unity's `Screen.fullScreen`, `QualitySettings.vSyncCount` and `Application.targetFrameRate`. A headless run has a dummy `DisplayServer` (`DisplayServer.get_name() == "headless"`) with a 64 × 64 window that goes back to that size every frame, so the settings skip the window calls there.

**`StringName` comparisons** (`tests/settings_test.gd`)
- `&"name"` is a `StringName`: a string that is stored once and compared by address, which is why signal and action names use them. `==` between a `StringName` and a `String` works, but sorting an array of `StringName`s orders them by address, not alphabetically; convert to `String` first (the test does).

**`TabContainer` and `ScrollContainer`** (`ui/settings_menu.tscn`)
- A `TabContainer` turns each of its child controls into a tab, and the *node's name* is the tab's title ("Game", "Video"...); only the selected child is visible. `tabs.current_tab = 3` switches, `get_tab_bar()` gives the row of tab buttons (to give it the keyboard focus). Unity's UI has no tab view; you build one from a toggle group and panels you show and hide.
- A tab container is as big as the page it is *showing* needs, so switching tabs can resize the panel around it. The crosshair page's widest row made the whole settings panel jump from 960 to 1068 px when you opened that tab (the other tabs were fine), so a test has to visit every tab to see it.
- A `ScrollContainer` is Unity's *Scroll Rect*: a child taller than it is scrolls (mouse wheel, scroll bar). Set `horizontal_scroll_mode = 0` (disabled) for a vertical list; the child is then as wide as the container. The Controls list scrolls because 13 rows don't fit under the tabs.
- A `Slider` also reacts to the mouse wheel by default (`scrollable = true`), so scrolling a page over a slider would change its value. `slider.scrollable = false` stops that.

**Sliders, text fields and drop-downs that must not echo** (`SettingsMenu`)
- Setting a control from code usually fires its signal, which would write the value straight back. `slider.set_value_no_signal(v)` and `check_box.set_pressed_no_signal(b)` change what is shown *without* emitting (Unity: `Slider.SetValueWithoutNotify`, `Toggle.SetIsOnWithoutNotify`); the settings menu uses them whenever `Settings.changed` tells it to follow, so there is no loop. Assigning `line_edit.text = "..."` doesn't emit `text_changed` either (only typing does).
- An `OptionButton` (Unity's Dropdown) holds items with a text and an id: `add_item("144 fps", 144)`. `item_selected(index)` passes the *index*, not the id, so the handler asks `get_item_id(index)`; `select(index)` shows an item from code without a signal, and `get_item_index(id)` finds it.
- `LineEdit` signals: `text_submitted` on Enter, `focus_exited` when you click away, `text_changed` while typing. A number field commits on the first two and ignores text that isn't a number; the menu accepts "1,5" as well as "1.5", because a Czech keyboard types a comma.
- `"%d" % 28.999999` is `28` (it cuts off), and `0.29 * 100` is `28.999999999999996`, so a field that shows percent rounds first (`roundi()`).

**Capturing the next key press, for rebinding** (`SettingsMenu.listen()`)
- While a slot waits, the menu reads events in `_input()` and ends each one it uses with `get_viewport().set_input_as_handled()`, so the key doesn't also reach the game, the console key or the menu's own Esc. Only a key *press* (not its release, not an `echo` repeat) is bound. `InputEventMouseButton` presses work the same, and the mouse wheel is a button press too (`MOUSE_BUTTON_WHEEL_UP`).
- A `Button` emits `pressed` when the mouse button is *released*, so the click that started the waiting is over before the menu listens, but the menu also ignores a press in the same frame (`Engine.get_process_frames()` is the frame counter) in case a button fires on press.
- Order of `_input()`: later nodes in the scene tree are called first, so the console (last in `main.tscn`) sees Esc before the settings menu; whoever handles the event ends the walk with `set_input_as_handled()`. A hidden `CanvasLayer` still receives `_input()`, so a menu checks its own `visible`. Unity's closest thing is the order of `EventSystem` handlers, but there you rarely care.
- A static flag (`MenuState.capturing_input`) lets code that can't be told directly (the console) stand down while the menu waits.

**A static class that keeps a list of nodes** (`ui/menu_state.gd`)
- Like `Settings` and `Teams`, `MenuState` is a class with only `static` members: `static var _open: Array` holds the open menus and `static func open(menu)` changes it, with no node and no autoload (so tests and tools can use it). It is Unity's static class with a static list, or a ScriptableObject singleton.
- A node freed while it is in such a list leaves a dead entry; `is_instance_valid(entry)` tells, and the list is cleaned each time it is read. (Keep such a list untyped: `Array[Node]` complains about the freed element.)

**Several menus at once** (`MenuState.is_top()`)
- Stacked menus (settings over a pause menu, the console over settings) need to know which one is on top: the last one opened. Only that one reacts to Esc, so one key press closes one menu, not all of them. A single `bool` like `DevConsole.is_open` can't say that.

**Scene unique names: `%Name`** (`SettingsMenu`)
- A node with *Access as Unique Name* (`unique_name_in_owner = true` in a hand-written `.tscn`) can be found from anywhere in the same scene with `%Name`, wherever it sits in the tree: `@onready var _tabs: TabContainer = %Tabs`. Unity has no direct match (`transform.Find` needs a path); it is like a name that is unique within one prefab.

**`Callable.bind()` puts the bound arguments last** (`SettingsMenu`)
- `button.pressed.connect(start_listening.bind(action, slot))` calls `start_listening(action, slot)` when `pressed` (no arguments) fires. But for a signal or call *with* arguments, the bound ones come *after* them: a callable made with `set_value.bind(id)` and called with `(value)` runs `set_value(value, id)`, the wrong order for `set_value(key, value)`. A small lambda says what you mean: `func(value): _settings.set_value(id, value)`.

**Showing part of a `Label`** (`DevConsole`)
- `label.max_lines_visible = 16` and `label.lines_skipped = n` make a `Label` show only a window of its lines, and its minimum height follows the lines shown, so a long text neither grows the panel nor needs a scroll container. The console keeps 200 lines in the label and moves the window for the mouse wheel and Page Up / Down (Unity: TextMeshPro's *Max Visible Lines* and a scroll offset).

**A color square inside a button** (`SettingsMenu`, the crosshair swatches)
- A `Button` is not a container, so a child is placed by its anchors: a `MarginContainer` with `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` and `mouse_filter = IGNORE` fills the button, and a `ColorRect` inside it leaves a margin around the color. The button keeps its theme frame, hover and focus ring, and no stylebox override is needed (an override would not be scaled by `UiTheme`).

**Driving input in a test, again** (`tests/ui_test.gd`)
- `Input.parse_input_event(event)` followed by `Input.flush_buffered_events()` makes the event arrive *now* through the same path a real key takes (`_input()`, the GUI, `_unhandled_input()`), so a test can press a key and check its effect in the same frame. Events built by hand need both `keycode` and `physical_keycode` to look like real keyboard events. A test that sends a key press must send the release too, or the key stays down in `Input`.

**Changing scenes and the main scene** (`MainMenu`, `Main.return_to_menu()`)
- `get_tree().change_scene_to_file("res://main.tscn")` (or `change_scene_to_packed()` with a `PackedScene` you already loaded) replaces the current scene: it frees the old scene's whole tree and adds the new one, at the end of the frame (the call returns at once, so don't expect the new scene yet). It is Unity's `SceneManager.LoadScene` in single mode. Nothing of the old scene survives, its menus, its `_ready()` state and its signals' connections included (a connection to a freed node disappears by itself).
- Which scene starts is *Project Settings → Application → Run → Main Scene* (`run/main_scene` in `project.godot`), like the first scene in Unity's Build Settings. Chiip's is now `ui/main_menu.tscn`; running another scene directly (`Godot --path . res://main.tscn`, or F6 in the editor) works as before.
- `get_tree().current_scene` is the node that `change_scene_*` will free; a script that adds a node under the root by hand has to set it (a test does, so the scene change it checks frees a scene of the test's own, not the test).

**Passing data between scenes with static variables** (`systems/game_launch.gd`)
- Since the old scene is freed, data can't stay in its nodes. Unity's answers are `DontDestroyOnLoad` objects or a static class; Godot's are an *autoload* (a node kept alive by *Project Settings → Globals*) or `static var` in a class. Chiip uses the static class (like `Settings`, `Teams` and `MenuState`): `GameLaunch.start_match(map, rules)` before the change, `GameLaunch.is_pending()` and `clear()` in the new scene's `_ready()`. A static variable keeps its value as long as the game runs and isn't saved anywhere, and tools run with `--script` have no autoloads, which is why not an autoload.

**`Path3D`, `PathFollow3D` and `Curve3D`** (`ui/menu_flight.gd`)
- A `Path3D` holds a `Curve3D`: points with an in and an out handle (Bézier). A `PathFollow3D` child moves along it: set `progress` (metres along the curve) or `progress_ratio` (0 to 1) and the follower's transform is the curve's point (and, with `rotation_mode` on, its direction). Whatever is a child of the follower rides along: a camera here. Unity has no direct match; it is a spline with a "dolly" on it (Cinemachine's Dolly Track, or the Splines package).
- `curve.closed = true` joins the last point to the first. `curve.add_point(position, in_handle, out_handle)` takes handles *relative to the point*; handles along the line between the neighbouring points (a sixth of it) give a smooth, corner-free Catmull-Rom route. `curve.sample_baked(distance, true)` gives the point at a distance along the curve (the curve is cut into small baked steps first), so "look 24 m ahead" is one call.
- A constant `progress` speed is a constant speed in metres, however the curve bends. The project has physics interpolation on; a node moved in `_process()` instead of the physics tick should set `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF`, or the interpolation fights the motion.

**Taking a scene apart before it enters the tree** (`MainMenu._build_background()`)
- `PackedScene.instantiate()` builds the nodes but they are not in the tree yet, so no `_ready()` has run. `remove_child(node)` and `node.free()` on one of them leaves a map without its player, with nothing of the player ever running (a node removed *after* `add_child()` would already have run its `_ready()`, captured the mouse and so on). Unity's equivalent is editing a prefab instance before it is activated.

**`ButtonGroup`: toggle buttons that act like radio buttons** (`ui/match_setup.gd`)
- Buttons with `toggle_mode = true` that share a `ButtonGroup` (`button.button_group = group`) press each other out: exactly one is on, and clicking the one that is on does nothing. Unity's `ToggleGroup`. A row of them is a "segmented" choice that shows every option at once. `toggled(on)` fires for the one switched on *and* the one switched off, so a handler usually checks `on`. `set_pressed_no_signal()` changes a button without the signal but, with a group, does not unpress the others: when showing a stored value, set every button of the row.

**Testing a scene change** (`tests/ui_test.gd`, `_test_scene_flow`)
- A test that calls `change_scene_to_file()` would free the test scene itself. The test makes a `Node` of its own a child of the root, assigns it to `get_tree().current_scene`, puts the scene under test in it, and lets the change happen: that node is freed, the new scene becomes current, and the test node (and its coroutine) lives on. At the end it puts `current_scene` back and frees the new scene. Anything the scenes load from disk is pointed at a temporary file first.

**Pausing the game: `SceneTree.paused` and `process_mode`** (`ui/pause_menu.gd`, D-065)
- `get_tree().paused = true` stops every node whose `process_mode` is the default (`PROCESS_MODE_INHERIT`, which means "do what my parent does", and the root is pausable): `_process`, `_physics_process`, `_input` and `_unhandled_input`, GUI input, `Timer`s, tweens bound to the node, and the physics and navigation servers (the tree switches those off by itself). Nodes set to `PROCESS_MODE_ALWAYS` (the Inspector's *Node → Process → Mode*, or `process_mode = 3` in a `.tscn`) keep running, with their children, which inherit it: a menu is one node with Always at its root. `WHEN_PAUSED` runs only while paused, `DISABLED` never. Unity's `Time.timeScale = 0` is a different tool: it zeroes the *time* but every `Update()` still runs and input still arrives, and you opt out per object with unscaled time (`Time.unscaledDeltaTime`, `WaitForSecondsRealtime`); Godot pauses *nodes*, and you opt out per node. (`Engine.time_scale` exists too and acts like `timeScale`; Chiip doesn't use it.)
- What follows the pause without any code: `AudioStreamPlayer` / `3D` (a *playing* one is paused and resumes where it stopped, an idle one is unchanged, and a player set to Always keeps playing, which a menu click sound needs), `create_tween()` tweens (they pause with the node they were created on, `Tween.TWEEN_PAUSE_BOUND`), and `get_tree().create_timer(time, process_always)` (the second argument is `true` by default, so such a timer keeps counting while paused: pass `false` for game time). `await get_tree().process_frame` and `physics_frame` keep firing while paused (a test can wait across a pause).
- A node can see the change: `_notification(what)` gets `NOTIFICATION_PAUSED` and `NOTIFICATION_UNPAUSED` when *its own* ability to process changes, so a node that is paused can still clean up as the pause starts and ends (`PlayerController` drops a queued jump and blocks a held fire button this way, because its `_process` doesn't run while paused). `node.can_process()` says whether it can run right now.
- A paused node's `_process` doesn't run, so it can't hide itself: the Tab scoreboard is Always for that reason (a node that only has to *react to* the pause, here by hiding, has to be awake to do it).
- The pause belongs to the tree, not to a scene: `change_scene_to_file()` while paused starts the next scene paused (frozen and deaf to clicks), so leaving a game unpauses first.

**Window content scale with integer stretch** (`ui/pixel_view.gd`)
- `Window.content_scale_mode = VIEWPORT` renders the whole window (UI included) at `content_scale_size` and scales it up; `content_scale_stretch = INTEGER` only allows whole factors and rounds *down*. Asking for 853 × 480 in a 1280 × 720 window gives factor 1 (1.5 rounded down): a small, unscaled image. Pick the whole number first (720 / 480 → 2) and ask for the window size divided by it (640 × 360). Unity has no direct equivalent; it's like rendering to a low-res RenderTexture and blitting it with point filtering at an integer scale.
### M8 — Quick maps (started early)

**Level design words used in docs/MAPS.md**
- A **lane** is one of the main routes from one spawn to the other (west, mid, east); **connectors** link lanes. A **sightline** is a straight, open view; short ones mean fights happen at close range. **Timing** is how long it takes each side to reach a spot, which decides where the first fight happens.
- Obstacles have to **overlap** to block views: two boxes side by side with a gap still let a diagonal through. Offset doors and "gates" with something right behind them do the same job.

**TrenchBroom axes vs Godot** (`maps/*.map`)
- func_godot turns TrenchBroom's (X, Y, Z) into Godot's (Y, Z, X): TrenchBroom's Z is up, like Unity's Y. In TrenchBroom's top view the map is turned 90°: Godot's north (−z) is on the left. 39.37 units are one metre (1 unit = 1 inch, like CS).

**The navigation map needs a moment** (`tests/maps_test.gd`)
- After a map with a `NavigationRegion3D` is added, `NavigationServer3D` picks up its mesh a few physics frames later; queries before that answer for the old map or the origin. Wait until `map_get_regions()` holds only the new region and `map_get_iteration_id()` has gone up. Unity's NavMesh is ready as soon as the scene loads.

**`.gdignore`** (`docs/maps/`)
- An empty `.gdignore` file makes Godot skip a folder: the plan drawings there are for reading, not textures to import.


### M8 — Modes

**Area3D as a trigger zone** (`bomb/bomb.gd`, the maps' `bomb_sites`)
- With `monitoring` on, an `Area3D` keeps track of which bodies are inside it; `overlaps_body(body)` asks about one, `get_overlapping_bodies()` lists them all. That's Unity's trigger collider with `OnTriggerStay`, or `Physics.OverlapBox`. The area's `collision_mask` decides which bodies count (here 6: the player and the bots).
- The list is updated once per physics step, so a body you just teleported is only "inside" one step later.
- `monitoring` was off in the maps until the bomb needed it: a monitoring area costs a little every physics step even when nobody asks.

**A `Callable` in a variable as a hook** (`Bomb.kit_check`)
- `var kit_check: Callable = func(defuser: Character) -> bool: return false` holds a function, like a C# `Func<Character, bool>` field. M7's economy will put its own check in it, and the bomb doesn't need to know where kits come from. `kit_check.call(defuser)` runs it.

**Teleporting a smoothed node** (`Bomb._place()`)
- With physics interpolation on (D-010), a node moved in `_physics_process` is drawn sliding between its old and new place. After a jump, such as the bomb dropping to the floor or appearing on the next carrier, `reset_physics_interpolation()` tells Godot not to smooth that one move. Unity's `Rigidbody.interpolation` has the same problem; there you'd set the position on the Rigidbody and the transform.

**Overriding methods: a subclass of a script** (`systems/respawn_match.gd`)
- `class_name RespawnMatch extends RoundManager` inherits every variable, signal and method of the round manager, like a C# subclass. Any method can be replaced by defining one with the same name: GDScript methods are all "virtual", there is no `override` keyword. `super(killer, victim)` (or `super.method()`) calls the parent's version.
- Signals connected with `_on_died.bind(character)` inside the parent call the subclass's `_on_died`, because the method is looked up by name on the object.
- `rounds is RoundManager` is true for a `RespawnMatch` too, so code that takes a `RoundManager` (the HUD, the scoreboard) accepts it, and `rules is RespawnMatch` tells them apart.

**Asking a NavigationAgent3D for a new path** (`BotController._check_stuck()`)
- Setting `target_position` again, even to the same point, makes the agent compute a fresh path from where the bot is now. That's how a stuck bot gets a new route after backing off; Unity's `NavMeshAgent.SetDestination()` works the same way.

**Metadata from func_godot, and which shape a ray hit** (`systems/surfaces.gd`)
- Any node can carry extra data with `set_meta()` / `get_meta()`, like a Dictionary attached to the node and saved with the scene. func_godot can store per-face data (texture, normal, which brush) there when the entity class asks for it; Chiip's worldspawn class does.
- `intersect_ray()` also returns `shape`, the index of the hit shape inside the body. `body.shape_find_owner(shape)` and `shape_owner_get_owner()` turn it into the `CollisionShape3D` node, whose name links it to the brush's faces. Unity's `RaycastHit.collider` gives the collider directly; with one body made of many shapes Godot needs the extra step.

**Static classes that own a node** (`ui/ui_sounds.gd`)
- A class with only static members can still play sounds: it creates one `AudioStreamPlayer`, adds it to `get_tree().root` (deferred, since the tree may be busy) and keeps it in a static variable. That's the job a Unity singleton `MonoBehaviour` with `DontDestroyOnLoad` would do, without an autoload.

**Lighting options in Godot** (D-085, `tools/map_screenshots.gd --lighting`)
- Real-time lights (`DirectionalLight3D`, `OmniLight3D`) plus the `Environment`'s ambient light is what the maps use, like Unity's realtime lights with a flat ambient color.
- **SSAO** (screen-space ambient occlusion) and **SSIL** darken corners and contact points from the depth buffer, per frame, like Unity's post-processing AO.
- **SDFGI** computes bounce light in real time from a signed-distance version of the level; no baking, like Unity's Enlighten realtime GI. It also bounces the sky's color, which tinted our shadows blue.
- **LightmapGI** bakes light into textures, like Unity's Progressive Lightmapper, but only from the editor's *Bake Lightmaps* button; there is no script call for it.
- On macOS V-Sync is enforced by the system, so even `--disable-vsync` stays at the display's rate, and `RenderingServer.viewport_get_measured_render_time_gpu()` returns 0 with Metal.

**A script can't reuse a built-in method's name** (`ui/match_setup.gd`)
- A menu that `extends CanvasLayer` can't have its own `get_rotation()`: `CanvasLayer` already has one (the layer's rotation), and Godot treats the clash as an error ("overrides a method from native class"). Unity lets you hide an inherited member with `new`; in GDScript pick another name (`get_rotation_maps()`).

**Exporting a game** (D-086)
- An **export preset** (`export_presets.cfg`, *Project → Export…*) is like a Unity build profile: platform, file name, what to include, signing. `--export-release "<preset>" <path>` builds from the command line.
- **Export templates** are Godot's prebuilt game executables for each platform (Unity installs these as "build support" modules). They must match the engine version exactly and live outside the project.
- The game's content goes into one **`.pck`** file next to the executable, like Unity's data folder or asset bundles. Text scenes are converted to binary on the way, which is why `DirAccess` sees `.remap` files in an exported game and `ResourceLoader.list_directory()` is the safe way to list them.
- Apple Silicon only runs signed code; an **ad-hoc signature** (no Apple account) is enough on the Mac that built it. Sharing builds needs a Developer ID and notarization.

**Text you can see through walls** (the bomb's marker)
- `Label3D.no_depth_test = true` draws the text on top of everything, like a waypoint marker; `fixed_size` keeps it the same size on screen at any distance. Unity would use a world-space canvas with a shader that ignores depth.

**Holding a key in a test** (`tests/bomb_test.gd`)
- `Input.action_press("use")` and `Input.action_release("use")` hold and release an action as if the key were down, so the test goes through the real `PlayerController` → `CharacterInput` path. Unity's Input System has `InputTestFixture.Press()` for the same thing.

**Audio buses that don't exist yet**
- `AudioStreamPlayer3D.bus = &"Effects"` names a bus of the audio bus layout (Unity's Audio Mixer groups). If the layout has no such bus, the sound plays on *Master* instead, without an error, so a sound can be put on a bus before the settings task creates it.

### M6 — Crew & animation

**Importing a glTF model** (`assets/models/crew/rifleman.glb`)
- Drop a `.glb` (binary glTF) into the project and Godot imports it into a scene, the way Unity imports an FBX into a model prefab. The import settings live in a `.import` file next to it (Unity keeps them in a `.meta` file). You can instance the result like any scene, but not edit its nodes in place: you either make an *inherited scene* from it or, as Chiip does, put it into your own scene and change things from code.
- glTF is the format Godot prefers (FBX needs a converter). It can reference textures as separate files: Godot then uses the project's own imported PNG, with that PNG's import settings. Chiip's generated textures are imported lossless with `detect_3d/compress_to=0`; otherwise Godot switches a texture to lossy VRAM compression the first time it sees it on a 3D model, and the palette would smear.
- glTF faces +Z by convention, Godot's forward is −Z. Chiip's generator writes its models facing −Z, so they need no turning.

**`Skeleton3D`: bones are not nodes**
- In Unity a rig is a hierarchy of Transforms and a `SkinnedMeshRenderer` points at them. In Godot the whole rig is *one* `Skeleton3D` node holding a list of bones (name, parent, rest pose, current pose), and the skinned `MeshInstance3D` is its child. You find a bone with `find_bone("hand_r")` and read its pose with `get_bone_global_pose()`. Godot may order the bones differently from the file, so always look them up by name.
- Each bone's *rest* is its pose in the file (Chiip's T-pose); animations set the *pose* on top of it.

**A `--script` can load and inspect any scene**
- A script that `extends SceneTree` (run with `--script`) can `load()` an imported model, `instantiate()` it and walk its nodes, which is a quick way to check what an importer built without opening the editor.

**Godot's shading language** (`characters/crew/crew.gdshader`)
- A Godot shader is one `.gdshader` text file, written in a GLSL-like language, with no wrapper around it: `shader_type spatial;` on the first line says it is a 3D surface shader (`canvas_item` is the 2D one, like the palette effect). Unity has ShaderLab around HLSL, with `Properties`, `SubShader` and `Pass` blocks and `#pragma` lines; Godot has none of that. The engine supplies the lighting, so you don't write passes: you fill in built-in outputs in a `fragment()` function (`ALBEDO`, `EMISSION`, `ROUGHNESS`, `SPECULAR`, `METALLIC`, ...), which is what a Unity *surface shader* does with `SurfaceOutputStandard`. `UV` and the textures' `texture(sampler, UV)` work as expected.
- Anything declared `uniform` at the top becomes a property of the material, shown in the Inspector (Unity's `Properties` block, but declared in the same line as the variable). *Hints* after the colon say how to treat it: `source_color` marks a texture or a vec4 as an sRGB colour, so Godot converts it to linear light for the maths (Unity does this for you with the sRGB flag on a texture, and a `[HDR]` or colour property); `filter_nearest_mipmap_anisotropic` and `repeat_disable` pick the sampling (Chiip's pixel look: nearest neighbour, but mipmaps and anisotropic filtering so far-away textures don't shimmer). A texture that holds data rather than colour (the team mask) gets no `source_color`.
- A `ShaderMaterial` is the shader plus the values of its uniforms (Unity: a Material). In code, `material.set_shader_parameter("name", value)`. `const` values (like `TEAM_BASE`) are baked into the shader and can't change.

**Per-instance shader parameters** (`instance uniform`, `set_instance_shader_parameter`)
- Unity has a trap here: setting a colour on `renderer.material` makes a copy of the material for that one renderer, and the `MaterialPropertyBlock` is the way to give one renderer its own value while sharing the material. Godot's version is built into the shader: declare `instance uniform vec4 team_color : source_color = ...;` and set it per mesh with `mesh_instance.set_instance_shader_parameter("team_color", color)` (read it back with `get_instance_shader_parameter()`). The material stays shared, so ten soldiers use one material and can still be blue and red.
- Instance uniforms live on the `GeometryInstance3D` (a mesh, multimesh, ...), not on the material, so `CrewBody` keeps the wanted colour in a variable and sets it on every mesh of the model when it builds the model in `_ready()`, and again whenever `set_team_color()` is called. Use them for a few values that differ per object, like this colour; the shared material keeps everything else.

**`BoneAttachment3D`: a node that follows a bone** (`characters/crew/crew_body.gd`)
- In Unity you make a GameObject a child of a bone's Transform and it follows the bone, because every bone *is* a Transform. In Godot bones aren't nodes (see `Skeleton3D` above), so there is nothing to parent to. A `BoneAttachment3D` is the stand-in: a node you add as a child of the `Skeleton3D`, with `bone_name` set to a bone. Every time the skeleton updates its pose, the attachment copies that bone's global pose, and everything under the attachment moves with it (Unity: a weapon socket, or a hitbox object on the hand bone). Chiip's hit zones are `Hitbox` areas under `BoneAttachment3D` nodes, so they follow the animated body instead of a fixed box.
- The skeleton updates its bones at the end of the frame, after the code that changed a pose has run, so a zone's position lags a pose change by up to one physics tick. A test that moves a bone waits a frame (and can call `skeleton.force_update_all_bone_transforms()`) before reading where the zones went. `skeleton.set_bone_pose_rotation(bone, quaternion)` and `set_bone_pose_position()` are the calls that pose a bone by hand (what an animation would do each frame); the bone's *rest* stays untouched.

**Adding nodes to an instanced imported scene at runtime** (`CrewBody._build_hit_zones`)
- An imported `.glb` is a scene you can `instantiate()`, but its nodes aren't meant to be edited in the editor, so extra nodes can't be saved into it. Code adds them after instancing: `CrewBody._ready()` instances the model, finds its `Skeleton3D` with `find_children("*", "Skeleton3D", true, false)` and adds the attachments to it (Unity: instantiating a model prefab and adding components to its children in `Awake`). Nodes made with `Hitbox.new()` and `CollisionShape3D.new()` have no scene file; they need a name (`node.name = ...`) and must be added with `add_child()` after their own children are set up. The same code builds every class's zones from a `HitZones` resource, so a new class needs no scene editing.
- A parent's `_ready()` runs after its children's, so the body (a child of `Character`) has built its zones by the time `Character._set_up_body()` looks for them with `find_children`.

**Animations from a glTF file** (`assets/models/crew/rifleman.glb`)
- A glTF file can carry animations, and Godot imports them into an `AnimationPlayer` in the model's scene (Unity puts them into the model's import as animation clips). Each clip has one track per bone; a bone track is written `Skeleton3D:hips`, the node path and the bone name. `get_animation_list()` lists the clips and `play("run_f")` plays one, which is what the crew preview does with N and P.
- glTF has no "loop" flag. Godot's importer loops an animation whose name ends in `-loop` (or `-cycle`) and removes the suffix, so the generator names `run_f` as `run_f-loop` in the file. The same setting is in the editor: double-click the `.glb`, *Animation* tab, *Loop Mode* (Unity: the model importer's *Animation* tab, *Loop Time*).

**`AnimationTree`: Godot's Animator** (`characters/crew/crew_animation_tree.tres`, `crew_body.gd`)
- An `AnimationTree` plays the clips of an `AnimationPlayer` through a graph, like Unity's Animator controller. Its root here is an `AnimationNodeBlendTree`: nodes wired into each other, ending in `output`. Each node's settings live in *parameters* on the tree, set from code: `tree.set("parameters/Stand/blend_position", Vector2(...))`, like `animator.SetFloat()`.
- **Blend spaces**: `AnimationNodeBlendSpace2D` blends clips placed at points of a 2D space (here velocity: x right, y forward), Unity's 2D blend tree; `AnimationNodeBlendSpace1D` along one axis (the aim pitch). `sync = true` keeps all clips advancing together so legs stay in step.
- **Filters** are Unity's avatar masks: a node with `filter_enabled` only affects the listed tracks (`Skeleton3D:spine`...). The `Upper` Blend2 takes spine, chest, head and arms from the aim blend and everything else from the legs.
- **One-shots** (`AnimationNodeOneShot`) play a clip once on top, when you set `parameters/Fire/request` to `ONE_SHOT_REQUEST_FIRE`, like a trigger parameter. With `mix_mode = MIX_MODE_ADD` the clip is *added* (Unity's additive layer), so a recoil kick works at any aim pitch. Additive clips hold differences from a base pose.
- **Transitions** (`AnimationNodeTransition`) switch between inputs by name (`transition_request = "headshot"`), with a cross-fade. Gotcha: a new Transition has no current state and outputs *nothing*, so the model stays in its rest pose; request a first state when you build the tree.
- `callback_mode_process = PHYSICS` runs the tree on physics ticks (Unity's Animator *Update Mode: Animate Physics*), and a `Skeleton3D`'s `modifier_callback_mode_process` does the same for the skeleton.

**Swapping a model at runtime** (`CrewBody.set_class()`)
- To change what a node shows while the game runs, take the old child out and put a new one in. In Unity you would `Destroy(oldGameObject)` and `Instantiate(newPrefab, parent)`. In Godot the two steps are `remove_child(old)` and `old.queue_free()`, then `add_child(new)`.
- `queue_free()` (Unity's `Destroy`) deletes the node at the end of the frame; `free()` (Unity's `DestroyImmediate`) deletes it on the spot. Swapping with `queue_free()` is the safe choice: the old hit zones can still be in the middle of announcing a hit (a signal handler is running because of them), and an object freed during its own signal would crash the game. The old node and its children are still valid objects for the rest of the frame, but they are out of the tree, so they no longer take part in physics.
- `remove_child()` is not optional. A node queued for freeing is still in the tree until the frame ends, so the new model could not be named `Model` too (Godot would rename it `@Model@2`), and `find_children` would still find the old hit zones. Taking it out first also stops the old zones from being hit during that frame.
- Anything that kept a reference to the old nodes (the body's lists of meshes and hit zones, the animation tree, the muzzle flash) must let go of them before the new model is built. Signals connected *to* the body or the character stay as they are, because those two nodes are not replaced; the signals of the old hit zones are disconnected by hand.

**A Resource as a data file with a static registry** (`characters/crew/class_data.gd`, `classes/*.tres`)
- A class that `extends Resource` and has `@export` variables is a data type, like `WeaponData` (Unity: a `ScriptableObject`). Each `.tres` file is one saved instance. Here there is one per crew class, with its texts, numbers, the model (a `PackedScene`) and the hit zones (another Resource) as references to other files; in a hand-written `.tres`, those are `[ext_resource]` lines at the top.
- A *static registry* is a `static func` on the resource class that knows where the instances are: `ClassData.all()` loads the four files from a constant list of paths, `ClassData.find(id)` looks one up. Unity would use a `ScriptableObject` list or `Resources.LoadAll`. It uses `load()` and not `preload()` because the `.tres` files refer back to the script: a `preload` of them from inside the script would be a circle. `load()` runs when called, and Godot caches the result, so every call gives the same objects (that is why `class_data == other_class_data` works as a comparison).
- The perk values are stored in the resource now and read by the M7 code later, so they can be tuned in the Inspector without touching a script.
- A property with a setter on a Node (`Character.class_data`) runs before `_ready()` when a scene is loaded or a script sets it before `add_child`. Code that needs the children (the body) must check `is_node_ready()` first, as `Character.team` does.

**Playing clips from code, and moving a node to another parent** (`weapons/weapon.gd`)
- `AnimationPlayer.play("fp_fire", blend, speed)` plays a clip (with a short cross-fade and a speed factor, here to stretch the reload to the weapon's reload time), `seek(0.0, true)` restarts it when the same clip is already playing, and `queue("fp_idle")` plays the idle clip once it ends: Unity's `Animator.Play()` and a transition back, without a state machine. Setting `active = false` stops a player from doing any work, which the hidden arms of every bot use.
- `node.reparent(new_parent)` moves a node to another parent in one call (Unity: `transform.SetParent()`); with `keep_global_transform = false` it keeps its *local* position instead. The muzzle flash moves onto the gun's bone attachment this way, so it follows the gun's kick and reload.

### M7 — Arsenal, perks & economy

**Composition: an inventory node instead of a weapon class hierarchy** (`characters/inventory.gd`)
- A character's weapons are plain `Weapon` nodes, one per weapon, all made from one generic scene with different data (`Weapon.create(data)`, a *static* function: Godot's version of a factory method). What a weapon does comes from its `WeaponData` resource, not from a subclass per gun. The `Inventory` is a child node that owns them, like a component in Unity: the character asks it, the HUD listens to it. Godot favours this: a node has one script, and behaviour is added by adding child nodes.
- Weapons not in hand are switched off with `process_mode = PROCESS_MODE_DISABLED` (no `_process` / `_physics_process` for the node and its children; Unity: disabling a component) and hidden with `visible = false` (Unity: `SetActive(false)` does both at once).
- When the thing a listener follows can change (the weapon in hand), the owner emits a signal (`weapon_changed`) and each listener disconnects from the old one and connects to the new one. Disconnecting from a node that is about to be freed is fine as long as it isn't freed yet: `queue_free()` waits until the end of the frame.
- `@onready` variables are null until a node enters the tree. A method called on a node that was made but not added yet (`Weapon.set_arms()`) has to keep its work for `_ready()`; `is_node_ready()` tells which case it is.

**Zooming the camera, and drawing a scope in code** (`player/player_controller.gd`, `ui/scope_overlay.gd`)
- A scope is just a narrower `Camera3D.fov` (vertical degrees in Godot; Unity's `Camera.fieldOfView` is vertical too). The player's field of view setting is CS's horizontal degrees across 4:3, so the zoomed angle goes through the same conversion (`Settings.vertical_fov()`). Mouse sensitivity is scaled by the ratio of the half-angles' tangents, so a mouse movement crosses the same part of the screen zoomed or not.
- The scope's black mask is drawn in `_draw()` (Unity: `OnGUI` or a UI `Graphics` subclass): rectangles row by row beside a circle, plus `draw_arc()` for the rim. `queue_redraw()` asks for a new drawing only when the size changes, so it costs nothing per frame.

**One animation graph, many holds** (`tools/make_crew_animation_tree.gd`, `characters/crew/crew_body.gd`)
- An `AnimationNodeTransition` (Unity: a sub-state machine with instant transitions, or an int-driven blend) picks one of its inputs by name: `tree.set("parameters/Hold/transition_request", "pistol")`. The crew graph uses one to choose the upper body's aim blend by the held weapon, and others inside one-shots to choose which kick, attack or reload plays. Parameters live on the `AnimationTree` *instance*, so ten characters share one graph resource and each holds its own weapon.
- A request is consumed when the node next runs. A transition that only runs while a one-shot plays (the kick) switches at that moment, which is exactly when it matters; `current_state` reads the old one until then.

**A projectile without a rigid body, and particles** (`weapons/grenade.gd`, `weapons/explosion.gd`)
- A grenade moves itself in `_physics_process`: gravity on its velocity, then a ray (`intersect_ray`) along this tick's move; a hit puts it at the surface and reflects the velocity (`velocity - normal * 2 * dot`, scaled for the bounce). Unity would use a `Rigidbody` with a bouncy `PhysicMaterial`; doing it by hand keeps every throw exactly the same on every run (and on M9's host), which a physics engine doesn't promise.
- `GPUParticles3D` is Godot's particle system (Unity's Particle System): the node emits, a `ParticleProcessMaterial` says how particles start and move (direction, spread, speed, gravity, damping), and a mesh in `draw_pass_1` is what each particle looks like. `one_shot` plus `explosiveness = 1` fires them all at once, for a burst. Headless runs don't draw them, which is fine for tests.

### M10 — Map kit

**How TrenchBroom finds textures, and how func_godot turns them into materials** (`assets/textures/<set>/`, D-121)
- TrenchBroom reads every image below the game's texture folder (`assets/textures`, set in the game config that `tools/export_trenchbroom_config.gd` writes) and shows each sub-folder as a *collection* in its texture browser. A face stores the texture's path below that folder, without extension: `industrial/rust_plates`. Unity has no direct equivalent: it's like a material picker that lists a folder of textures.
- When func_godot builds the map it turns each texture name into a Godot material. First it looks for a material file with the same path and `.tres` next to the image (`assets/textures/industrial/chainlink.tres`); if there is none, it copies the template material from the map settings (`assets/materials/map_default.tres`: rough, no shine, pixel filtering) and puts the image in as albedo. So most textures need no material at all, and a special one (see-through, glowing) gets a hand-made `.tres` beside it, which TrenchBroom ignores because it only lists images.
- **Alpha scissor** (`transparency = ALPHA_SCISSOR`, `alpha_scissor_threshold = 0.5`) cuts out every pixel below half opacity and draws the rest as solid: Unity's *Alpha Clipping* / cutout shader. It stays sharp, needs no sorting and casts holey shadows, which suits pixel art better than real transparency. `cull_mode = CULL_DISABLED` draws both sides of a face (a fence seen from behind).
- In a tool script, `Image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))` reads a PNG's pixels straight from the file. `Image.load_from_file()` on a `res://` image works too but warns, because an exported game only has the imported texture, not the PNG (`tools/texture_report.gd`).

**Props: a model, box colliders and a TrenchBroom entity** (`tools/modelgen/props.py`, `maps/kit/props/`, D-122)
- A prop scene is a `StaticBody3D` with the imported `.glb` as a child and a few `CollisionShape3D` children, each holding a `BoxShape3D`: Unity's prefab with a `MeshRenderer` child and several `BoxCollider`s. Godot has no single "collider component": the body decides what it is (static, rigid, character), the shapes say where it is solid. The body's **collision layer** says what it *is* (world, or the see-through layer); its mask, what it bumps into (nothing: a static body never moves, so `collision_mask = 0`).
- A glTF file can hold several *primitives* (Unity: sub-meshes), each with its own material. Lamps use one lit material and one *emissive* material (`emissiveTexture`), which Godot imports as a `StandardMaterial3D` with emission on: the bulb glows whatever the light around it.
- A `.glb`'s import settings live in the `.glb.import` file next to it (Unity: the model's import settings in its `.meta`). The generator writes `meshes/generate_lods=false` once: Godot would otherwise make simplified versions for distance, which only break a 300-triangle box.
- **Point entities** are TrenchBroom's prefabs: a classname at a point, with an angle and properties. func_godot's FGD resource says which scene each classname becomes. In a scene saved by `tools/build_maps.gd` a placed prop stays an *instance* of its scene (like a prefab instance in Unity), so regenerating the prop updates every map that uses it without a rebuild. That works through `owner`: a node is saved in the scene file whose root is its owner, so nodes inside an instance keep the instance as their owner.

**Lamps: a spot light, entity properties and a tool script** (`maps/kit/kit_light.gd`, D-124)
- A `SpotLight3D` is a cone of light along its −Z (Unity's spot light): `spot_angle` is the cone's half angle, `spot_range` its reach. Turning the node turns the beam, so a floodlight's beam is tilted down by rotating the light about X.
- `distance_fade_enabled` makes a light fade out and stop costing anything beyond a distance from the camera (Unity has no built-in equivalent; it's like culling lights by distance in a script).
- Entity properties set in TrenchBroom (`light_color`, `light_energy`…) reach the game through func_godot: when the map is built it calls `_func_godot_apply_properties(properties)` on the node, with the values already turned into Godot types (a `color255` becomes a `Color`). The lamp stores them in `@export` variables, which are saved into the map scene as *overrides* of the lamp's instance, like overriding a prefab instance's field in Unity.
- `@tool` at the top of a script runs it in the editor too (Unity's `[ExecuteInEditMode]`), so the lamp's light shows while you look at the map in Godot. A child added with `add_child(node, false, Node.INTERNAL_MODE_BACK)` is *internal*: it is never saved with the scene and `get_children()` skips it, which suits a light rebuilt from the exported values every time.

**Entities that become gameplay markers** (`maps/fgd/chiip_mapper_fgd.tres`, `maps/kit/kit_bomb_site.gd`, `kit_route_point.gd`, D-125)
- A *brush entity* is a brush (or several) that belongs to an entity instead of the world: func_godot builds the entity's `node_class` from it. For `trigger_bombsite` that is an `Area3D` (Unity: a trigger collider) whose shapes are the brushes; `build_visuals = false` leaves out the mesh, so it's invisible.
- A *point entity* with `node_class = "Marker3D"` and `node_groups` becomes an empty marker in those groups, the same as dragging a `Marker3D` into a scene and adding it to a group (Unity: an empty GameObject with a tag).
- `call_deferred()` runs a call at the end of the frame, once the scene tree has finished what it's doing. A route point can't move itself to another parent inside `_ready()` (its parent is busy adding children), so it asks for `_join_route.call_deferred()` and reparents itself a moment later (Unity has no direct equivalent; it's like starting a coroutine that waits one frame).
- `node.reparent(new_parent)` keeps the node's place in the world; `move_child(node, index)` sorts a parent's children, which is all a route's order is.

**The Shooting Range: choices in TrenchBroom, metadata on a scene, text in the world** (`maps/kit/kit_weapon_stand.gd`, `kit_text_sign.gd`, D-141, D-142)
- An FGD property whose default is a `Dictionary` becomes a drop-down list in TrenchBroom (`range_weapon`'s `weapon`: "Ram (rifle)" → `rifle`). func_godot hands the script the value, a String; the description `["Which gun", "rifle"]` gives the default.
- func_godot turns a point entity before it calls `_func_godot_apply_properties()`, so a script can still change its rotation there: the text sign turns itself 180° once, at build time, and the built scene keeps it.
- A map tells the game something about itself with metadata on its root node (`metadata/practice_bots = 0` in the `.tscn`; *Add Metadata* in the Inspector). Unity would use a component on the scene's root object for that.
- A `Label3D` with *Fixed Size* is the same size on screen at any distance, so far away it is huge in the world: at 30 m a 14-letter title is about 10 m wide and runs into the nearest wall, which hides that part of it (labels are depth tested unless `no_depth_test`). Keep such titles short, or put the long text on the wall.

### M10 — UI refresh

**Design tokens for a generated theme** (`tools/ui_palette.gd`, D-131)
- A *design token* is a named value of a look (a colour, a text size, a padding), the way web and Figma designs hand over a style. Godot has no token system of its own, but a script full of `const` values that a tool reads works the same: `tools/make_ui_theme.gd` builds every stylebox, font size and spacing of the `Theme` from those names, so restyling is editing values in one file and running the tool. In Unity terms it's a USS file's variables (`--accent-color`), only checked by the editor because they are GDScript constants.
- A test can read a script's source with `FileAccess.get_file_as_string()` and search it with `RegEx` (Godot's regular expressions are PCRE2, lookbehind included); `ui_test` uses that to make sure the theme tool never gets a number of its own again.

**Custom theme types for icons** (`ui/ui_icons.gd`)
- A theme type doesn't have to be a class: the theme can hold items under any name you choose, like our `Palette` (colours) and `Icons` (textures). Any control under the theme asks with `get_theme_icon(&"headshot", &"Icons")`, and `has_theme_icon()` says whether the item exists, so a missing icon can fall back to text instead of Godot's "missing icon" placeholder. Because the icon lives in the theme, `UiTheme`'s scaled copies resize it with the rest of the UI (nearest-neighbor), which loading the PNG by path in each screen wouldn't do. Unity's nearest equivalent is a sprite atlas referenced by name from a style sheet.

**A button with more than one line of text** (`ui/main_menu.tscn`, the mode buttons)
- A `Button` draws one text in one font size, and its minimum size comes only from that text and its stylebox, so children you add to it are neither laid out nor counted. The trick is to put the `Button` and the content side by side in a container: a `MarginContainer` makes every child as big as itself, so the `Button` fills the whole area behind two labels, and the container is as tall as the labels need. The labels and their boxes get `mouse_filter = IGNORE`, so the click, the hover and the keyboard focus go to the `Button` underneath. In Unity's uGUI you'd do the same with a `Button` component on a parent `Image` and two `Text` children with *Raycast Target* off.

**Changing a saved default without surprising old players** (`Settings.MATCH_SETUP_VERSION`)
- Settings are saved with every value, so a new default never reaches a player who already has a file. A version number written into the file (`setup_version` in `[match]`) lets loading tell an old file from a new one and move only the values that changed meaning, once; the next save writes the new version. The same idea as a save-game version in Unity's `PlayerPrefs` or a JSON save.

**A hard drop shadow on a StyleBoxFlat** (`tools/make_ui_theme.gd`, `_shadowed()`)
- `StyleBoxFlat` has `shadow_size` and `shadow_offset`, but its shadow is always blurred, which breaks the pixel look. A hard shadow is a trick instead: grow the box 2 px to the right and down with `expand_margin_right` / `expand_margin_bottom` (it is drawn bigger than the control) and draw just those two edges as a 2 px border in the shadow colour. The fill then covers exactly the control and the border looks like a shadow. In Unity's uGUI you'd use the `Shadow` component with zero blur.

**One icon, coloured per state** (the menu items' chip)
- A `Button`'s icon is drawn through the theme colours `icon_normal_color`, `icon_hover_color`, `icon_focus_color`, `icon_pressed_color`... (white icons take them exactly). Making `icon_normal_color` transparent and the others ink gives the mockup's focus chip that appears only on the focused or hovered item, with no code.

### M9 — Multiplayer

**Godot's high-level multiplayer** (`net/net_session.gd`)
- Every node can reach `multiplayer`, a `MultiplayerAPI` (in practice a `SceneMultiplayer`), Godot's counterpart of Unity Netcode's `NetworkManager`. What actually sends packets is its `multiplayer_peer`: an `ENetMultiplayerPeer` (UDP through the ENet library, like Unity Transport), a `WebSocketMultiplayerPeer`, a `WebRTCMultiplayerPeer` or, later in M9, a Steam peer. Swapping the peer swaps the transport; the rest of the code stays.
- `peer.create_server(port, max_clients, channels)` hosts, `peer.create_client(address, port, channels)` joins; assign the peer to `multiplayer.multiplayer_peer` and the signals `peer_connected`, `peer_disconnected`, `connected_to_server`, `connection_failed` and `server_disconnected` tell you what happens. Every computer gets a *peer id*: the server is always 1, clients get random numbers (`multiplayer.get_unique_id()`).
- ENet *channels* are independent queues: a lost unreliable snapshot on one channel never holds up reliable events on another.

**RPCs** (`@rpc`)
- A function marked `@rpc` can be called on the same node on another computer: `my_function.rpc(args)` calls it on everyone, `my_function.rpc_id(peer_id, args)` on one computer. Unity's `[ServerRpc]` / `[ClientRpc]` are the same idea, but Godot uses one annotation with options: `"any_peer"` (any computer may call it; check `multiplayer.get_remote_sender_id()` to see who did) or `"authority"` (only the node's *multiplayer authority*, the server by default); `"call_remote"` (not on yourself) or `"call_local"`; `"reliable"`, `"unreliable"` or `"unreliable_ordered"`; and a channel number.
- The call finds its node by **path**, so the node must exist at the same path on both computers. That is why the session node always has the same name (`NetSession`) and the same place below its multiplayer root.

**One process, several "computers"** (`SceneTree.set_multiplayer()`, `tests/net_harness.gd`)
- `get_tree().set_multiplayer(SceneMultiplayer.new(), ^"/root/Test/Host")` gives one branch of the tree its own multiplayer API: nodes below it use that one, with paths counted from the branch. Two branches with their own APIs connected over localhost behave like two computers, which is how Chiip's network tests run a host and clients in one test run. Unity has nothing built in for this (its multiplayer play mode starts extra editor processes).

**Raw packets next to RPCs** (`SceneMultiplayer.send_bytes()`, `peer_packet`)
- `SceneMultiplayer` can also send plain byte arrays, with no node and no path: `send_bytes(bytes, peer_id, transfer_mode, channel)`, received through the `peer_packet(id, bytes)` signal. Chiip uses them for the game stream, where it wants its own compact format and tick numbers (D-101), and RPCs for the lobby.

**Running code in a set order within a tick** (`process_physics_priority`)
- Every node's `_physics_process` runs once per tick, normally in tree order (parents before children, earlier siblings first). `process_physics_priority` changes that: lower numbers run first, across the whole tree (Unity's *Script Execution Order*, but per node and changeable at runtime). Online, the session hands out the packets at -1000, the network code runs the friends' commands at -100, everything else runs at 0, and the host sends its snapshots from a node at 1000, after everyone has moved.

**A world of its own** (`SubViewport.own_world_3d`, `Viewport.find_world_3d()`)
- A `SubViewport` normally shares the 3D world (rendering *and* physics) of the window it is in, so two maps in two SubViewports would collide with each other's walls. `own_world_3d = true` gives it a separate `World3D` with its own physics space, which is how the network tests keep the host's and the client's maps apart in one process. `node.get_viewport().find_world_3d()` tells which world a node lives in. Groups, however, are per tree, not per world: that is why `Character.all_in_world()` filters the `characters` group.

**ENet's throttle**
- ENet slows down unreliable traffic on its own when it thinks the connection is congested: it drops a share of unreliable packets when the round-trip time rises. That suits bulk data, not a game stream that already repeats what matters, so Chiip switches it off per connection with `ENetPacketPeer.throttle_configure(interval, acceleration, 0)`.

**Client-side prediction, in Godot terms** (`net/net_client.gd`)
- Unity's Netcode for GameObjects has no built-in prediction either (Netcode for Entities does); in both engines you write it yourself. The trick that makes it work here is that a `CharacterBody3D`'s `move_and_slide()` can be called several times in one physics tick: replaying ten commands is ten calls in a row, each starting where the last one ended. The physics engine only learns the body's final position at the next physics step, which doesn't matter for the body's own moves (`move_and_slide()` starts from the node's transform).
- `is_on_floor()` is the result of the last `move_and_slide()`, so after putting a body somewhere by hand it is stale; Chiip tells the next tick explicitly (`Character.set_floor_contact()`).
- GDScript's `float` is 64 bits, but `Vector3` and the packets use 32. A value that travels must be cut to 32 bits *before* both sides use it (`PackedFloat32Array([value])[0]`), or the two simulations drift apart a hair per tick.

**Lag compensation without moving physics bodies** (`net/lag_compensation.gd`)
- Source's way is to move every player's hitboxes back in time, trace, and move them forward again. In Godot (with Jolt) a body or area moved from code only reaches the physics engine at the next physics step, so a ray cast right after moving it would still see the old place. Chiip keeps the hit-zone boxes as numbers (a `Transform3D` and a size per zone and tick) and tests the ray against them in GDScript: transform the ray into the box's own space with `affine_inverse()`, then the box is axis-aligned and the "slab test" (where the ray enters and leaves each pair of faces) gives the hit. A check compares it with `intersect_ray()` on 300 rays.
- `Transform3D.interpolate_with(other, weight)` blends position and rotation between two recorded ticks, like `Vector3.lerp` plus `Quaternion.slerp` (Unity: `Vector3.Lerp` and `Quaternion.Slerp`).

**The peer is the swappable part** (`net/net_transport.gd`, D-114)
- In Godot everything above the connection talks to a `MultiplayerPeer`: RPCs, `send_bytes()`, peer ids, `peer_connected`. ENet (`ENetMultiplayerPeer`), WebSocket, WebRTC and GodotSteam's `SteamMultiplayerPeer` are all `MultiplayerPeer`s, so changing how computers reach each other means making a different peer and nothing else. Unity's Netcode works the same way: its `NetworkManager` has a *transport* component (Unity Transport, or a community Steam transport) you swap without touching game code. Chiip puts the making of the peer in one small class (`EnetTransport`), so a Steam one can sit next to it later.

### M11 — Weapons and models

**Shader includes** (`.gdshaderinc`, `#include "res://..."`)
- A shader file can pull in another file's code with `#include`, like a C header: uniforms, constants and functions all come along. Chiip's crew surface lives in `crew_surface.gdshaderinc`, so the bodies' shader and the first-person arms' shader share it, and every viewmodel shader includes `shaders/viewmodel.gdshaderinc`. Unity's equivalent is `#include "File.hlsl"` / `.cginc` in a shader. Functions in an include can't see `vertex()`'s built-ins (`PROJECTION_MATRIX`, `VERTEX`), so they take them as parameters; global ones like `CLIP_SPACE_FAR` work anywhere.

**Writing `POSITION` in a spatial shader** (the viewmodel, D-155)
- Normally Godot multiplies `VERTEX` by the model-view and projection matrices for you. If `vertex()` writes `POSITION` (clip space), that value is used instead, while lighting still uses the real view-space position. That's how the viewmodel gets its own field of view (scale clip x and y) and its own depth range (set clip z), Quake's depth-range trick, without a second camera. In Unity you'd do the same in a custom vertex shader by changing `UnityObjectToClipPos`'s result, or use a second camera with a culling mask.
- Godot 4 uses **reverse Z**: depth is 1 at the near plane and 0 far away (`CLIP_SPACE_FAR` is the far value: 0, or −1 in the Compatibility renderer). Nearer things have *larger* depth, the opposite of Unity's default on OpenGL.

**Skeleton modifiers** (`SkeletonModifier3D`, the left-hand IK, D-156)
- A node under a `Skeleton3D` that changes bone poses after the animation, every update: override `_process_modification()`, read poses with `get_bone_global_pose()` and write them with `set_bone_global_pose()`. `influence` (0 to 1) blends its result with the animated pose, `active` switches it off. Unity's counterpart is the Animation Rigging package (a *Rig* with a `TwoBoneIKConstraint`), or `OnAnimatorIK` with `SetIKPosition`. Godot 4.6+ also ships ready ones (`TwoBoneIK3D`, `FABRIK3D`, `LookAtModifier3D`...).
- The result lives in the poses only while the skeleton draws: Godot puts the animated poses back afterwards, so modifiers don't pile up from frame to frame. To read what a modifier did, connect to `Skeleton3D.skeleton_updated` (a `BoneAttachment3D` does the same).

### M11 — Optimization

**Measuring a frame** (`tools/frame_timing.gd`, D-165)
- Unity has the Profiler window and `FrameTimingManager`. Godot's editor has a Profiler tab too, but a tool needs numbers it can compare from run to run, so Chiip times the frame itself. `SceneTree.physics_frame` fires at the start of every physics tick and `process_frame` at the start of the process step. `RenderingServer.frame_pre_draw` and `frame_post_draw` bracket drawing. The gaps between them are the frame's parts.
- A node's `process_priority` orders `_process` calls: higher runs later (Unity's Script Execution Order). A helper node with a huge priority marks the end of the scripts in a run without a window, where no drawing signals fire.
- `Performance.get_monitor(TIME_PROCESS)` is not one frame's time: the engine updates it once a second with the slowest frame of that second, and it includes drawing and the wait for the display.
- `RenderingServer.get_rendering_info(RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)` counts shader pipelines compiled in the middle of a frame: the "first time I see a smoke, it hitches" stutter. Unity's equivalent is `ShaderVariantCollection` warm-up. Godot 4.4+ compiles most of them in the background ("specialization").
- `-d --profiling` on the command line prints GDScript's own profiler (time per function) once a second: like Unity's Deep Profile, for scripts only.

**Loading versus finding a resource** (`systems/shop.gd`, D-166)
- `load()` returns the copy already in memory as long as something holds it. When nothing does, the resource was freed and `load()` parses the file again, like `Resources.Load` after `Resources.UnloadUnusedAssets`. Code that runs often keeps what it loaded in a `static var`. The class keeps it, as in a C# static field.
- `set_meta()` / `get_meta()` hang a value on any `Object` (Unity: a component, or a dictionary keyed by the object). Chiip keeps a hit zone's box on the zone (`net/lag_compensation.gd`): it goes away with the zone, while a dictionary keyed by the zone could match a new zone that got a freed one's memory.

## M12: sharing the game

**Never trust the other side of a network** (`@rpc("any_peer")`, `get_remote_sender_id()`, `bytes_to_var`)
- `@rpc("authority")` means only the node's authority (the host, peer 1) may call it, and Godot drops a call from anyone else; `"any_peer"` lets every connected computer call it, so the body must check who is calling (`multiplayer.get_remote_sender_id()`) and whether it should be listening at all (`is_host()`). Chiip has three any_peer functions and every one starts with that check. Unity's Netcode has the same split (`ServerRpc` with or without `RequireOwnership`).
- A packet is just bytes: `bytes_to_var()` turns them into numbers, text, arrays and dictionaries and never into objects, while `bytes_to_var_with_objects()` can create objects (and run their scripts' setters): never use it, or `str_to_var()`, on network data. `SceneMultiplayer.allow_object_decoding` must stay false for the same reason.
- A value can have the right type and still be hostile: a `float` can be NaN or infinite, an `int` negative or huge, a `String` megabytes long. Check the shape, then the type, then the range, then the size, and drop what doesn't fit, as `NetProtocol.unpack_commands()` and `NetHost._on_request()` do.
- Limits count something per second (here: per second of physics ticks, `NetSession.allow()`), so a flood costs the sender and nobody else.


**Files that are not resources in an export** (`include_filter` of an export preset, `FileAccess` on `res://`)
- An export packs the project's *resources* (scenes, scripts, textures, imported assets) into one `.pck` file. A plain file such as `LICENSE`, which has no importer, is left out unless the preset's **Resources → Filters to export non-resource files** lists it (`LICENSE, LICENSE-ASSETS, ...`, comma separated, glob patterns). Once listed it sits in the pck and `FileAccess.get_file_as_string("res://LICENSE")` reads it exactly as in the editor. Unity's counterpart is the `StreamingAssets` folder, whose files are copied untouched into the build and read with normal file calls.
- Checking for it: `FileAccess.file_exists()` is false for a file the export left out, so the Licences screen shows "not in this build" instead of an empty page (`LicensesMenu.read_file()`), and a test can catch it.

**Godot's own licence texts** (`Engine.get_license_text()`, `get_license_info()`, `get_copyright_info()`)
- The engine carries its licence, the list of every third-party library inside it with its copyright lines, and the text of each licence. A game that ships the engine must show these notices (MIT asks for the copyright line, the libraries' licences for theirs); `Engine.get_*_info()` returns them, so a credits screen is a few lines of code and always matches the engine of the build. Unity keeps its third-party notices in a separate "Third Party Notices" file you ship by hand.

**Toggle buttons in a group** (`Button.toggle_mode`, `ButtonGroup`)
- A `Button` with `toggle_mode = true` stays pressed after a click. Give several buttons the same `ButtonGroup` and pressing one releases the others: a radio-button list without a special control. The Licences list uses it so the picked document stays highlighted; `set_pressed_no_signal(true)` marks one from code without firing `pressed` (Unity's `ToggleGroup` and `Toggle.SetIsOnWithoutNotify`).

**A theme reaches through layers** (`UiTheme.apply()`)
- `Control.theme` is inherited down a tree of `Control`s, but a `CanvasLayer` is not a `Control`, so it stops inheritance. Chiip's `UiTheme.apply(root)` therefore walks through non-Control nodes and sets the theme on the first `Control`s below each layer: a `CanvasLayer` menu instanced inside another menu (the Licences screen inside the settings menu) is scaled together with it, without its own call.

**Looking up this computer's addresses, and the clipboard** (`IP.get_local_addresses()`, `DisplayServer.clipboard_set()`)
- `IP.get_local_addresses()` lists every address of every network interface, IPv4 and IPv6, including loopback and link-local ones; the game filters it (Unity: `NetworkInterface.GetAllNetworkInterfaces()`). A Tailscale device appears as one more interface, with an address in 100.64.0.0/10.
- `DisplayServer.clipboard_set(text)` and `clipboard_get()` are the clipboard (Unity: `GUIUtility.systemCopyBuffer`). A headless run has no clipboard, so a test asks `DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)` first.

**Time in a test that runs at a fixed frame rate** (`Time.get_ticks_msec()` against `SceneTreeTimer`)
- `--fixed-fps 128` makes every frame exactly 1/128 s of *game* time however fast it really runs, so `create_timer(1.5)` fires after 192 frames in a fraction of a second of wall-clock time. `Time.get_ticks_msec()` is the wall clock: a "Copied" label that reset itself by comparing ticks never reset in the test. The Copy button counts presses instead. (This is also why CLAUDE.md says to count time in deltas.)

## M14: stats and training

**Data classes and a file that reads and writes them** (`RefCounted`, `JSON`, `FileAccess`, typed `Dictionary`)
- A class that only holds data extends `RefCounted` (Unity: a plain C# class, no `MonoBehaviour`, no `ScriptableObject`): it is counted and freed by itself and never enters the scene tree. `StatsMatch`, `StatsWeapon` and `StatsTotals` are such classes; each has `to_dict()` and a static `from_dict()` (Unity: `JsonUtility.ToJson` / `FromJson`, but written by hand, because a damaged file must give a safe value instead of throwing).
- `JSON.stringify(data, "\t")` writes a dictionary or array as text; `JSON.new().parse(text)` reads it back and returns an error code instead of printing one (the static `JSON.parse_string()` just returns `null`). **JSON has no integers: every number comes back as a `float`**, so `from_dict()` turns counts back with `int()` (`StatsMath.clean_count()`), and a test that compares must too.
- `Dictionary[String, StatsWeapon]` is a typed dictionary (Godot 4.4+; Unity: `Dictionary<string, StatsWeapon>`): the editor and the compiler know what comes out of it.
- A file is never trusted: any value read from it is cleaned (the right type, in a range, finite: `is_finite()` catches NaN and infinity), a list entry that isn't one is skipped, and a file that can't be read at all is moved aside (`DirAccess.rename_absolute()`) rather than overwritten, so the player's data is never lost to a bug.
- Saving writes `stats.json.tmp` and then renames it over the real file (`DirAccess.rename_absolute()`): a rename is one step, so a crash in the middle leaves the old file or the new one, never half of either.

**Building a table in code** (`HFlowContainer`, `ProgressBar`, `Label.clip_text`)
- `HFlowContainer` lays its children out in a row and wraps to a new line when the row is full (CSS flex-wrap; Unity: a `GridLayoutGroup` with a flexible column count): the Overview's tiles fill the width at any window size.
- `ProgressBar` with `show_percentage = false` is a bar for any 0–100 value (here the share of matches won). Its look comes from the theme like every control's.
- A table is a column of rows, each an `HBoxContainer` of `Label`s with a fixed `custom_minimum_size.x`, one expanding (`SIZE_EXPAND_FILL`) and `clip_text` so a long text can't push the others around. Dynamic rows are built after the UI scale is known and sized with `UiTheme.apply_sizes()`.
