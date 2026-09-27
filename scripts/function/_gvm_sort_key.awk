# Canonical Go version sort key. Shared by gvm_version_sort_key (single value)
# and gvm_versions_sorted (bulk), so the two can never disagree.
#
# Key layout: MAJOR.MINOR.PATCH.STAGE.RANK.NUM   (zero padded, fixed width)
#   STAGE  0 for a pre-release (alpha/beta/rc), 1 for a final release
#   RANK   alpha=00, beta=01, rc=02, final=99
#   NUM    pre-release number, 0 for final releases
#
# `sort -V` is deliberately not used: it orders go1.2.2 before go1.2.2rc1 and
# go1.4 before go1.4rc1, inverting pre-release ordering.
#
# Only POSIX awk features are used here. match(str, re, array) would be far
# tidier but is a GNU awk extension and is unavailable on macOS/BSD awk.
# Extra function parameters are the awk idiom for locals.

function pad(n, width,   s) {
	s = n ""
	while (length(s) < width) s = "0" s
	return s
}

# Split a Go version into its numeric part and its pre-release tail, stashing
# the pieces in P_MAJOR/P_MINOR/P_PATCH/P_PRE/P_PRENUM. Returns 1 if the
# string is not a Go version.
function split_version(version,   i, c, n, numeric, rest, parts) {
	# The "release.rN" naming predates goN and has no index entry.
	if (version ~ /^release\./) return 1

	sub(/^go/, "", version)

	# Everything up to the first non [0-9.] character is the numeric part.
	numeric = ""
	n = length(version)
	for (i = 1; i <= n; i++) {
		c = substr(version, i, 1)
		if (c ~ /[0-9.]/) numeric = numeric c
		else break
	}
	rest = substr(version, i)
	sub(/\.+$/, "", numeric)
	if (numeric == "" || numeric !~ /^[0-9]+(\.[0-9]+)*$/) return 1

	split(numeric, parts, ".")
	P_MAJOR = parts[1] + 0
	P_MINOR = (parts[2] == "" ? 0 : parts[2] + 0)
	P_PATCH = (parts[3] == "" ? 0 : parts[3] + 0)

	P_PRE = ""
	P_PRENUM = 0
	if (rest != "") {
		# POSIX awk has no capture array; peel the keyword off by hand.
		if (rest !~ /^(alpha|beta|rc)[0-9]*$/) return 1
		if (substr(rest, 1, 5) == "alpha") P_PRE = "alpha"
		else if (substr(rest, 1, 4) == "beta") P_PRE = "beta"
		else if (substr(rest, 1, 2) == "rc") P_PRE = "rc"
		else return 1
		P_PRENUM = substr(rest, length(P_PRE) + 1) + 0
	}

	return 0
}

function sort_key(version,   stage, rank) {
	if (split_version(version) != 0) return ""

	stage = 1
	rank = 99
	if (P_PRE != "") {
		stage = 0
		if (P_PRE == "alpha") rank = 0
		else if (P_PRE == "beta") rank = 1
		else if (P_PRE == "rc") rank = 2
		else return ""
	}

	return pad(P_MAJOR, 3) "." pad(P_MINOR, 3) "." pad(P_PATCH, 3) "." stage "." pad(rank, 2) "." pad(P_PRENUM, 3)
}

BEGIN { FS = "\t" }
{
	# Accept either a bare version or a key<TAB>version line.
	if (NF >= 2 && $1 ~ /^[0-9][0-9][0-9]\./) {
		print $0
		next
	}
	version = $NF
	if (version == "") next
	key = sort_key(version)
	if (key == "") next
	print key "\t" version
}
