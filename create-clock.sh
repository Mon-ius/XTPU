#!/usr/bin/env bash
#
# create-clock.sh — recurring macOS reminders via the Notification Center.
#
# Built for the classic "office hygiene" nudges — leave work, look up (rest your
# eyes), drink water, stand up — but it is fully data-driven: every reminder is
# described by a small JSON object and you can supply your own set.
#
# JSON schema (one object, or an array of them):
#
#   {
#     "name":     "Stand",                       # short label, shown as the title
#     "emoji":    "🧍",                          # decorates the title (optional)
#     "action":   "Stand up and stretch a bit.", # the notification body
#     "interval": "50m",                         # repeat every: 30s / 45m / 1h / 8h / 1d
#     "sound":    "Glass"                         # optional; "none" to silence
#   }
#
# Usage:
#   ./create-clock.sh start '<json>'        # start from an inline JSON string
#   ./create-clock.sh start config.json     # start from a JSON file
#   ./create-clock.sh start -               # read JSON config from stdin
#   ./create-clock.sh start                 # no config -> built-in defaults
#   ./create-clock.sh list  '<json>'        # show parsed reminders, don't start
#   ./create-clock.sh status                # show which reminders are running
#   ./create-clock.sh stop                  # stop all running reminders
#   ./create-clock.sh test                  # fire one test notification now
#   ./create-clock.sh help                  # this help
#
# The config argument accepts an inline JSON string (one object or an array),
# a file path, or '-' for stdin. Example:
#   ./create-clock.sh start '{"name":"Tea","emoji":"🍵","action":"Brew tea","interval":"90m"}'
#
# Dependencies: none beyond a stock macOS (uses osascript + JavaScriptCore for
# JSON parsing, so jq is NOT required). Targets bash 3.2 (the system bash).
#
# Note: notifications are delivered by "Script Editor"/osascript. The first run
# may ask you to allow notifications; also make sure a Focus / Do Not Disturb
# mode is not suppressing them. Background reminders survive closing the
# terminal (nohup), but not logout/reboot — re-run `start` after you log back in.

# --------------------------------------------------------------------------- #
# Configuration / paths
# --------------------------------------------------------------------------- #

STATE_DIR="${CREATE_CLOCK_HOME:-$HOME/.create-clock}"
PID_FILE="$STATE_DIR/clock.pids"
LOG_FILE="$STATE_DIR/clock.log"

# Absolute path to this script, so background workers can re-invoke it.
SELF="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)/$(basename "$0")"

# Built-in reminders used when no config is supplied.
DEFAULT_JSON=$(cat <<'JSON'
[
  { "name": "Leave Work", "emoji": "🏃", "action": "Time to wrap up and leave work. Log off and go home.", "interval": "8h",  "sound": "Hero"   },
  { "name": "Look Up",    "emoji": "👀", "action": "Look away from the screen: focus on something ~20 feet away for 20 seconds (20-20-20).", "interval": "20m", "sound": "Glass" },
  { "name": "Drink",      "emoji": "💧", "action": "Time to drink some water — stay hydrated.", "interval": "45m", "sound": "Glass" },
  { "name": "Stand",      "emoji": "🧍", "action": "Stand up, stretch, and move around for a minute.", "interval": "50m", "sound": "Glass" }
]
JSON
)

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

err()  { printf '%s\n' "$*" >&2; }
note() { printf '%s\n' "$*"; }

# to_seconds <value> -> echoes seconds, or returns 1 if unparseable.
# Accepts a bare number (seconds) or a number with a unit suffix s/m/h/d.
to_seconds() {
  local v="$1" n unit
  if [[ "$v" =~ ^([0-9]+)[[:space:]]*([smhdSMHD]?)$ ]]; then
    n="${BASH_REMATCH[1]}"
    unit="$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')"
    # 10# forces base-10 so zero-padded values (e.g. "08m", "09s") are not
    # misread as octal — bash would otherwise abort on the digits 8/9.
    case "$unit" in
      ""|s) printf '%s' "$(( 10#$n ))" ;;
      m)    printf '%s' "$(( 10#$n * 60 ))" ;;
      h)    printf '%s' "$(( 10#$n * 3600 ))" ;;
      d)    printf '%s' "$(( 10#$n * 86400 ))" ;;
    esac
    return 0
  fi
  return 1
}

