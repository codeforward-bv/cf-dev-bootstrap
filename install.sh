#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# Codeforward cf-dev-bootstrap installer (macOS-focused)
#
# - Installs Homebrew if missing (macOS only)
# - Runs `brew update`
# - Installs deps via Brewfile: `brew bundle --file=...`
# - Installs cf-dev-bootstrap into ~/.local/bin
# - Ensures python package 'click' exists for python3
#
# Safe to re-run.
# ------------------------------------------------------------------

REPO_RAW_BASE="https://raw.githubusercontent.com/codeforward-bv/cf-dev-bootstrap/main"

CF_DEV_BIN_DIR="${HOME}/.local/bin"
CF_DEV_BIN="${CF_DEV_BIN_DIR}/cf-dev-bootstrap"

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

echo "== Codeforward cf-dev-bootstrap installer =="
echo

# ------------------------------------------------------------------
# 1) macOS dependency install via Homebrew + Brewfile
# ------------------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
  echo "Detected macOS."

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Try to make brew available in this shell (Apple Silicon default path)
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew installation completed but 'brew' is still not on PATH."
    echo "Open a new terminal, or add Homebrew to your PATH per the installer output."
    exit 1
  fi

  echo
  echo "Updating Homebrew..."
  brew update

  echo
  echo "Installing dependencies using Brewfile..."
  BREWFILE_PATH="${TMP_DIR}/Brewfile"
  curl -fsSL "${REPO_RAW_BASE}/Brewfile" -o "${BREWFILE_PATH}"

  # Install as defined in Brewfile (including restart_service: :changed)
  brew bundle --file="${BREWFILE_PATH}"

  echo
else
  echo "Non-macOS system detected. Skipping Homebrew/Brewfile dependency install."
  echo "You must install dependencies manually: uv, and optionally postgresql/psql."
  echo
fi

# ------------------------------------------------------------------
# 2) Install cf-dev-bootstrap
# ------------------------------------------------------------------
mkdir -p "${CF_DEV_BIN_DIR}"

echo "Installing cf-dev-bootstrap to ${CF_DEV_BIN} ..."
curl -fsSL "${REPO_RAW_BASE}/cf-dev-bootstrap" -o "${CF_DEV_BIN}"
chmod +x "${CF_DEV_BIN}"
echo "  ✔ cf-dev-bootstrap installed"

echo
# ------------------------------------------------------------------
# 3) Ensure ~/.local/bin is on PATH
# ------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

if ! echo "${PATH}" | tr ':' '\n' | grep -qx "${CF_DEV_BIN_DIR}"; then
  echo "Adding ~/.local/bin to PATH in ${ZSHRC}..."

  # Ensure file exists
  touch "${ZSHRC}"

  # Only add if not already present
  if ! grep -Fq "${PATH_LINE}" "${ZSHRC}"; then
    {
      echo
      echo "# Added by Codeforward cf-dev-bootstrap installer"
      echo "${PATH_LINE}"
    } >> "${ZSHRC}"
    echo "  ✔ PATH updated in ${ZSHRC}"
  else
    echo "  ✔ PATH already configured in ${ZSHRC}"
  fi

  echo "Please restart your terminal to apply PATH changes."
  echo
fi

# ------------------------------------------------------------------
# 4) Ensure click is installed for python3
# ------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  echo "Ensuring Python dependency 'click' is installed for python3..."
  python3 - <<'PY'
import importlib.util
import subprocess
import sys

if importlib.util.find_spec("click") is None:
    print("  → Installing click (user site)")
    subprocess.check_call([sys.executable, "-m", "pip3", "install", "--user", "click"])
else:
    print("  ✔ click already installed")
PY
else
  echo "WARNING: python3 not found on PATH. Install Python 3 and ensure 'click' is installed."
fi

echo
echo "== Installation complete =="
