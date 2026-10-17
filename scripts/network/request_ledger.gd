class_name RequestLedger
extends RefCounted

# Remains owned by the match, not a transport. Future reconnect must preserve it.
# High-water mark rejects evicted old IDs, so bounded storage never permits replay.
var highest := 0
var recent: Dictionary = {}
const CAPACITY := 256

func accept(value: Variant) -> bool:
	if not ScenarioDefinition.integer(value, highest + 1, 100000000): return false
	highest = int(value)
	recent[highest] = true
	if recent.size() > CAPACITY: recent.erase(recent.keys()[0])
	return true
