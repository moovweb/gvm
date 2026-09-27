# Parse the go.dev download index (?mode=json&include=all) into a flat,
# grep/awk-friendly TSV. Avoids requiring jq on the user's machine.
#
# Input : the JSON index on stdin
# Output: two record shapes, tab separated
#   V<TAB>version<TAB>stable|unstable
#   F<TAB>version<TAB>filename<TAB>os<TAB>arch<TAB>kind<TAB>size<TAB>sha256
#
# This scanner follows brace depth rather than column positions, so it accepts
# the pretty-printed feed, a compact feed, and hand-written fixtures. An earlier
# version keyed off "how many spaces is this line indented", which silently
# produced an empty index from anything shaped differently from the copy it was
# written against.
#
# Depth is counted in braces only; [ and ] do not count, so a release object is
# at depth 1 and each of its file objects at depth 2.

function trim(s) {
	sub(/^[ \t]+/, "", s)
	sub(/[ \t]+$/, "", s)
	return s
}

# value: a quoted string, a number, or a bare true/false
function unquote(v) {
	sub(/, *$/, "", v)
	sub(/ *$/, "", v)
	gsub(/^"/, "", v)
	gsub(/"$/, "", v)
	return v
}

function handle(key, value,   d) {
	d = depth
	if (f) {
		if (key == "filename") filename = value
		else if (key == "os") os = value
		else if (key == "arch") arch = value
		else if (key == "kind") kind = value
		else if (key == "sha256") sha = value
		else if (key == "size") size = value
		return
	}
	if (d == 1) {
		if (key == "version") {
			close_release()
			rel = value
			relstable = "unstable"
			seen_files = 0
		} else if (key == "stable") {
			relstable = (value ~ /true/) ? "stable" : "unstable"
		} else if (key == "files") {
			seen_files = 1
		}
	}
}

# A file object closed: emit its record.
function close_file() {
	if (rel == "") index_strict("file record before any release version")
	if (kind != "archive" && kind != "source") {
		f = 0
		return
	}
	if (filename == "") index_strict("file record without a filename in " rel)
	print "F", rel, filename, os, arch, kind, (size == "" ? 0 : size), sha
	f = 0
}

# A release object closed: emit its record.
function close_release() {
	if (rel == "") return
	if (!seen_files) index_strict("release " rel " has no files array")
	print "V", rel, relstable
	rel = ""
}

BEGIN {
	FS = ""
	OFS = "\t"
	depth = 0
	rel = ""
	relstable = ""
	f = 0
	filename = os = arch = kind = sha = size = ""
	seen_files = 0
}

{
	line = $0
	while (length(line)) {
		# Leading whitespace and separators carry no structure.
		if (line ~ /^[ \t]/) {
			line = substr(line, 2)
			continue
		}
		if (line ~ /^[{},]/) {
			ch = substr(line, 1, 1)
			line = substr(line, 2)
			if (ch == "{") {
				depth++
				if (depth == 2 && rel != "") {
					# A file object opens inside the current release.
					f = 1
					filename = os = arch = kind = sha = size = ""
				}
			} else if (ch == "}") {
				if (depth == 2 && f) close_file()
				if (depth == 1) close_release()
				depth--
				if (depth < 0) depth = 0
			}
			continue
		}
		if (line ~ /^"/) {
			# "key": value
			rest = substr(line, 2)
			q = index(rest, "\"")
			if (q == 0) {
				line = ""
				continue
			}
			key = substr(rest, 1, q - 1)
			rest = substr(rest, q + 1)
			sub(/^ *: */, "", rest)
			if (substr(rest, 1, 1) == "\"") {
				r2 = substr(rest, 2)
				q2 = index(r2, "\"")
				if (q2 == 0) {
					line = ""
					continue
				}
				value = substr(r2, 1, q2 - 1)
				line = substr(r2, q2 + 1)
			} else {
				# number, true, false, or [] ; up to the next comma
				comma = index(rest, ",")
				if (comma == 0) comma = index(rest, "}")
				if (comma == 0) comma = length(rest) + 1
				value = substr(rest, 1, comma - 1)
				line = substr(rest, comma)
			}
			handle(key, unquote(value))
			continue
		}
		# Anything else (a bare number, a stray token) cannot start a member.
		line = substr(line, 2)
	}
}

END {
	close_release()
	if (f) index_strict("unterminated file record in " rel)
}

function index_strict(message) {
	print "gvm: malformed go.dev index: " message > "/dev/stderr"
	exit 1
}
