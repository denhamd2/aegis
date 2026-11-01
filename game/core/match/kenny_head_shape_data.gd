class_name KennyHeadShapeData
extends Resource
## Kenny's head shape, photo-fitted from the owner's sheet onto Cody's head
## (tools/assets/build_kenny_head.py writes it; KennyFaceShape applies it):
## for each moved vertex of the head's skin and the mouth's inside, its rest
## position on Cody's head, how far it moves, and how its normal changes.

@export var rest := PackedVector3Array()
@export var offset := PackedVector3Array()
@export var normal_offset := PackedVector3Array()
