class_name LooseCargo
extends Node3D
## Read Docs/LEVEL_PLANE.md first. Cargo that is not bolted down: the Blocks under this node slide across the plane
## together when it banks (PlaneBank). Keep the node itself at the origin, unrotated: PlaneBank moves it along x.

## Bank (degrees) it takes to set this cargo sliding: crates and reels go first, the tank only on a steep bank.
@export var grip := 5.0
