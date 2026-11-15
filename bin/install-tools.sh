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
