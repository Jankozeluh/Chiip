# Chiip — Credits

> Every third-party asset and tool used in Chiip, with its source and license. Update this file whenever something is added (see CLAUDE.md).
>
> Last updated: 2026-10-16

## Engine

| What | Source | License |
|---|---|---|
| Godot Engine 4.7.2 | https://godotengine.org | MIT. Its license notice must be included with any shipped build of the game (e.g. in the credits screen or a text file next to the game). |

## Textures

All textures come from **ambientCG** (https://ambientcg.com) under **CC0 1.0 Universal** (public domain). Free for any use, including commercial, and attribution isn't required, but we credit them anyway. Each one was shrunk to 64 × 64 and reduced to 16 colors with `tools/make_retro_texture.gd`. Only the processed files are kept in the project.

| File | ambientCG asset | Contrast | Brightness | Saturation |
|---|---|---|---|---|
| `assets/textures/concrete_floor.png` | Concrete034 | 3.0 | 0.62 | 1.0 |
| `assets/textures/plaster_wall.png` | Plaster001 | 3.0 | 0.8 | 1.0 |
| `assets/textures/stone_grey.png` | Bricks075A | 1.1 | 0.9 | 0.12 |
| `assets/textures/bricks_red.png` | Bricks097 | 1.1 | 0.9 | 0.6 |
| `assets/textures/gravel_grey.png` | Ground080 | 3.0 | 0.72 | 0.1 |
| `assets/textures/wood_planks.png` | Planks037A | 1.4 | 1.0 | 1.0 |
| `assets/textures/metal_plates.png` | MetalPlates006 | 2.0 | 1.0 | 1.0 |
| `assets/textures/painted_plaster.png` | PaintedPlaster017 | 2.5 | 0.85 | 1.0 |

To recreate one: download `<asset>_1K-JPG.zip` from ambientCG, extract `<asset>_1K-JPG_Color.jpg`, and run the tool with the contrast, brightness and saturation values above (see CLAUDE.md).

### Texture library (M10 map kit, D-121)

28 more ambientCG textures (CC0 1.0), downloaded on 2026-10-16 within your approval of about 30 (D-120): the 1K-JPG zips, 1.8–11 MB each, 173 MB in all, kept outside the project and deleted afterwards. Each was turned into 64 × 64 with 16 colors by `tools/make_retro_texture.gd`, in four set folders that TrenchBroom shows as collections. Every one passes `tools/texture_report.gd` (no team red or blue, muted colours). Each has a material in `assets/materials/<set>/`.

Eight of them needed their source prepared first, because their colour map alone turns into flat grey or noise at 64 × 64: `tools/texture_prep.py` (Python, in the `chiip` environment) bakes the relief from the asset's Displacement map into the colour, crops fine patterns, turns a hue, or draws a pattern (roof shingles, the chain-link's diamond lattice), as noted below. To recreate them: extract the assets' `_Color.jpg` and `_Displacement.jpg` (and Fence007A's `_Color.jpg`) into one folder per asset, run `texture_prep.py <that folder> <out>`, then the tool on `<out>/<name>.png` (for the chain-link add `<out>/chainlink_opacity.png` as the 8th argument). The others use the asset's `_Color.jpg` directly.

| File (in `assets/textures/`) | ambientCG asset | Contrast | Brightness | Saturation | Source prepared first |
|---|---|---|---|---|---|
| `industrial/corrugated_grey.png` | CorrugatedSteel005 | 1.1 | 0.72 | 0.3 | prep: ribs from the displacement map |
| `industrial/corrugated_green.png` | CorrugatedSteel006A | 1.4 | 1.55 | 0.32 | prep: ribs from the displacement map, hue −38° (olive) |
| `industrial/diamond_plate.png` | DiamondPlate008B | 1.4 | 1.0 | 0.2 | prep: lugs from the displacement map, top-left quarter |
| `industrial/rust_plates.png` | MetalPlates011 | 1.4 | 1.1 | 0.2 | prep: hue +12° (brown, not red) |
| `industrial/grate.png` | MetalWalkway007 | 1.6 | 1.2 | 0.2 | — |
| `industrial/chainlink.png` | Fence007A | 1.3 | 0.8 | 0.2 | prep: the asset's metal colour, a drawn diamond lattice as the opacity map |
| `industrial/concrete_worn.png` | Concrete042B | 2.0 | 0.95 | 0.3 | — |
| `industrial/perforated.png` | SheetMetal004 | 1.4 | 1.0 | 0.2 | prep: holes from the displacement map, top-left quarter |
| `urban/asphalt.png` | Asphalt031 | 2.5 | 0.8 | 0.2 | — |
| `urban/cobbles.png` | PavingStones150 | 1.5 | 0.85 | 0.2 | — |
| `urban/slabs.png` | PavingStones136 | 2.0 | 0.8 | 0.2 | — |
| `urban/blocks_grey.png` | Bricks066 | 1.5 | 0.85 | 0.2 | — |
| `urban/rubble_wall.png` | Bricks102 | 1.3 | 0.85 | 0.3 | — |
| `urban/roof_slate.png` | RoofingTiles013A | 1.2 | 1.0 | 0.2 | prep: shingles drawn by the tool, the asset's colour map as the stone grain |
| `urban/wood_siding.png` | WoodSiding008 | 1.6 | 1.4 | 0.6 | — |
| `urban/plaster_olive.png` | PaintedPlaster012 | 2.5 | 0.85 | 0.8 | — |
| `interior/wood_floor_dark.png` | WoodFloor043 | 1.3 | 1.0 | 0.5 | — |
| `interior/parquet.png` | WoodFloor052 | 1.3 | 0.9 | 0.6 | — |
| `interior/tiles_white.png` | Tiles107 | 2.5 | 0.55 | 0.2 | — |
| `interior/tiles_dark.png` | Tiles138 | 1.4 | 1.0 | 0.2 | prep: grout from the displacement map, top-left quarter |
| `interior/tiles_checker.png` | Tiles074 | 1.0 | 0.85 | 0.2 | — |
| `interior/ceiling_tiles.png` | OfficeCeiling005 | 1.3 | 0.6 | 0.1 | — |
| `interior/terrazzo.png` | Terrazzo011 | 2.0 | 0.6 | 0.3 | — |
| `interior/planks_old.png` | Planks023A | 1.6 | 1.0 | 0.5 | — |
| `nature/grass.png` | Grass003 | 1.6 | 1.2 | 0.38 | — |
| `nature/dirt.png` | Ground112 | 1.6 | 0.9 | 0.4 | — |
| `nature/rock_moss.png` | Rock063 | 1.5 | 0.9 | 0.33 | — |
| `nature/bark.png` | Bark001 | 1.3 | 0.7 | 0.4 | — |

