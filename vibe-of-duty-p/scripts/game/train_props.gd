@tool
class_name TrainProps
extends Node3D
## Read Docs/LEVEL_TRAIN.md first (what is edited where, the rules for hand edits); update it with any change here.
## A decked level's furniture, cover and cargo (the train, the plane, the tower): Blocks edited by hand in the level
## scene (the shell around them comes from a tools/make_*_map.py). Puts every Block under it on its deck's render
## layer by the height of its centre, so a lamp lights only its own deck (the lamps cast no shadows): a block moved to
## the other deck follows.

const DECK_LAYERS: Array[int] = [4, 8, 16]  # render layers 3 train_lower, 4 train_upper, 5 deck_3 (project.godot)

## Heights between the decks, lowest first: the middle of each upper floor slab (the generator's DECK_SPLITS).
@export var deck_splits: PackedFloat32Array = [3.15]


func _ready() -> void:
	for node in find_children("*", "", true, false):
		if node is Block:
			var block := node as Block
			var deck := 0
			for split in deck_splits:
				if block.global_position.y >= split:
					deck += 1
			block.mesh_layers = DECK_LAYERS[mini(deck, DECK_LAYERS.size() - 1)]
