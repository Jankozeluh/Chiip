# Chiip: third-party notices

Chiip is made with the material below, which keeps its own licences. This file
ships inside every build, next to `LICENSE` (the game's code, GPL-3.0) and
`LICENSE-ASSETS` (art, models, maps and sounds, CC BY-NC-SA 4.0). The same
texts are in the game: **Settings → Licences**. The source of this list is
[docs/CREDITS.md](docs/CREDITS.md).

> Last updated: 2026-10-16

## Godot Engine 4.7.2 (MIT)

<https://godotengine.org>

Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

The engine itself contains third-party libraries (FreeType, ENet, Jolt Physics,
mbedTLS, zlib and others), each with its own licence. Their notices are part of
the engine and are shown in the game under **Settings → Licences → Godot Engine**.

## FuncGodot 2025.12 (MIT)

`addons/func_godot/`: <https://github.com/func-godot/func_godot_plugin>.
Reads the maps made in TrenchBroom.

Copyright (c) 2023 func-godot

The MIT licence text is in `addons/func_godot/LICENSE` (the same words as the
Godot licence above, with this copyright line).

## Silkscreen (SIL Open Font License 1.1)

`assets/fonts/Silkscreen-Regular.ttf` and `Silkscreen-Bold.ttf`, by Jason Kottke:
<https://github.com/googlefonts/silkscreen>.

Copyright 2001 The Silkscreen Project Authors.

The full licence is in `assets/fonts/Silkscreen-OFL.txt`. The font is used and
shipped as it is, under its own licence, and is not sold on its own.

## Made for Chiip (not third-party)

Every texture, model, sound and map in Chiip is drawn, generated or built for
the game by `tools/` (see [docs/CREDITS.md](docs/CREDITS.md)) and is covered by
`LICENSE-ASSETS`. Earlier versions of the textures were CC0 photo textures from
ambientCG (<https://ambientcg.com>); they were replaced and are no longer in the
game.

## Tools used to make the game (not shipped)

TrenchBroom (map editor, GPL-3.0; the licence covers the editor, not the maps),
Python with NumPy (BSD-3-Clause) and Pillow (MIT-CMU), and the Godot export
templates (MIT). None of them is part of a build.
