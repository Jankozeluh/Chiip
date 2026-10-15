class_name PhysicsLayers
## Bit values of Chiip's physics layers, matching the names in
## Project Settings → Layer Names → 3D Physics. Use these instead of raw
## numbers, e.g. [code]PhysicsLayers.WORLD | PhysicsLayers.HITBOXES[/code].

## Map geometry: floors, walls, crates.
const WORLD := 1
## The player's body.
const PLAYER := 2
## Bot bodies and target dummies (solid, but bullets pass through to their hitboxes).
const BOTS := 4
## Damage zones (head, chest, …) that bullets hit.
const HITBOXES := 8
## Trigger areas such as buy zones and bombsites.
const TRIGGERS := 16
