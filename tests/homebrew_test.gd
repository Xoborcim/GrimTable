extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run() -> void:
	ContentRegistry.catalog()
	var pack:=HomebrewPack.fresh("qa_homebrew_0150")
	var weapon:=HomebrewPack.weapon(pack);weapon.tags=["anti_heavy"];pack.weapons.append(weapon)
	var unit:=HomebrewPack.unit(pack);unit.weapons=[weapon.id];unit.roster.role="Leader";unit.roster.min_size=1;unit.roster.max_size=1;pack.units.append(unit)
	check(HomebrewPack.validate(pack).is_empty(),"Custom faction, unit and weapon validate")
	check(AttackResolver.strength_against(weapon,{"roster":{"role":"Walker"}})==6,"Anti-heavy trait changes canonical strength")
	check(AttackResolver.strength_against(weapon,{"roster":{"role":"Infantry"}})==4,"Trait only affects supported target classes")
	var bad:=pack.duplicate(true);bad.weapons[0].tags=["execute_script"]
	check(not HomebrewPack.validate(bad).is_empty(),"Unimplemented abilities rejected")
	bad=pack.duplicate(true);bad.units[0].script="evil.gd"
	check(not HomebrewPack.validate(bad).is_empty(),"Executable unit fields rejected")
	bad=pack.duplicate(true);bad.units[0].visual="third_party.glb"
	check(not HomebrewPack.validate(bad).is_empty(),"Rules export never auto-packages user models")
	bad=pack.duplicate(true);bad.weapons[0].damage=-1
	check(not HomebrewPack.validate(bad).is_empty(),"Invalid combat numbers rejected")
	bad=pack.duplicate(true);bad.manifest.id="../escape"
	check(not HomebrewPack.validate(bad).is_empty(),"Unsafe pack paths rejected")
	bad=pack.duplicate(true);bad.units[0].weapons=["missing:weapon"]
	check(not HomebrewPack.validate(bad).is_empty(),"Missing equipment dependencies rejected")
	var installed:=HomebrewPack.install(pack)
	check(installed.begins_with("Installed"),"Pack installed through existing mod loader: "+installed)
	check(ContentRegistry.catalog().factions.has("qa_homebrew_0150:faction"),"Custom faction in canonical registry")
	check(ContentRegistry.validate().is_empty(),"Installed content validation")
	var army:=ArmyRoster.fresh("qa_homebrew_0150:faction",500);army.units.append(ArmyRoster.entry(unit.id));ArmyRoster.stamp(army)
	check(ArmyRoster.errors(army).is_empty(),"Homebrew army uses same roster validator")
	check(army.homebrew and army.dependencies.size()==1,"Homebrew and pack identity persist")
	check(ContentRegistry.weapons(ArmyRoster.profile(unit.id))[0].name==weapon.name,"Custom weapon resolves from mod definitions")
	pack.manifest.version="1.0.1";pack.units[0].roster.points_per_model=20
	check(HomebrewPack.install(pack).begins_with("Installed"),"Update preserves previous pack and reloads content")
	check(not ArmyRoster.errors(army).is_empty(),"Old army reports updated dependency and profile")
	var app: Node=load("res://scenes/main/app.tscn").instantiate();root.add_child(app);await process_frame
	var editor_ui: HomebrewEditor=app.show_homebrew();await process_frame
	check(editor_ui.left.get_child_count()>6 and editor_ui.form.get_child_count()>10,"Player-facing faction editor loads")
	editor_ui.category="Unit";editor_ui.selected=0;editor_ui.refresh()
	check(editor_ui.form.get_child_count()>15,"Custom unit editing controls are functional")
	editor_ui.document.weapons.append(HomebrewPack.weapon(editor_ui.document));editor_ui.category="Weapon";editor_ui.selected=0;editor_ui.refresh()
	check(editor_ui.form.get_child_count()>10,"Custom weapon editing controls are functional")
	app.queue_free();await process_frame
	# Remove only explicitly named QA definitions; never touch personal packs.
	var folder:="user://mods/qa_homebrew_0150"
	for category in ["units","weapons","factions"]:
		for item in pack[category]:DirAccess.remove_absolute(folder+"/"+category+"/"+str(item.id).get_slice(":",1)+".json")
		DirAccess.remove_absolute(folder+"/"+category)
	for name in ["manifest.json","grimtable_homebrew.json"]:DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder);ContentRegistry.reload_content()
	print("GRIMTABLE HOMEBREW ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
