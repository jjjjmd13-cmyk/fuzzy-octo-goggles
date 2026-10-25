extends Node3D
## 바닥에 놓인 기름병 (+oil_bottle_amount). 호스트가 taken 을 정해 보낸다.
## 겉모습은 scenes/art/oil_bottle_model.tscn.

var taken := false:
	set(value):
		taken = value
		if is_node_ready():
			$Model.visible = not taken


func _ready() -> void:
	add_to_group("oil_bottles")
	$Model.visible = not taken
