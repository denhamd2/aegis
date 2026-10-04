class_name Persona
extends RefCounted
## Whose side the house is on: the heel (Roman Reigns, who the crowd boos and
## who works the match slow and mean) or the face (Cody Rhodes, who they cheer
## and who sells, hopes and fires up). Anyone else is neutral.
##
## By display name, the way the roster presents them. Read by MatchFlow (the
## match's pacing), WrestlerAI (tempo) and MatchAudio (boos and cheers).

enum Kind { NEUTRAL, HEEL, FACE }


static func of(display_name: String) -> Kind:
	var n := display_name.to_upper()
	if n.contains("ROMAN") or n.contains("REIGNS"):
		return Kind.HEEL
	if n.contains("CODY") or n.contains("RHODES"):
		return Kind.FACE
	return Kind.NEUTRAL


## -1 for the heel, +1 for the face, 0 for neutral.
static func favor(display_name: String) -> float:
	match of(display_name):
		Kind.HEEL:
			return -1.0
		Kind.FACE:
			return 1.0
	return 0.0
