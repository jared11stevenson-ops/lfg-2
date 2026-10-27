class_name Calendar
extends RefCounted
## Day 1-5 PEACE, day 6 WARNING, day 7 WARNING until PURGE_START_TOD then PURGE_ACTIVE (night), next day 1 starts with RESOLUTION.
const PURGE_START_TOD := 0.5
const RESOLUTION_END_TOD := 0.12
const EPS := 1e-7
const DAYS_PER_WEEK := 7

static func phase_for(day: int, tod: float) -> StringName:
	var dow: int = ((day - 1) % DAYS_PER_WEEK) + 1
	var wk: int = (day - 1) / DAYS_PER_WEEK
	if dow == 7 and tod >= PURGE_START_TOD - EPS:
		return &"PURGE_ACTIVE"
	if dow == 6 or dow == 7:
		return &"WARNING"
	if dow == 1 and wk >= 1 and tod < RESOLUTION_END_TOD - EPS:
		return &"RESOLUTION"
	return &"PEACE"

static func lawless(phase: StringName) -> bool:
	return phase == &"PURGE_ACTIVE"
