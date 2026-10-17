class_name ExchangeRules
extends RefCounted
## Pure rules; exact-size connected subsets preserve the value of excess coins.

const VALUES := [1, 5, 10, 50, 100, 500]
const REQUIRED := [5, 2, 5, 2, 5, 2]
const RADII := [32.0, 40.0, 48.0, 56.0, 66.0, 78.0]
const WEIGHTS := [30, 25, 20, 12, 9, 4]
# Two visible pixel-art pixels accommodate tiny gaps and collision bounce.
const CONTACT_SLOP := 8.0
const BASE_SCORES := [5, 10, 50, 100, 500, 10000]
const MAX_SCORE: int = 9223372036854775807

static func chain_multiplier(chain: int) -> int:
	var count := maxi(chain, 1)
	# 16^16 already exceeds a signed 64-bit integer. Never use floating-point
	# pow() for scoring: large integer scores must remain exact.
	if count >= 16:
		return MAX_SCORE
	var multiplier := 1
	for i in count:
		multiplier *= count
	return multiplier

@warning_ignore("integer_division")
static func exchange_score(tier: int, chain: int) -> int:
	var base: int = BASE_SCORES[tier]
	var multiplier := chain_multiplier(chain)
	if multiplier > MAX_SCORE / base:
		return MAX_SCORE
	return base * multiplier

static func add_score(total: int, earned: int) -> int:
	return MAX_SCORE if earned > MAX_SCORE - total else total + earned

static func connected_batch(coins: Array) -> Array:
	var visited: Dictionary = {}
	for seed in coins:
		if visited.has(seed) or not seed.exchange_ready():
			continue
		var component: Array = [seed]
		visited[seed] = true
		var cursor := 0
		while cursor < component.size():
			var current = component[cursor]
			cursor += 1
			for other in coins:
				if visited.has(other) or other.tier != seed.tier or not other.exchange_ready():
					continue
				var reach: float = current.radius + other.radius + CONTACT_SLOP
				if current.position.distance_squared_to(other.position) <= reach * reach:
					visited[other] = true
					component.append(other)
		# BFS order guarantees the consumed prefix is itself connected.
		if component.size() >= REQUIRED[seed.tier]:
			return component.slice(0, REQUIRED[seed.tier])
	return []

static func roll_tier(rng: RandomNumberGenerator) -> int:
	var roll := rng.randi_range(1, 100)
	for tier in WEIGHTS.size():
		roll -= WEIGHTS[tier]
		if roll <= 0:
			return tier
	return 0
