class_name SimRng
extends RefCounted
## Deterministic RNG: the same seed gives the same draws, and `state` round-trips through saves.

var _rng := RandomNumberGenerator.new()
var calls: int = 0


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## The seed of a stream of its own for one purpose (`salt`), so a change in how one purpose draws never shifts another's.
static func derived_seed(seed_value: int, salt: String) -> int:
	return hash("%d:%s" % [seed_value, salt])


static func derived(seed_value: int, salt: String) -> SimRng:
	return SimRng.new(derived_seed(seed_value, salt))


func next() -> float:
	calls += 1
	return _rng.randf()


func chance(p: float) -> bool:
	return next() < p


## Returns true with probability a^sharpness / (a^sharpness + b^sharpness).
## `sharpness` > 1 makes attribute differences weigh more.
func contest(a: float, b: float, sharpness: float = 1.0) -> bool:
	if a <= 0.0 and b <= 0.0:
		return next() < 0.5
	var pa: float = pow(maxf(a, 0.01), sharpness)
	var pb: float = pow(maxf(b, 0.01), sharpness)
	return next() < pa / (pa + pb)


func irange(a: int, b: int) -> int:
	calls += 1
	return _rng.randi_range(a, b)


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[irange(0, arr.size() - 1)]


## Picks an index according to (unnormalized) weights.
func pick_weighted(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var r := next() * total
	var acc := 0.0
	for i in weights.size():
		acc += maxf(weights[i], 0.0)
		if r < acc:
			return i
	return weights.size() - 1


func gauss(mean: float, sd: float) -> float:
	calls += 2
	return _rng.randfn(mean, sd)


func get_state() -> int:
	return _rng.state


func set_state(st: int) -> void:
	_rng.state = st