# human <seconds> -> compact human-readable duration, e.g. "1h30m", "45m", "20s".
human() {
  local s=$(( 10#${1:-0} )) out="" d h m
  d=$(( s / 86400 )); s=$(( s % 86400 ))
  h=$(( s / 3600 ));  s=$(( s % 3600 ))
  m=$(( s / 60 ));    s=$(( s % 60 ))
  [ "$d" -gt 0 ] && out="${out}${d}d"
  [ "$h" -gt 0 ] && out="${out}${h}h"
  [ "$m" -gt 0 ] && out="${out}${m}m"
  [ "$s" -gt 0 ] && out="${out}${s}s"
  [ -z "$out" ] && out="0s"
  printf '%s' "$out"
}

# notify <title> <message> [sound]
# Strings are passed as AppleScript arguments (argv), so no escaping/quoting of
# the content is needed and it is injection-safe.
notify() {
  local title="$1" message="$2" sound="${3:-}"
  osascript \
    -e 'on run {t, m, s}' \
    -e 'if s is "" then' \
    -e '  display notification m with title t' \
    -e 'else' \
    -e '  display notification m with title t sound name s' \
    -e 'end if' \
    -e 'end run' \
    -- "$title" "$message" "$sound" >/dev/null 2>&1
}

# parse_json_tsv <json-string>
# Emits one line per reminder, fields joined by US (0x1f, the unit separator):
#   name<US>emoji<US>action<US>interval<US>sound
# A non-whitespace separator is used on purpose: TAB is IFS-whitespace, so bash
# `read` would collapse consecutive TABs and silently shift columns whenever an
# optional field (emoji/sound) is empty. Field values are also stripped of any
# TAB / CR / LF so they can never break the line-oriented record format.
# Parsing is done by JavaScriptCore (always present on macOS) — handles unicode,
# nested quotes, single object or array. Returns non-zero on invalid JSON.
parse_json_tsv() {
  osascript -l JavaScript \
    -e 'function run(argv){' \
    -e '  var data = JSON.parse(argv[0]);' \
    -e '  if (!Array.isArray(data)) data = [data];' \
    -e '  return data.map(function(r){' \
    -e '    r = r || {};' \
    -e '    function g(k){ var v = (r[k] === undefined || r[k] === null) ? "" : String(r[k]); return v.replace(/[\t\r\n\x1f]+/g, " "); }' \
    -e '    return [g("name"), g("emoji"), g("action"), g("interval"), g("sound")].join("\x1f");' \
    -e '  }).join("\n");' \
    -e '}' \
    -- "$1"
}

# load_config <arg> -> echoes the JSON text to use.
#   inline JSON string       -> used verbatim   (arg starts with '{' or '[')
#   existing file path        -> file contents
#   "-", or piped non-empty   -> stdin
#   nothing, tty, or empty    -> built-in defaults
# The argument is treated as a literal JSON string first, so you can pass the
# config inline:  ./create-clock.sh start '{"name":"Tea",...}'
# Reading stdin only when it carries data means non-interactive callers (cron,
# launchd, a here-doc-less pipe) fall back to the defaults instead of hanging
# on / parsing an empty stream.
load_config() {
  local arg="${1:-}" data trimmed
  # Inline JSON? (first non-whitespace char is '{' or '[')
  trimmed="${arg#"${arg%%[![:space:]]*}"}"
  case "$trimmed" in
    '{'*|'['*)
      printf '%s' "$arg"
      return 0
      ;;
  esac
  if [ -n "$arg" ] && [ "$arg" != "-" ]; then
    if [ ! -f "$arg" ]; then
      err "Not an inline JSON string and not a file: $arg"
      return 1
    fi
    cat "$arg"
    return 0
  fi
  if [ "$arg" = "-" ] || [ ! -t 0 ]; then
    data="$(cat)"
    if [ -n "$(printf '%s' "$data" | tr -d '[:space:]')" ]; then
      printf '%s' "$data"
      return 0
    fi
  fi
  printf '%s' "$DEFAULT_JSON"
}

# Read config -> validated TSV into the global REMINDERS_TSV. Returns non-zero
# on failure (missing file, bad JSON). Skips entries with no name/action.
REMINDERS_TSV=""
read_reminders() {
  local json tsv
  json="$(load_config "${1:-}")" || return 1
  tsv="$(parse_json_tsv "$json" 2>/dev/null)" || {
    err "Could not parse JSON config (check that it is valid JSON)."
    return 1
  }
  REMINDERS_TSV="$tsv"
  if [ -z "$REMINDERS_TSV" ]; then
    err "No reminders found in the config."
    return 1
  fi
  return 0
}

# normalize_sound <sound> -> "" for empty/none/off/silent, else the value.
normalize_sound() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$s" in
    ""|none|off|silent|mute) printf '' ;;
    *) printf '%s' "$1" ;;
  esac
}

