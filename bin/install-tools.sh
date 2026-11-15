#!/usr/bin/env bash
# Install tools that live outside Nix and dnf and keep themselves up to date.
# Safe to re-run: each tool is skipped when it is already present.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# polytoken installs and updates itself, which a read-only Nix store path would
# prevent. The installer verifies the release checksum and needs no root. Set
# PT_VERSION to pin a release, or leave it to track latest.
if [ "${SKIP_POLYTOKEN:-0}" != "1" ]; then
  if have polytoken; then
    echo "polytoken: $(polytoken --version 2>/dev/null || echo present)"
  else
    echo "polytoken: installing ${PT_VERSION:-latest}"
    curl -fsS https://get.polytoken.dev |
      env PT_VERSION="${PT_VERSION:-latest}" PT_INSTALL_DIR="$HOME/.local/bin" bash
  fi
fi

# roast is a brew cask in the Bluesky tap and also builds from source. Where
# brew exists the cask is the package, so brew upgrade keeps it current; else it
# is built with Go, which is what a guest has and where the binary already lives.
# Neither path reinstalls when the version already matches the latest release,
# so re-running this file updates; ROAST_VERSION still pins a tag.
if [ "${SKIP_ROAST:-0}" != "1" ]; then
  if have brew; then
    if have roast; then
      echo "roast: $(roast --version 2>/dev/null | head -1 || echo present)"
    else
      echo "roast: installing from the bluesky tap"
      brew install --cask bluesky-social/tap/roast
    fi
  elif have go && have curl; then
    # Neither the probe nor the API call may fail the run: a fresh machine has
    # no roast yet, and a bad network should leave the tool as it was.
    installed=
    if have roast; then
      installed=$(roast --version 2>/dev/null |
        sed -n 's/^roast version \(v[0-9][^ ]*\).*/\1/p' | head -1 || true)
    fi
    latest=${ROAST_VERSION:-}
    if [ -z "$latest" ]; then
      latest=$(curl -fsSL https://api.github.com/repos/bluesky-social/roast/releases/latest 2>/dev/null |
        sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1 || true)
    fi
    if [ -n "$installed" ] && { [ -z "$latest" ] || [ "$installed" = "$latest" ]; }; then
      echo "roast: $installed"
    else
      echo "roast: building ${latest:-latest} with go"
      go install "github.com/bluesky-social/roast/cmd/roast@${latest:-latest}"
    fi
  else
    echo "roast: skipped, needs brew or go" >&2
  fi
fi
