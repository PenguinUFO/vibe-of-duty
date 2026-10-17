class_name Layers
## Physics layer bit masks. Keep in sync with [layer_names] in project.godot.

const WORLD := 1 << 0     # level geometry
const PLAYER := 1 << 1    # player movement capsules
const HITBOX := 1 << 2    # per-bone hit detection (lag compensation raycasts)
const PICKUP := 1 << 3
const TRIGGER := 1 << 4

## What a player body collides with while moving.
const PLAYER_MOVE_MASK := WORLD | PLAYER
## What a hitscan shot traces against.
const HITSCAN_MASK := WORLD | HITBOX
