#!/usr/bin/env bash
set -euo pipefail

check_port() {
  local port="$1"
  (echo > "/dev/tcp/127.0.0.1/${port}") >/dev/null 2>&1
}

# Check svnserve listening
if ! check_port 3690; then
  echo "svnserve not responding on 3690" >&2
  exit 1
fi

# Check sshd listening
if ! check_port 22; then
  echo "sshd not responding on 22" >&2
  exit 1
fi

exit 0


