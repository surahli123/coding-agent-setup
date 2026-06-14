#!/usr/bin/env bash
# Hook: PreToolUse:Bash matcher for `docker build`
#
# Snapshots a Docker build context that lives under /tmp/ to a persistent
# location BEFORE the build runs, so a mid-build crash + reboot doesn't lose
# the build source.
#
# Rationale: macOS launchd com.apple.periodic-daily wipes /tmp/ on reboot.
# A build source living under /tmp/ was lost in a crash + reboot exactly this way,
# which is what motivated this hook.
#
# Action: extract the `-f <path>` arg from the docker build command;
# if `-f` points to /tmp/, cp -r the parent directory to
# `~/.local-build-backups/<basename>-<timestamp>/`.
#
# Best-effort: never blocks the command, never errors out loudly.
# Print to stderr so it shows in the agent's view.

set -u  # NOT -e — never block the user command on a backup failure

CMD="${CLAUDE_TOOL_INPUT_COMMAND:-${CLAUDE_BASH_COMMAND:-${1:-}}}"

# Bail if not a docker build with a -f pointing into /tmp/
if ! echo "$CMD" | grep -qE 'docker[[:space:]]+build.*-f[[:space:]]+/tmp/'; then
  exit 0
fi

# Extract the -f path
DOCKERFILE=$(echo "$CMD" | grep -oE -- '-f[[:space:]]+/tmp/[^[:space:]]+' \
  | sed -E 's/^-f[[:space:]]+//')
if [ -z "$DOCKERFILE" ]; then
  exit 0
fi

BUILD_DIR=$(dirname "$DOCKERFILE")
if [ ! -d "$BUILD_DIR" ]; then
  exit 0
fi

BACKUP_ROOT="$HOME/.local-build-backups"
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DEST="$BACKUP_ROOT/$(basename "$BUILD_DIR")-$TS"

mkdir -p "$BACKUP_ROOT" 2>/dev/null || exit 0
cp -R "$BUILD_DIR" "$BACKUP_DEST" 2>/dev/null && \
  echo "[hook pre-docker-build-backup] $BUILD_DIR → $BACKUP_DEST" >&2

exit 0
