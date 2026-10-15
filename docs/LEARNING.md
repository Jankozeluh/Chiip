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

*To be written during M1.*
