#!/usr/bin/env bash

CONF_FILE="/etc/supervisord.conf"

cat >"${CONF_FILE}" << _EOF
[supervisord]
nodaemon = true
pidfile = /supervisord.pid
user = root

[program:app]
command=/app/.venv/bin/python3 /app/app.py $*
autostart=true
autorestart=true

[eventlistener:manage_tts_cache]
command=/usr/bin/env bash /manage_tts_cache.sh
autostart=true
autorestart=true
events=TICK_3600
_EOF

/bin/supervisord -c "${CONF_FILE}" &
WAIT_PIDS=($!)

function stop_container() {
   kill -TERM "${WAIT_PIDS[@]}"
   wait "${WAIT_PIDS[@]}"
}

trap "stop_container" SIGTERM SIGHUP

wait "${WAIT_PIDS[@]}"
