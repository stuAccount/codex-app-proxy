#!/bin/zsh

set -euo pipefail

PID_FILE="$HOME/.codex-app-proxy.pid"

if [[ ! -f "$PID_FILE" ]]; then
  exit 0
fi

PID="$(cat "$PID_FILE")"

if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
  kill "$PID" 2>/dev/null || true

  for _ in {1..50}; do
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done
fi

rm -f "$PID_FILE"
