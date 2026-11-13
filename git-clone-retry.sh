#!/bin/sh
# Usage: git-clone-retry.sh [git clone options...] <repository> <directory>
#
# Wrapper around `git clone` that retries on failure.
# Meant for remotes that are known to time out often from CI runners.
# The destination directory is wiped between attempts.
#
# Tunables: GIT_CLONE_RETRIES (default 5), GIT_CLONE_RETRY_DELAY (default 5s).
set -u

retries="${GIT_CLONE_RETRIES:-5}"
delay="${GIT_CLONE_RETRY_DELAY:-5}"

if [ "$#" -lt 2 ]; then
	echo "usage: $0 [git clone options...] <repository> <directory>" >&2
	exit 2
fi

# The destination is the last argument
for dest; do :; done

i=1
while [ "$i" -le "$retries" ]; do
	if git clone "$@"; then
		exit 0
	fi
	rm -rf "$dest"
	if [ "$i" -lt "$retries" ]; then
		echo "git clone failed, retrying ($i/$retries)..." >&2
		sleep "$delay"
	fi
	i=$((i + 1))
done

echo "git clone failed after $retries attempts" >&2
exit 1
