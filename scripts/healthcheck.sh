#!/usr/bin/env bash
set -euo pipefail

is_listening() {
  local port="$1"
  ss -ltn | awk '{print $4}' | grep -qE ":${port}$"
}

# Check svnserve listening
if ! is_listening 3690; then
  echo "svnserve not listening on 3690" >&2
  exit 1
fi

# Check sshd listening
if ! is_listening 22; then
  echo "sshd not listening on 22" >&2
  exit 1
fi

exit 0
