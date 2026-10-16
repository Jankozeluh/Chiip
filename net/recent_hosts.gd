class_name RecentHosts
extends RefCounted
## The hosts you joined lately (M17, D-242), for the Join page's "Recent" list: the way back to a
## friend over Tailscale, where the LAN browser ([LanDiscovery]) can't see them.
##
## The list is kept as one line of text in the settings ([member Settings.online_recent], the
## [code][online][/code] section's [code]recent[/code]): [code]address:port|name;address:port|name[/code],
## newest first, at most [constant MAX_ENTRIES], no duplicates (an address and port count once). It
## is a text setting because the settings file stores plain values and the list is small. A line
## from a hand-edited or damaged file is cleaned entry by entry ([method clean]): an entry that
## doesn't parse is dropped, a name is made plain and short, so nothing in the file can break the
## page. Every function here works on that text and returns new text, so the class needs no
## [Settings] (and tests never touch a real file). A plain class with static functions.

## The list's length: the oldest host falls off the end.
const MAX_ENTRIES := 8
## A remembered name is cut to this many characters ([constant NetSession.MAX_NAME_LENGTH]'s value;
## this class mustn't name NetSession, which would make Settings load the network code).
const MAX_NAME_LENGTH := 16
## An address (an IP or a host name) can be this long at most.
const MAX_ADDRESS_LENGTH := 64
## The text a [Settings] value may hold at most; more is dropped before anything is parsed.
const MAX_TEXT_LENGTH := 2048
## Between entries and between an entry's address:port and its name.
const ENTRY_SEPARATOR := ";"
const FIELD_SEPARATOR := "|"
## The lowest port a host can use ([Settings] keeps ports from here to 65535).
const MIN_PORT := 1024
const MAX_PORT := 65535


## The entries of [param text], newest first: each a Dictionary with [code]address[/code],
## [code]port[/code] and [code]name[/code] (empty when it wasn't known). Entries that don't parse
## are left out, so are repeats of an address and port; at most [constant MAX_ENTRIES].
static func parse(text: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for part in text.left(MAX_TEXT_LENGTH).split(ENTRY_SEPARATOR, false):
		var entry := _parse_entry(part)
		if entry.is_empty() or _find(list, entry["address"], entry["port"]) >= 0:
			continue
		list.append(entry)
		if list.size() >= MAX_ENTRIES:
			break
	return list


## The text that holds [param list] (see [method parse]); [method parse] gives the same list back.
static func format(list: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for entry in list:
		var part := "%s:%d" % [entry["address"], entry["port"]]
		if not String(entry["name"]).is_empty():
			part += FIELD_SEPARATOR + String(entry["name"])
		parts.append(part)
	return ENTRY_SEPARATOR.join(parts)


## [param text] cleaned entry by entry: what [Settings] keeps when something sets the list.
static func clean(text: String) -> String:
	return format(parse(text))


## [param text] with the host [param address]:[param port] at the front, called [param host_name]
## (an empty name keeps the one the list already knew). A host already in the list moves to the
## front instead of being listed twice; the list stays within [constant MAX_ENTRIES]. An address
## or port that can't be one leaves the text as it was.
static func remember(text: String, address: String, port: int, host_name: String = "") -> String:
	var entry := _make_entry(address, port, host_name)
	var list := parse(text)
	if entry.is_empty():
		return format(list)
	var known := _find(list, entry["address"], entry["port"])
	if known >= 0:
		if String(entry["name"]).is_empty():
			entry["name"] = list[known]["name"]
		list.remove_at(known)
	list.push_front(entry)
	list.resize(mini(list.size(), MAX_ENTRIES))
	return format(list)


## [param text] without the host [param address]:[param port] (unchanged when it wasn't in it).
static func forget(text: String, address: String, port: int) -> String:
	var list := parse(text)
	var known := _find(list, address.strip_edges(), port)
	if known >= 0:
		list.remove_at(known)
	return format(list)


## True if [param address] could be the address of a host: an IP (v4 or v6) or a host name, plain
## characters only, no spaces.
static func is_valid_address(address: String) -> bool:
	if address.is_empty() or address.length() > MAX_ADDRESS_LENGTH:
		return false
	for character in address:
		var code := character.unicode_at(0)
		var allowed := (code >= 48 and code <= 58) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
				or character == "." or character == "-" or character == "_"
		if not allowed:
			return false
	return true


## One "address:port|name" part of the text as an entry, or an empty Dictionary.
static func _parse_entry(part: String) -> Dictionary:
	var fields := part.split(FIELD_SEPARATOR, true, 1)
	var target := fields[0].strip_edges()
	# The port follows the last colon (an IPv6 address has more of them).
	var colon := target.rfind(":")
	if colon <= 0:
		return {}
	var digits := target.substr(colon + 1)
	if digits.is_empty() or not digits.is_valid_int() or digits.length() > 5:
		return {}
	return _make_entry(target.left(colon), int(digits), fields[1] if fields.size() > 1 else "")


## An entry for [param address] and [param port], or an empty Dictionary when either is wrong.
static func _make_entry(address: String, port: int, host_name: String) -> Dictionary:
	var clean_address := address.strip_edges()
	if not is_valid_address(clean_address) or port < MIN_PORT or port > MAX_PORT:
		return {}
	var plain := PlainText.clean(host_name.replace(ENTRY_SEPARATOR, " ").replace(FIELD_SEPARATOR, " "), MAX_NAME_LENGTH)
	return {"address": clean_address, "port": port, "name": plain}


## The index of the entry for [param address]:[param port] in [param list], or -1. A host name's
## letters may be written in either case.
static func _find(list: Array[Dictionary], address: String, port: int) -> int:
	for i in list.size():
		if list[i]["port"] == port and String(list[i]["address"]).nocasecmp_to(address) == 0:
			return i
	return -1
