extends "res://tools/benchmark_composition_0131.gd"

func run() -> void:
	if "--custom" in OS.get_cmdline_user_args():
		var data:=WorkshopStore.fresh();data.name="Benchmark cosmetic"
		data.colors.primary="536c57";data.parts.head=1;data.parts.backpack=2;data.parts.shoulders=2;data.parts.weapon=1
		var overlay:=Image.create(1024,1024,false,Image.FORMAT_RGBA8);overlay.fill(Color.TRANSPARENT)
		overlay.fill_rect(Rect2i(128,128,64,12),Color("c9ad65"))
		var saved:=WorkshopStore.save(data,overlay)
		if saved.has("error"):push_error(saved.error);quit(1);return
		WorkshopStore.assign("profile","legion_trooper",saved.id)
	await super.run()
