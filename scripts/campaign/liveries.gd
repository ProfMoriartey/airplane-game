class_name Liveries
## Paint schemes the player can choose for their aircraft in the hangar.

## The first entry means "as designed": the aircraft's own colours.
const LIVERIES := [
	{name = "Factory finish"},
	{name = "Khaki", paint = Color(0.45, 0.42, 0.28), wings = Color(0.8, 0.75, 0.6)},
	{name = "Forest green", paint = Color(0.18, 0.26, 0.16), wings = Color(0.62, 0.6, 0.48)},
	{name = "Silver dope", paint = Color(0.7, 0.7, 0.68), wings = Color(0.84, 0.84, 0.82)},
	{name = "Squadron blue", paint = Color(0.2, 0.28, 0.45), wings = Color(0.82, 0.78, 0.65)},
]


static func paint(aircraft: AircraftStats, livery: int) -> Color:
	return LIVERIES[livery].get("paint", aircraft.paint_color)


static func wings(aircraft: AircraftStats, livery: int) -> Color:
	return LIVERIES[livery].get("wings", aircraft.wing_color)
