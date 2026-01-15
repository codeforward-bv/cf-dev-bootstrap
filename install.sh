#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------
# Codeforward cf-dev-bootstrap installer (macOS-focused)
#
# - Installs Homebrew if missing (macOS only)
# - Runs `brew update`
# - Installs deps via Brewfile: `brew bundle --file=...` (includes python)
# - Installs cf-dev-bootstrap into ~/.local/bin as a wrapper
# - Downloads the real cf-dev-bootstrap script into ~/.local/share/cf-dev-bootstrap/
# - Creates a dedicated venv for cf-dev-bootstrap (avoids PEP 668)
# - Ensures python package 'click' exists in that venv
#
# Safe to re-run.
# ------------------------------------------------------------------

REPO_RAW_BASE="https://raw.githubusercontent.com/codeforward-bv/cf-dev-bootstrap/main"

CF_DEV_BIN_DIR="${HOME}/.local/bin"
CF_DEV_BIN="${CF_DEV_BIN_DIR}/cf-dev-bootstrap"

CF_DEV_STATE_DIR="${HOME}/.local/share/cf-dev-bootstrap"
CF_DEV_SCRIPT="${CF_DEV_STATE_DIR}/cf-dev-bootstrap"
CF_DEV_VENV_DIR="${CF_DEV_STATE_DIR}/venv"
CF_DEV_PY="${CF_DEV_VENV_DIR}/bin/python"

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

    # Try to make brew available in this shell
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

  # Install as defined in Brewfile (including python)
  brew bundle --file="${BREWFILE_PATH}"

  echo
else
  echo "Non-macOS system detected. Skipping Homebrew/Brewfile dependency install."
  echo "You must install dependencies manually: python3 (with venv), and optionally postgresql/psql."
  echo
fi

# ------------------------------------------------------------------
# 2) Ensure brew paths are preferred (macOS) so python3 is Homebrew Python
# ------------------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    export PATH="/opt/homebrew/bin:${PATH}"
  elif [[ -x /usr/local/bin/brew ]]; then
    export PATH="/usr/local/bin:${PATH}"
  fi
fi

# ------------------------------------------------------------------
# 3) Ensure python3 exists
# ------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found on PATH."
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "Ensure 'python' is included in your Brewfile (brew bundle)."
  fi
  exit 1
fi

# ------------------------------------------------------------------
# 4) Download cf-dev-bootstrap script (stored outside PATH)
# ------------------------------------------------------------------
mkdir -p "${CF_DEV_STATE_DIR}"

echo "Downloading cf-dev-bootstrap script to ${CF_DEV_SCRIPT} ..."
curl -fsSL "${REPO_RAW_BASE}/cf-dev-bootstrap" -o "${CF_DEV_SCRIPT}"
chmod +x "${CF_DEV_SCRIPT}"
echo "  ✔ cf-dev-bootstrap script installed"

echo

# ------------------------------------------------------------------
# 5) Create/ensure dedicated venv for cf-dev-bootstrap + install click
# ------------------------------------------------------------------
if [[ ! -x "${CF_DEV_PY}" ]]; then
  echo "Creating virtual environment for cf-dev-bootstrap at ${CF_DEV_VENV_DIR} ..."
  python3 -m venv "${CF_DEV_VENV_DIR}"
  echo "  ✔ venv created"
else
  echo "Virtual environment already exists at ${CF_DEV_VENV_DIR}"
fi

echo "Ensuring Python dependency 'click' is installed in cf-dev-bootstrap venv..."
"${CF_DEV_PY}" - <<'PY'
import importlib.util
import subprocess
import sys

if importlib.util.find_spec("click") is None:
    print("  → Installing click")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "click"])
else:
    print("  ✔ click already installed")
PY

echo

# ------------------------------------------------------------------
# 6) Install wrapper into ~/.local/bin
# ------------------------------------------------------------------
mkdir -p "${CF_DEV_BIN_DIR}"

echo "Installing cf-dev-bootstrap wrapper to ${CF_DEV_BIN} ..."
cat > "${CF_DEV_BIN}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CF_DEV_PY="${HOME}/.local/share/cf-dev-bootstrap/venv/bin/python"
CF_DEV_SCRIPT="${HOME}/.local/share/cf-dev-bootstrap/cf-dev-bootstrap"

if [[ ! -x "${CF_DEV_PY}" ]]; then
  echo "ERROR: cf-dev-bootstrap virtualenv not found at:"
  echo "  ${CF_DEV_PY}"
  echo "Re-run the installer."
  exit 1
fi

if [[ ! -f "${CF_DEV_SCRIPT}" ]]; then
  echo "ERROR: cf-dev-bootstrap script not found at:"
  echo "  ${CF_DEV_SCRIPT}"
  echo "Re-run the installer."
  exit 1
fi

exec "${CF_DEV_PY}" "${CF_DEV_SCRIPT}" "$@"
EOF

chmod +x "${CF_DEV_BIN}"
echo "  ✔ wrapper installed"

echo

# ------------------------------------------------------------------
# 7) Ensure ~/.local/bin is on PATH
# ------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

if ! echo "${PATH}" | tr ':' '\n' | grep -qx "${CF_DEV_BIN_DIR}"; then
  echo "Adding ~/.local/bin to PATH in ${ZSHRC}..."

  touch "${ZSHRC}"

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

echo "== Installation complete =="
