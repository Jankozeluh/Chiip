class_name PlainText
extends RefCounted
## Plain, printable text from outside (M17, D-242): names and map titles that arrive in a LAN
## beacon ([LanDiscovery]), a player's hello ([NetSession]) or the settings file ([RecentHosts]).
## Nothing that comes from another computer may hide or spoof anything on screen, so control
## characters and the invisible ones that change how text reads (zero-width characters, the marks
## that reverse its direction) become spaces, and the result is trimmed and cut to a length.
## A plain class with static functions: no autoload, so tools and tests can use it.


## [param text] without control characters and the invisible ones that change how text reads
## (zero-width characters, the marks that reverse its direction): a name can't hide or spoof anything.
static func printable(text: String) -> String:
	var result := ""
	for character in text:
		var code := character.unicode_at(0)
		if code < 32 or code == 127 or (code >= 0x80 and code < 0xA0) or (code >= 0x200B and code <= 0x200F) \
				or (code >= 0x202A and code <= 0x202E) or (code >= 0x2060 and code <= 0x2069) or code == 0xFEFF:
			result += " "
		else:
			result += character
	return result


## [param text] made printable ([method printable]), trimmed, at most [param max_length] characters.
static func clean(text: String, max_length: int) -> String:
	return printable(text).strip_edges().left(max_length).strip_edges()
