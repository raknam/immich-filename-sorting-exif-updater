#!/usr/bin/env sh

CRON_EXPRESSION="${CRON_EXPRESSION:-}"
RUN_IMMEDIATELY="${RUN_IMMEDIATELY:-false}"

# Run immediately if requested
if [ ! -z "$RUN_IMMEDIATELY" ] && { [ "$RUN_IMMEDIATELY" = "true" ] || [ "$RUN_IMMEDIATELY" = "1" ]; }; then
  /process.sh > /proc/1/fd/1 2>/proc/1/fd/2 || true
fi

if [ ! -z "$CRON_EXPRESSION" ]; then
  CRONTAB_PATH="/etc/crontabs/crontab"
  # Create and lock down crontab
  touch "$CRONTAB_PATH"
  chmod 0600 "$CRONTAB_PATH"
  # Populate crontab
  echo "$CRON_EXPRESSION /process.sh > /proc/1/fd/1 2>/proc/1/fd/2" > "$CRONTAB_PATH"
  /usr/local/bin/supercronic -passthrough-logs -no-reap -split-logs "$CRONTAB_PATH"
else
  echo "ERROR: CRON_EXPRESSION is required (e.g. '0 * * * *')" >&2
  exit 1
fi
