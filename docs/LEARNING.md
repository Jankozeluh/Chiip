# Learning Godot, coming from Unity

> Notes on Godot concepts as Chiip uses them. Each milestone adds a section with what was new and where it's used in the project.
>
> Last updated: 2026-10-15

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

**Groups and material overrides** (`characters/soldier_body.tscn`, `Character._set_up_body`)
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

**Procedural animation** (`characters/soldier_body.gd`)
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