# --------------------------------------------------------------------------- #
# Commands
# --------------------------------------------------------------------------- #

cmd_list() {
  read_reminders "${1:-}" || return 1
  printf '%-14s %-6s %-10s %s\n' "NAME" "EVERY" "SOUND" "ACTION"
  local name emoji action interval sound secs every
  while IFS=$'\x1f' read -r name emoji action interval sound; do
    [ -z "$name$action" ] && continue
    if secs="$(to_seconds "$interval")"; then every="$(human "$secs")"; else every="?($interval)"; fi
    printf '%-14s %-6s %-10s %s\n' "$emoji $name" "$every" "${sound:-—}" "$action"
  done <<< "$REMINDERS_TSV"
}

cmd_start() {
  read_reminders "${1:-}" || return 1

  # Clean restart: always sweep first (this also reaps any untracked workers
  # from an earlier run), so we can never end up with duplicate live sets.
  if has_running; then
    note "Reminders already running — restarting."
  fi
  cmd_stop >/dev/null 2>&1

  mkdir -p "$STATE_DIR" || { err "Cannot create state dir: $STATE_DIR"; return 1; }
  : > "$PID_FILE"

  local name emoji action interval sound secs title count=0
  while IFS=$'\x1f' read -r name emoji action interval sound; do
    [ -z "$name$action" ] && continue
    if ! secs="$(to_seconds "$interval")"; then
      err "Skipping '$name': bad interval '$interval' (use e.g. 30s, 45m, 1h, 8h, 1d)."
      continue
    fi
    if [ "$secs" -le 0 ]; then
      err "Skipping '$name': interval must be greater than zero."
      continue
    fi
    sound="$(normalize_sound "$sound")"
    title="$emoji $name"
    # Trim a leading space if there is no emoji.
    title="${title# }"

    nohup "$SELF" __loop "$secs" "$title" "$action" "$sound" \
      </dev/null >>"$LOG_FILE" 2>&1 &
    local pid=$!
    # No-arg disown targets the job just backgrounded; nohup already shields it
    # from SIGHUP, so this is only belt-and-suspenders (and avoids the bash 3.2
    # quirk where `disown <pid>` rejects a raw PID).
    disown 2>/dev/null || true
    printf '%s\t%s\t%s\n' "$pid" "$name" "$(human "$secs")" >> "$PID_FILE"
    count=$(( count + 1 ))
    note "started  $title  (every $(human "$secs"), pid $pid)"
  done <<< "$REMINDERS_TSV"

  if [ "$count" -eq 0 ]; then
    err "No valid reminders to start."
    rm -f "$PID_FILE"
    return 1
  fi

  notify "⏰ Clock started" "$count reminder(s) are now active." "Glass"
  note ""
  note "$count reminder(s) running. Stop them with:  $0 stop"
}

# is_our_worker <pid> -> 0 only if <pid> is alive AND its command line is one of
# our __loop workers. PIDs are recycled (especially across reboots, and the PID
# file is not cleared on reboot), so a bare `kill`/`kill -0` on a recorded PID
# could hit — or terminate — an unrelated process. Verifying the command line
# before signalling makes stop/status safe.
is_our_worker() {
  local pid="$1" cmd
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  cmd="$(ps -o command= -p "$pid" 2>/dev/null)"
  case "$cmd" in
    *"$SELF"*__loop*) return 0 ;;
    *) return 1 ;;
  esac
}

cmd_stop() {
  local pid name every stopped=0 opid
  if [ -f "$PID_FILE" ]; then
    while IFS=$'\t' read -r pid name every; do
      if is_our_worker "$pid"; then
        kill "$pid" 2>/dev/null || true   # trap in the worker reaps its child sleep
        stopped=$(( stopped + 1 ))
        note "stopped  $name (pid $pid)"
      fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
  fi
  # Safety net: catch any of our workers that escaped the PID file (e.g. a
  # previous run whose state file was lost), so a restart can never leak workers.
  for opid in $(pgrep -f "$SELF __loop" 2>/dev/null); do
    if is_our_worker "$opid"; then
      kill "$opid" 2>/dev/null || true
      stopped=$(( stopped + 1 ))
      note "stopped  (untracked pid $opid)"
    fi
  done
  if [ "$stopped" -eq 0 ]; then
    note "No reminders are running."
  else
    note "Stopped $stopped reminder(s)."
  fi
}

