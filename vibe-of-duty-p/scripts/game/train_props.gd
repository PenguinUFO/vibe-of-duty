@tool
class_name TrainProps
extends Node3D
## Read Docs/LEVEL_TRAIN.md first (what is edited where, the rules for hand edits); update it with any change here.
## The train's furniture, cover and cargo: Blocks edited by hand in prefabs/levels/train.tscn (the shell around them
## comes from tools/make_train_map.py). Puts every Block under it on its deck's render layer by the height of its
## centre, so a lamp lights only its own deck (the lamps cast no shadows): a block moved to the other deck follows.

const LAYER_LOWER := 4    # render layer 3, train_lower (project.godot)
const LAYER_UPPER := 8    # render layer 4, train_upper
const DECK_SPLIT := 3.15  # m: the middle of the upper floor slab (tools/make_train_map.py DECK_SPLIT)


func _ready() -> void:
	for node in find_children("*", "", true, false):
		if node is Block:
			var block := node as Block
			block.mesh_layers = LAYER_LOWER if block.global_position.y < DECK_SPLIT else LAYER_UPPER
