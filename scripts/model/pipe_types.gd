extends RefCounted
## Shared enums + direction constants for the pure game model.
## Preloaded (no class_name) for deterministic headless loading.

# OPEN must stay 0: the terrain grid is a zero-filled PackedInt32Array.
# NOTE for S1.3: any piece-type enum must reserve 0 for NONE (no piece placed),
# or a zero-filled piece array reads as "every cell has the 0th piece type".
enum Cell { OPEN, BLOCKED, BOMB }

## Edge directions as a bitmask (a piece's open edges are an OR of these).
const N := 1
const E := 2
const S := 4
const W := 8


static func opposite(d: int) -> int:
	match d:
		N: return S
		S: return N
		E: return W
		W: return E
	return 0
