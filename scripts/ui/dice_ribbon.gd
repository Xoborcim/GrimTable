class_name DiceRibbon
extends Control

var groups: Array[Dictionary] = []
var font: Font = preload("res://assets/third_party/fonts/barlow/barlow_semibold.ttf")

func add_group(title: String, rolls: Array, threshold: int) -> void:
	groups.append({"title":title,"rolls":rolls.duplicate(),"threshold":threshold})
	custom_minimum_size = Vector2(330,groups.size()*48)
	tooltip_text = "\n".join(groups.map(func(group): return group.title+": "+str(group.rolls)))
	queue_redraw()

func _draw() -> void:
	for row in groups.size():
		var group := groups[row]
		draw_string(font,Vector2(0,row*48+12),group.title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,GrimTheme.MUTED)
		for i in mini(12,group.rolls.size()):
			var value := int(group.rolls[i])
			var success := value >= int(group.threshold)
			var box := Rect2(Vector2(i*26,row*48+18),Vector2(23,24))
			var style := GrimTheme.surface(GrimTheme.PLAYER.darkened(.5) if success else GrimTheme.LINE,true)
			style.shadow_size = 0
			draw_style_box(style,box)
			draw_string(font,box.position+Vector2(7,18),str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,17,GrimTheme.TEXT if success else GrimTheme.MUTED)
