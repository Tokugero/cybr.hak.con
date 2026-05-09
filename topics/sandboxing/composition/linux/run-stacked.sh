#!/usr/bin/env bash
# run-stacked.sh — Drop-in stacked sandbox harness.
#
# A defensible default for "I want to run an agent (or a shell) against
# code I don't fully trust, with sensible composition turned on." Read
# the source; copy and adapt for your own workflow. The composition
# workshop's lesson is recognizing when each layer matters; this script
# makes one good default easy to start from.
#
# Usage:
#   run-stacked.sh [--tier bwrap|docker] [--target DIR] [-- command ...]
#
# Examples:
#   run-stacked.sh
#       Tier 0 (host shell) + Tier 2 (hardened docker) on the current
#       directory. Drops you into an interactive bash inside.
#   run-stacked.sh --tier bwrap
#       Tier 0 + Tier 1 (hardened bwrap), Linux-only, faster spin-up.
#   run-stacked.sh --target ~/repos/sketchy
#       Same defaults, but mount the sketchy repo at /work instead of cwd.
#   run-stacked.sh --tier bwrap -- ls -la /work
#       Run a single command instead of an interactive shell.
#
# What this composes:
# - Tier 0: warns loudly if the host shell still has prod-shaped creds
#   in the environment. It does not scrub for you — that is the host
#   shell's job (cred-scrub + direnv-perimeter).
# - Tier 1 (bwrap) or Tier 2 (docker): both fail-closed on network
#   (--unshare-net / --network=none) and read-only on host filesystem
#   outside $TARGET. $TARGET is mounted read-only at /work; HOME is a
#   tmpfs so a misbehaving process has nowhere durable to write.
#
# What this deliberately does NOT do:
# - It does not bring up the network-egress sidecar. If you need
#   outbound network, run compose-docker-egress.sh and adapt from there.
# - It does not mount your real $HOME. If you need a credential, fetch
#   it into a variable and pass via -e (docker) or --setenv (bwrap).
# - It does not write to the target directory. Read-only by design;
#   change to :rw and --bind if you want the agent to write back, but
#   understand what you're trading away.

set -euo pipefail

TIER="docker"
TARGET="$(pwd)"
CMD=()

usage() {
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --target)
      if [ ! -d "$2" ]; then
        echo "ERROR: target directory not found: $2" >&2
        exit 2
      fi
      TARGET="$(cd "$2" && pwd)"
      shift 2
      ;;
    --)
      shift
      CMD=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 2
      ;;
  esac
done

if [ ${#CMD[@]} -eq 0 ]; then
  CMD=(bash -i)
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target directory not found: $TARGET" >&2
  exit 2
fi

# ── Tier 0 sanity check ──
# Spot-check a few prod-shaped env vars. Not exhaustive — the cred-scrub
# probe is the comprehensive check. This just yells if something obvious
# is still in scope so the participant notices before exec'ing into a
# sandbox that "feels safe."
echo "=========================================================="
echo "Composition harness — tier=$TIER, target=$TARGET"
echo "=========================================================="
echo
LEAKED=0
for v in AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY \
         GITHUB_TOKEN GH_TOKEN \
         OPENAI_API_KEY ANTHROPIC_API_KEY \
         KUBECONFIG; do
  if [ -n "${!v:-}" ]; then
    if [ "$LEAKED" -eq 0 ]; then
      echo "Tier 0: host shell appears UNSCRUBBED. The following are set:"
    fi
    LEAKED=1
    echo "  - $v"
  fi
done
if [ "$LEAKED" -eq 1 ]; then
  echo
  echo "  These will be inherited by the sandbox unless you also clear them"
  echo "  there. For the strongest composition, launch this script from a"
  echo "  shell that has cred-scrub's .envrc loaded (see cred-scrub topic)."
  echo
else
  echo "Tier 0: no obvious prod-shaped env vars set. Good."
  echo
fi

# ── Tier 1 / Tier 2 dispatch ──
case "$TIER" in
  bwrap)
    if ! command -v bwrap >/dev/null 2>&1; then
      echo "ERROR: bwrap not installed (apt/pacman/dnf install bubblewrap)" >&2
      exit 127
    fi
    BINDS=(
      --proc /proc
      --dev /dev
      --tmpfs /tmp
      --tmpfs /home/agent
      --setenv HOME /home/agent
      --ro-bind "$TARGET" /work
      --chdir /work
      --unshare-pid --unshare-uts --unshare-ipc --unshare-cgroup --unshare-net
      --die-with-parent
    )
    for dir in /usr /etc /lib /lib64 /bin /sbin /nix/store /run/current-system; do
      [ -e "$dir" ] && BINDS+=( --ro-bind "$dir" "$dir" )
    done
    echo "Tier 1: hardened bwrap. /work is read-only into your target."
    echo "        Network: unshared. PID/UTS/IPC/cgroup: unshared."
    echo "        Capabilities: bounding set empty (bwrap default)."
    echo
    exec bwrap "${BINDS[@]}" "${CMD[@]}"
    ;;

  docker)
    if ! command -v docker >/dev/null 2>&1; then
      echo "ERROR: docker not installed" >&2
      exit 127
    fi
    if ! docker info >/dev/null 2>&1; then
      echo "ERROR: docker daemon not reachable (is it running? are you in the docker group?)" >&2
      exit 127
    fi
    DOCKER_FLAGS=(
      --rm
      --user "$(id -u):$(id -g)"
      --network=none
      --read-only
      --tmpfs /tmp
      --tmpfs /home/agent:uid=$(id -u),gid=$(id -g)
      -e HOME=/home/agent
      --cap-drop=ALL
      --security-opt=no-new-privileges
      -v "$TARGET":/work:ro
      -w /work
    )
    if [ -t 0 ] && [ -t 1 ]; then
      DOCKER_FLAGS+=( -it )
    fi
    echo "Tier 2: hardened docker. /work is read-only into your target."
    echo "        Network: none. Capabilities: dropped. FS: read-only +"
    echo "        tmpfs HOME. Default seccomp profile applies."
    echo "        (If you find yourself wanting --security-opt seccomp=unconfined,"
    echo "         stop and reconsider — that single flag undoes most of this.)"
    echo
    exec docker run "${DOCKER_FLAGS[@]}" ubuntu:24.04 "${CMD[@]}"
    ;;

  *)
    echo "ERROR: unknown --tier '$TIER' (use 'bwrap' or 'docker')" >&2
    exit 2
    ;;
esac