## Fonts

| File | Source | License |
|---|---|---|
| `assets/fonts/Silkscreen-Regular.ttf`, `Silkscreen-Bold.ttf` | Silkscreen by Jason Kottke, via Google Fonts (https://github.com/google/fonts/tree/main/ofl/silkscreen) | SIL Open Font License 1.1. The license text is in `assets/fonts/Silkscreen-OFL.txt` and must ship with the game. The font may be used and embedded in a commercial game but not sold on its own. |

## Addons (part of the project)

| What | Source | License |
|---|---|---|
| `addons/func_godot/`: FuncGodot 2025.12 (imports TrenchBroom `.map` files) | https://github.com/func-godot/func_godot_plugin | MIT (`addons/func_godot/LICENSE`) |

## Tools (used to make the game, not shipped with it)

| What | Source | License |
|---|---|---|
| TrenchBroom v2026.2 (map editor) | https://github.com/TrenchBroom/TrenchBroom | GPL-3.0. The license covers the editor, not maps made with it. |
| Godot 4.7.2 export templates (`Godot_v4.7.2-stable_export_templates.tpz`, 1.28 GB, SHA-512 `ca4d71c4…ccb84079`, checked against the release's `SHA512-SUMS.txt`), downloaded 2026-10-15 with your OK (M8) and installed in `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` | https://github.com/godotengine/godot/releases/tag/4.7.2-stable | MIT, like the engine. The macOS template becomes the game's executable in every exported build, so the Godot license notice applies to the builds (see Engine above). |
| Miniconda (Python distribution, installed in `~/miniconda3`, D-071) | https://repo.anaconda.com/miniconda/ (`Miniconda3-latest-MacOSX-arm64.sh`, SHA-256 checked) | Free under Anaconda's Miniconda end-user licence. Packages from Anaconda's default channels (`pkgs/main`, `pkgs/r`) fall under the Anaconda Terms of Service, which you accepted on 2026-10-15. Nothing from it ships with the game. |
| Python 3.12 (in the `chiip` conda environment) | https://www.python.org | PSF License |
| NumPy | https://numpy.org | BSD-3-Clause |
| Pillow | https://python-pillow.org | MIT-CMU (HPND) |
| ambientCG preview images (128-pixel thumbnails of about 300 candidate textures, fetched through ambientCG's public API to choose the library, 2026-10-16) | https://ambientcg.com | CC0 1.0, like the textures. Kept outside the project and deleted afterwards. |

## Made for Chiip

- Sounds: generated by `tools/generate_sounds.gd` (rifle shot, empty click, reload clack, footsteps on four surfaces, the bomb, bullet impacts, body and head hits, interface sounds and round stingers).
- Spray pattern, weapon stats, test map, target dummy and first-person rifle model: made for Chiip.
- The AK-style rifle (`assets/models/weapons/ak_rifle.glb`) and the first-person arms (`assets/models/crew/<class>_arms.glb`): generated by `tools/modelgen/`.
- Crew models, their textures and animations (`assets/models/crew/`): generated by `tools/modelgen/` (D-054), from the concept designs in `tools/concept/`.
- The map kit's props and lamps (`assets/models/props/`, `maps/kit/`): generated by `tools/modelgen/` from the part lists in `props.py` (D-122).
- Textures drawn for the kit: `assets/textures/interior/glass.png`, `industrial/hazard_stripes.png` and `industrial/floor_line.png` (the base `concrete_floor` with a painted line): `tools/make_kit_textures.py` (D-121).
