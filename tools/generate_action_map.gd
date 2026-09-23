extends SceneTree
## Regenerates res://openxr_action_map.tres.
##
## Starts from Godot's default action map (generic controller, Touch, Pico 4,
## hand interaction) and adds explicit bindings for the controllers people
## commonly use through SteamVR (Index, Vive, WMR) plus the Khronos simple
## controller. PSVR2 Sense controllers reach us through SteamVR, which maps
## them onto one of these profiles.
##
## Usage: godot --headless --xr-mode off --script res://tools/generate_action_map.gd

const OUTPUT := "res://openxr_action_map.tres"

const HANDS := ["left", "right"]

## profile path -> { action name: input subpath, or [left subpath, right subpath] }
const EXTRA_PROFILES := {
	"/interaction_profiles/valve/index_controller": {
		"aim_pose": "input/aim/pose",
		"grip_pose": "input/grip/pose",
		"trigger": "input/trigger/value",
		"trigger_click": "input/trigger/click",
		"trigger_touch": "input/trigger/touch",
		"grip": "input/squeeze/value",
		"grip_force": "input/squeeze/force",
		"primary": "input/thumbstick",
		"primary_click": "input/thumbstick/click",
		"primary_touch": "input/thumbstick/touch",
		"secondary": "input/trackpad",
		"secondary_touch": "input/trackpad/touch",
		"ax_button": "input/a/click",
		"ax_touch": "input/a/touch",
		"by_button": "input/b/click",
		"by_touch": "input/b/touch",
		"menu_button": "input/system/click",
		"haptic": "output/haptic",
	},
	"/interaction_profiles/htc/vive_controller": {
		"aim_pose": "input/aim/pose",
		"grip_pose": "input/grip/pose",
		"trigger": "input/trigger/value",
		"trigger_click": "input/trigger/click",
		"grip": "input/squeeze/click",
		"grip_click": "input/squeeze/click",
		"primary": "input/trackpad",
		"primary_click": "input/trackpad/click",
		"primary_touch": "input/trackpad/touch",
		# Vive wands have no face buttons; menu doubles as calibrate (B/Y).
		"by_button": "input/menu/click",
		"menu_button": "input/menu/click",
		"haptic": "output/haptic",
	},
	"/interaction_profiles/microsoft/motion_controller": {
		"aim_pose": "input/aim/pose",
		"grip_pose": "input/grip/pose",
		"trigger": "input/trigger/value",
		"trigger_click": "input/trigger/value",
		"grip": "input/squeeze/click",
		"grip_click": "input/squeeze/click",
		"primary": "input/thumbstick",
		"primary_click": "input/thumbstick/click",
		"secondary": "input/trackpad",
		"secondary_click": "input/trackpad/click",
		"secondary_touch": "input/trackpad/touch",
		"by_button": "input/menu/click",
		"menu_button": "input/menu/click",
		"haptic": "output/haptic",
	},
	"/interaction_profiles/khr/simple_controller": {
		"aim_pose": "input/aim/pose",
		"grip_pose": "input/grip/pose",
		"trigger": "input/select/click",
		"trigger_click": "input/select/click",
		"menu_button": "input/menu/click",
		"haptic": "output/haptic",
	},
}


func _initialize() -> void:
	var map := OpenXRActionMap.new()
	map.create_default_action_sets()
	var actions := {}
	for action in map.find_action_set("godot").get_actions():
		actions[action.resource_name] = action
	for profile_path in EXTRA_PROFILES:
		if map.find_interaction_profile(profile_path):
			continue
		var profile := OpenXRInteractionProfile.new()
		profile.interaction_profile_path = profile_path
		var profile_bindings: Array = []
		var paths := EXTRA_PROFILES[profile_path] as Dictionary
		for action_name in paths:
			if not actions.has(action_name):
				push_error("Unknown action %s" % action_name)
				quit(1)
				return
			for hand in HANDS:
				var binding := OpenXRIPBinding.new()
				binding.action = actions[action_name]
				binding.binding_path = "/user/hand/%s/%s" % [hand, paths[action_name]]
				profile_bindings.append(binding)
		profile.bindings = profile_bindings
		map.add_interaction_profile(profile)
	var err := ResourceSaver.save(map, OUTPUT)
	if err != OK:
		push_error("Saving %s failed: %s" % [OUTPUT, error_string(err)])
		quit(1)
		return
	print("Wrote %s with %d interaction profiles" % [OUTPUT, map.get_interaction_profile_count()])
	quit()
