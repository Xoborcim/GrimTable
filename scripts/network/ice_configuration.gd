class_name IceConfiguration
extends RefCounted

static func url_valid(value: Variant) -> bool:
	if not value is String or value.length() > 512: return false
	var expression := RegEx.new()
	expression.compile("^(stun|turn|turns):([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\\[[0-9A-Fa-f:]+\\])(?::([0-9]{1,5}))?(?:\\?transport=(udp|tcp))?$")
	var found := expression.search(value)
	if found == null or found.get_string() != value: return false
	var hostname := found.get_string(2)
	if ".." in hostname: return false
	if hostname.begins_with("[") and not hostname.substr(1, hostname.length() - 2).is_valid_ip_address(): return false
	var port := found.get_string(3)
	if not port.is_empty() and (int(port) < 1 or int(port) > 65535): return false
	return found.get_string(1) != "stun" or found.get_string(4).is_empty()

static func token_valid(value: Variant) -> bool:
	if not value is String or value.length() != 43: return false
	for character in value:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

static func validate(servers: Variant) -> String:
	if not servers is Array or servers.size() > 16: return "Invalid ICE server list"
	for server in servers:
		if not server is Dictionary or not server.get("urls") is Array or server.urls.is_empty() or server.urls.size() > 8: return "Invalid ICE server URLs"
		var needs_credentials := false
		for url in server.urls:
			if not url_valid(url): return "Invalid ICE URL"
			if url.begins_with("turn:") or url.begins_with("turns:"): needs_credentials = true
		if needs_credentials:
			for key in ["username", "credential"]:
				if not server.get(key) is String or server[key].is_empty() or server[key].length() > 512: return "TURN requires temporary credentials"
	return ""

static func has_turn(servers: Array) -> bool:
	for server: Dictionary in servers:
		for url: String in server.urls:
			if url.begins_with("turn:") or url.begins_with("turns:"): return true
	return false

static func candidate_type(candidate: String) -> String:
	var words := candidate.strip_edges().split(" ", false)
	var index := words.find("typ")
	if index < 0 or index + 1 >= words.size(): return "unknown"
	var kind := words[index + 1]
	return kind if kind in ["host", "srflx", "prflx", "relay"] else "unknown"
