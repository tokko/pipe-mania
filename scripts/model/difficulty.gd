extends RefCounted
## DifficultyConfig(n): the pinned per-board ramp (docs/ROADMAP.md). n = 0-based board
## index. Grids are capped (cells stay >=44dp in portrait); hazards capped to keep a
## solution feasible; build clock floors at 8s; cross weight rises (harder mix).

const PT = preload("res://scripts/model/pipe_types.gd")


@warning_ignore("integer_division")
static func config(n: int) -> Dictionary:
	var gw := mini(9, 5 + n / 3)
	var gh := mini(13, 7 + n / 2)
	var area := gw * gh
	return {
		"build_seconds": maxi(8, 25 - n),
		"grid_w": gw,
		"grid_h": gh,
		"bombs": mini(area / 8, n / 3),
		"blocked": mini(area / 6, 1 + n / 2),
		"weights": {
			PT.Piece.STRAIGHT: maxi(25, 45 - n),
			PT.Piece.BEND: 40,
			PT.Piece.CROSS: mini(35, 15 + n),
		},
	}
