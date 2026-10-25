class_name TheaterPresets
## Terrain settings for each theater's landscape, for levels that pick one at
## runtime (like Quick Battle). Campaign missions store theirs in their scenes.

const THEATERS := [
	{
		name = "The Quiet Sector (farmland)",
		terrain = {},
		cloud_altitude = 650.0,
		start_height = 350.0,
	},
	{
		name = "Mud and Wire (front line)",
		terrain = {
			terrain_seed = 1916, height_scale = 90.0, forest_cover = 0.15, pine_share = 0.2,
			field_colors = [Color(0.4, 0.35, 0.24), Color(0.36, 0.33, 0.25), Color(0.45, 0.4, 0.28), Color(0.33, 0.36, 0.22), Color(0.42, 0.38, 0.3)],
			rock_color = Color(0.35, 0.3, 0.24), tree_color = Color(0.2, 0.22, 0.14),
			water_level = 4.0, river_width = 0.03, river_max_height = 50.0,
		},
		cloud_altitude = 600.0,
		start_height = 300.0,
	},
	{
		name = "The High Passes (mountains)",
		terrain = {
			terrain_seed = 1918, height_scale = 380.0, forest_cover = 0.3, pine_share = 0.85, snow_height = 150.0,
			field_colors = [Color(0.32, 0.42, 0.22), Color(0.38, 0.46, 0.26), Color(0.3, 0.38, 0.22), Color(0.42, 0.44, 0.3)],
			rock_color = Color(0.48, 0.47, 0.45), tree_color = Color(0.12, 0.2, 0.12),
			water_level = 10.0, rivers = false, edge_height = 500.0,
		},
		cloud_altitude = 950.0,
		start_height = 650.0,
	},
]


## Applies a theater to a Terrain before it builds itself (call from _enter_tree).
static func apply(index: int, terrain: Terrain) -> void:
	for property: String in THEATERS[index].terrain:
		var value: Variant = THEATERS[index].terrain[property]
		if property == "field_colors":
			var colors: Array[Color] = []
			colors.assign(value)
			value = colors
		terrain.set(property, value)