cmd_status() {
  if [ ! -f "$PID_FILE" ]; then
    note "No reminders are running."
    return 0
  fi
  local pid name every alive=0
  printf '%-8s %-14s %-8s %s\n' "PID" "NAME" "EVERY" "STATE"
  while IFS=$'\t' read -r pid name every; do
    [ -z "$pid" ] && continue
    if is_our_worker "$pid"; then
      printf '%-8s %-14s %-8s %s\n' "$pid" "$name" "$every" "running"
      alive=$(( alive + 1 ))
    else
      printf '%-8s %-14s %-8s %s\n' "$pid" "$name" "$every" "stale"
    fi
  done < "$PID_FILE"
  note ""
  note "$alive reminder(s) running.  Log: $LOG_FILE"
}

# has_running -> 0 if at least one tracked pid is genuinely one of our workers.
has_running() {
  [ -f "$PID_FILE" ] || return 1
  local pid rest
  while IFS=$'\t' read -r pid rest; do
    is_our_worker "$pid" && return 0
  done < "$PID_FILE"
  return 1
}

cmd_test() {
  note "Sending a test notification…"
  if notify "⏰ create-clock" "If you can see this, notifications are working. 🎉" "Glass"; then
    note "Sent. If nothing appeared, allow notifications for Script Editor in"
    note "System Settings ▸ Notifications, and check Do Not Disturb / Focus."
  else
    err "osascript failed to send the notification."
    return 1
  fi
}

# Internal worker: loop forever, notifying every <secs>. Not for direct use.
# The sleep runs in the BACKGROUND and we `wait` on it so an incoming SIGTERM is
# handled promptly: a trap is deferred while bash blocks in a *foreground* child
# (the worker would otherwise keep sleeping — up to hours — after `stop`), but it
# interrupts `wait` immediately. The trap kills the child sleep (no orphan) and
# `wait ... || break` means an interrupted sleep does NOT fire a stray
# notification on the way out.
cmd_loop() {
  local secs="$1" title="$2" message="$3" sound="$4" child=""
  trap 'kill "$child" 2>/dev/null; exit 0' TERM INT
  while true; do
    sleep "$secs" & child=$!
    wait "$child" || break
    notify "$title" "$message" "$sound"
  done
}

cmd_help() {
  sed -n '2,/^$/p' "$SELF" 2>/dev/null | sed 's/^# \{0,1\}//' | sed '/^#/d'
  cat <<'USAGE'
Commands:
  start [<json>|file|-]   Start reminders in the background. The argument may be
                          an inline JSON string, a file path, '-' for stdin, or
                          nothing for the built-in defaults.
  list  [<json>|file|-]   Show the parsed reminders without starting them.
  status                  Show which reminders are currently running.
  stop                    Stop all running reminders.
  test                    Fire a single test notification right now.
  help                    Show this help.

Examples:
  ./create-clock.sh start                       # leave-work / look-up / drink / stand
  ./create-clock.sh start '{"name":"Tea","emoji":"🍵","action":"Brew tea","interval":"90m"}'
  ./create-clock.sh start '[{"name":"Stand","emoji":"🧍","action":"Stand up","interval":"50m"}]'
  ./create-clock.sh start my-reminders.json
  echo '{"name":"Tea","action":"Brew tea","interval":"90m"}' | ./create-clock.sh start -
USAGE
}

# --------------------------------------------------------------------------- #
# Dispatch
# --------------------------------------------------------------------------- #

main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true
  case "$cmd" in
    start)        cmd_start "${1:-}" ;;
    list|ls)      cmd_list "${1:-}" ;;
    status|st)    cmd_status ;;
    stop)         cmd_stop ;;
    test)         cmd_test ;;
    __loop)       cmd_loop "$@" ;;
    help|-h|--help|"") cmd_help ;;
    *)            err "Unknown command: $cmd"; err "Run '$0 help' for usage."; return 2 ;;
  esac
}

main "$@"
