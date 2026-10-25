class_name TwoPlayer
## The choices made on the two-player screen, kept while the battle loads.

enum Mode { COOP, VERSUS }
enum Layout { SIDE_BY_SIDE, TOP_AND_BOTTOM }

## Keyboard and mouse; any other number is a controller's device id.
const KEYBOARD := -1

static var mode := Mode.COOP
static var layout := Layout.SIDE_BY_SIDE
static var devices: Array[int] = [KEYBOARD, 0]
## Player 2's aircraft (player 1 flies the one chosen in the hangar).
static var second_aircraft := "scout"
static var theater := 0
static var time_of_day := Weather.TimeOfDay.NOON
static var weather := Weather.Kind.CLEAR
