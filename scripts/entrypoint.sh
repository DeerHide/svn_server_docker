#!/usr/bin/env bash

set -euo pipefail

# Ensure runtime dirs
mkdir -p /run/sshd /var/log/svn
chmod 755 /run/sshd /var/log/svn || true

# Ensure the svn account is unlocked (some base images/system users are locked by default)
if passwd -S svn 2>/dev/null | grep -q " L "; then
  usermod -U svn || true
  passwd -u svn || true
fi

# Ensure home and ssh dir perms
HOME_DIR=${HOME_DIR:-/home/svn}
if [ -d "$HOME_DIR" ]; then
  chown -R svn:svn "$HOME_DIR" || true
  chmod 755 "$HOME_DIR" || true
  mkdir -p "$HOME_DIR/.ssh"
  chown -R svn:svn "$HOME_DIR/.ssh"
  chmod 700 "$HOME_DIR/.ssh"
  if [ -f "$HOME_DIR/.ssh/authorized_keys" ]; then
    chown svn:svn "$HOME_DIR/.ssh/authorized_keys"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
  fi
fi

# Populate authorized_keys from environment variables if provided
sanitize_keys() {
  # Remove CRs, trim whitespace
  sed -e 's/\r$//' -e 's/^\s\+//' -e 's/\s\+$//' | sed '/^$/d'
}

AUTH_KEYS_FILE="$HOME_DIR/.ssh/authorized_keys"
# Always overwrite with env-provided keys only
if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
  # Support comma-separated, newline-separated, and literal \n-separated without corrupting characters
  printf "%s" "$SSH_AUTHORIZED_KEYS" \
    | sed 's/\\\n/\n/g' \
    | tr ',' '\n' \
    | sanitize_keys > "$AUTH_KEYS_FILE"
else
  # Create empty file if no keys provided so sshd can start; warn for visibility
  : > "$AUTH_KEYS_FILE"
  echo "[entrypoint] Warning: SSH_AUTHORIZED_KEYS is empty; no SSH logins will be allowed." >&2
fi
chmod 600 "$AUTH_KEYS_FILE" && chown svn:svn "$AUTH_KEYS_FILE"

# Start sshd (key-only per config)
/usr/sbin/sshd -D -e &

# Start svnserve in foreground via tini
exec /usr/bin/svnserve --foreground -r "$HOME_DIR" --listen-port 3690 --log-file=/var/log/svn/svnserve.log
