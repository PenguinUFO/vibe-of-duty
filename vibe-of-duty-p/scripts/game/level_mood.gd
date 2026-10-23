class_name LevelMood
extends Node
## A level's own take on the PSX style's mood (Mood): the train lives in the common cold dusk, the plane flies in the
## day and the tower stands in the night. `values` overrides Mood's constants by name, the rest stay as they are:
##   sun_elevation (deg), sun_energy, sun_color, ambient_energy (x the level's), ambient_color, ambient_sky,
##   fog_density, fog_color, fog_sky_affect, saturation, contrast, and "sky" - a Dictionary of sky shader parameters
##   merged over Mood.SKY.
## Put it in the level as a node named LevelMood (Mood finds it by name).

@export var values := {}
