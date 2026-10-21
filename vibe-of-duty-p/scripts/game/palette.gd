class_name Palette
extends RefCounted
## The game's palette (Docs/AUTHOR.md, "Визуал"): darkness and warm greys; accents are rare, muted and mean something.
## tools/make_train_map.py keeps a copy of these values (Python can't read this file) - change both.

# Neutrals: warm dark greys (hue 15-40 deg, saturation < 0.08), darkest first.
const GREY_0 := Color("#100f0e")
const GREY_1 := Color("#1b1a19")
const GREY_2 := Color("#262523")
const GREY_3 := Color("#36322f")
const GREY_4 := Color("#48413f")
const GREY_5 := Color("#635f58")
const GREY_6 := Color("#8a857c")  # light: text-adjacent only, never large areas
const PALE := Color("#d8d2c6")    # text

# Accents. Each one means one thing.
const EMBER := Color("#cc8746")       # light, where to go: lamps, muzzle flashes, tracers
const OLIVE := Color("#6a7a31")       # something to pick up (ammo bags); "good" in the UI
const OLIVE_DARK := Color("#505c23")
const OLIVE_DEEP := Color("#2f3214")
const SIGNAL := Color("#fc3100")      # danger and "about you": damage, your own lines, focused buttons
const RUST := Color("#5e392a")        # wood; tells the cars apart

# The cold dusk (Mood): sky, shade and fog. Cool and dim, desaturated - the warm in the frame is only the lamps.
const DUSK_ZENITH := Color("#0b0e14")
const DUSK_HORIZON := Color("#4a5560")
const DUSK_SHADE := Color("#56606e")
const DUSK_FOG := Color("#151a21")
const DUSK_SUN := Color("#b4c0cc")
