class_name NetCodec
extends RefCounted
## Wire format: one Variant per ENet packet via var_to_bytes (no Object decoding => no code injection).
const MAX_PACKET := 16384          # client->server
const MAX_CMD_KEYS := 32
const MAX_DEPTH := 4
const CHANNEL := 0

static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)

## Returns {} on anything that is not a plain Dictionary message with a String "t".
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() == 0:
		return {}
	var v: Variant = bytes_to_var(bytes)
	if not (v is Dictionary) or not ((v as Dictionary).get("t") is String):
		return {}
	return v

## Plain-data check: bool/int/float/String/StringName/Vector2/Vector2i/Array/Dictionary, bounded depth/size.
static func plain(v: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I:
			return true
		TYPE_FLOAT:
			return not is_nan(v) and not is_inf(v)
		TYPE_ARRAY:
			if (v as Array).size() > 256:
				return false
			for x in v:
				if not plain(x, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if (v as Dictionary).size() > MAX_CMD_KEYS:
				return false
			for k in v:
				if not (k is String or k is StringName or k is int) or not plain(v[k], depth + 1):
					return false
			return true
	return false
