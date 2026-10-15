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
