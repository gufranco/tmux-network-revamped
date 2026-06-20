#!/usr/bin/env bash
#
# Unit test helpers for plugins built from tmux-plugin-template.
#
# Provides a mock tmux that keeps options in an in-memory associative array, so
# the cache layer can be tested end to end without a real tmux server. Time is
# mocked so cache ages are deterministic.

setup_test_environment() {
  TEST_TMPDIR=$(mktemp -d)
  export TEST_TMPDIR
  export TMUX_TEST_MODE=1

  # In-memory tmux option store. Reset per test for isolation.
  declare -gA _MOCK_TMUX_OPTS=()

  # Deterministic clock. Tests advance MOCK_EPOCH to simulate elapsed time.
  export MOCK_EPOCH=1000000

  # Reset source guards so each test re-sources fresh.
  unset _TMUX_PLUGIN_CONSTANTS_LOADED
  unset _TMUX_PLUGIN_HAS_COMMAND_LOADED
  unset _TMUX_PLUGIN_ERROR_LOGGER_LOADED
  unset _TMUX_PLUGIN_PLATFORM_LOADED
  unset _TMUX_PLUGIN_CACHE_LOADED
  unset _TMUX_PLUGIN_TMUX_OPS_LOADED
}

cleanup_test_environment() {
  if [[ -n "${TEST_TMPDIR:-}" && -d "${TEST_TMPDIR}" ]]; then
    rm -rf "${TEST_TMPDIR}"
  fi
}

# Mock tmux: only the option verbs the libraries use. set-option writes the
# in-memory store, show-option reads it. Everything else is a no-op success.
tmux() {
  local verb="$1"
  shift || true
  case "${verb}" in
    set-option)
      local unset_flag=0
      local args=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -gqu|-gu|-u) unset_flag=1 ;;
          -g|-q|-w|-p|-gq|-wq|-pq|-ga|-wqv|-gqv) ;;
          -t) shift ;;
          *) args+=("$1") ;;
        esac
        shift
      done
      local name="${args[0]:-}"
      [[ -z "${name}" ]] && return 0
      if (( unset_flag )); then
        unset '_MOCK_TMUX_OPTS[${name}]'
      else
        _MOCK_TMUX_OPTS["${name}"]="${args[1]:-}"
      fi
      return 0
      ;;
    show-option)
      local name=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          -gqv|-wqv|-pqv|-gq|-g|-q|-w|-p) ;;
          -t) shift ;;
          @*) name="$1" ;;
        esac
        shift
      done
      echo "${_MOCK_TMUX_OPTS[${name}]:-}"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}

# Mock date: +%s returns the controllable epoch; the log timestamp format
# returns a fixed string; everything else defers to the real date.
date() {
  case "$1" in
    +%s) echo "${MOCK_EPOCH:-1000000}" ;;
    '+%Y-%m-%d %H:%M:%S') echo "${MOCK_TIMESTAMP:-2026-01-15 14:30:00}" ;;
    *) command date "$@" ;;
  esac
}

function_exists() {
  declare -f "$1" >/dev/null
}

variable_exists() {
  [[ -n "${!1:-}" ]]
}

export -f tmux
export -f date
