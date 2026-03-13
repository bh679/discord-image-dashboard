#!/usr/bin/env bash
# ============================================================
#  Discord Image Dashboard — Single-File Bootstrap
#
#  Downloads everything needed from scratch:
#    • Installs git, Node.js (via nvm)
#    • Clones all repositories
#    • Runs the credential wizard
#    • Starts both services
#
#  Usage (download and run):
#    curl -fsSL https://raw.githubusercontent.com/bh679/discord-image-dashboard/main/setup.sh | bash
#  Or:
#    bash setup.sh
# ============================================================

set -euo pipefail

# ── Repo URLs ─────────────────────────────────────────────────
ORCHESTRATOR_REPO="https://github.com/bh679/discord-image-dashboard"
BOT_REPO="https://github.com/bh679/discord-image-dashboard-bot"
CLIENT_REPO="https://github.com/bh679/discord-image-dashboard-client"
NVM_VERSION="0.39.7"
NODE_VERSION="20"
DEFAULT_INSTALL_DIR="$HOME/discord-image-dashboard"

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

banner() {
  printf "\n"
  printf "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗\n${RESET}"
  printf "${CYAN}${BOLD}║     Discord Image Dashboard — Setup Wizard           ║\n${RESET}"
  printf "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝\n${RESET}"
  printf "\n"
}

step() { printf "\n${BOLD}▶ %s${RESET}\n" "$1"; }
ok()   { printf "  ${GREEN}✔${RESET}  %s\n" "$1"; }
warn() { printf "  ${YELLOW}⚠${RESET}  %s\n" "$1"; }
fail() { printf "  ${RED}✖${RESET}  %s\n" "$1"; }
info() { printf "  ${CYAN}ℹ${RESET}  %s\n" "$1"; }
hr()   { printf "${CYAN}──────────────────────────────────────────────────────${RESET}\n"; }

prompt_value() {
  local var_name="$1"
  local prompt_text="$2"
  local default="$3"
  local input

  if [ -n "$default" ]; then
    printf "  ${BOLD}%s${RESET} [${CYAN}%s${RESET}]: " "$prompt_text" "$default"
  else
    printf "  ${BOLD}%s${RESET}: " "$prompt_text"
  fi

  read -r input
  if [ -z "$input" ] && [ -n "$default" ]; then
    eval "$var_name=\$default"
  else
    eval "$var_name=\$input"
  fi
}

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"
  local input
  printf "  ${BOLD}%s${RESET}: " "$prompt_text"
  read -rs input
  printf "\n"
  eval "$var_name=\$input"
}

# ── Detect OS ─────────────────────────────────────────────────
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [ -f /etc/debian_version ] || grep -qi debian /etc/os-release 2>/dev/null; then
    OS="debian"
  elif grep -qi "fedora\|rhel\|centos\|rocky\|alma" /etc/os-release 2>/dev/null; then
    OS="rhel"
  else
    OS="unknown"
  fi
}

# ── Install Homebrew (macOS only) ─────────────────────────────
ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [ -f "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
}

# ── Install git ───────────────────────────────────────────────
install_git() {
  info "Installing git..."
  case "$OS" in
    macos)
      if command -v brew >/dev/null 2>&1; then
        brew install git
      else
        info "Downloading git installer (~30 MB, no Xcode required)..."
        local GIT_PKG
        GIT_PKG="$(mktemp /tmp/git-XXXXXX.pkg)"
        if curl -fsSL \
            -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
            -o "$GIT_PKG" \
            "https://sourceforge.net/projects/git-osx-installer/files/latest/download"; then
          info "Installing git (requires sudo)..."
          sudo installer -pkg "$GIT_PKG" -target /
          rm -f "$GIT_PKG"
          ok "git installed"
        else
          rm -f "$GIT_PKG"
          fail "Could not download git installer. Install manually (no Xcode needed):"
          printf "    ${CYAN}https://git-scm.com/download/mac${RESET}\n"
          exit 1
        fi
      fi
      ;;
    debian)
      sudo apt-get update -qq
      sudo apt-get install -y git
      ;;
    rhel)
      sudo dnf install -y git 2>/dev/null || sudo yum install -y git
      ;;
    *)
      fail "Cannot auto-install git on this OS."
      printf "  Please install git manually:\n"
      printf "    Download: ${CYAN}https://git-scm.com/downloads${RESET}\n"
      exit 1
      ;;
  esac
}

# ── Install curl ──────────────────────────────────────────────
install_curl() {
  if command -v curl >/dev/null 2>&1; then return; fi
  info "Installing curl..."
  case "$OS" in
    macos)  ensure_brew && brew install curl ;;
    debian) sudo apt-get install -y curl ;;
    rhel)   sudo dnf install -y curl 2>/dev/null || sudo yum install -y curl ;;
    *)
      fail "curl not found and cannot auto-install."
      printf "  Please install curl manually, then re-run setup.\n"
      exit 1
      ;;
  esac
}

# ── Install Node.js via nvm ───────────────────────────────────
install_node_via_nvm() {
  install_curl

  export NVM_DIR="$HOME/.nvm"

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm v${NVM_VERSION}..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
  fi

  # Load nvm in the current session
  # shellcheck source=/dev/null
  \. "$NVM_DIR/nvm.sh"

  info "Installing Node.js v${NODE_VERSION} via nvm..."
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"

  ok "Node.js $(node --version) installed via nvm"

  # Add nvm to shell profile if not already there
  for profile in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    if [ -f "$profile" ] && ! grep -q "NVM_DIR" "$profile"; then
      {
        printf '\n# nvm (added by discord-image-dashboard setup)\n'
        printf 'export NVM_DIR="$HOME/.nvm"\n'
        printf '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"\n'
      } >> "$profile"
    fi
  done
}

# ── 1. Banner ─────────────────────────────────────────────────
banner
detect_os

# ── 2. Check & install system requirements ───────────────────
step "Checking system requirements"

NEED_NODE=false

# curl (needed for nvm)
if command -v curl >/dev/null 2>&1; then
  ok "curl $(curl --version | head -1 | awk '{print $2}')"
else
  warn "curl not found — will install"
  install_curl
  ok "curl installed"
fi

# git
if command -v git >/dev/null 2>&1; then
  ok "git $(git --version | awk '{print $3}')"
else
  warn "git not found — installing..."
  install_git
  ok "git $(git --version | awk '{print $3}') installed"
fi

# Node.js
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node --version | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 18 ]; then
    ok "Node.js v$NODE_VER"
  else
    warn "Node.js v$NODE_VER found but v18+ is required — upgrading via nvm"
    NEED_NODE=true
  fi
else
  warn "Node.js not found — installing via nvm"
  NEED_NODE=true
fi

if [ "$NEED_NODE" = true ]; then
  # Load nvm if already installed
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  install_node_via_nvm
fi

# npm (should be present after node)
if command -v npm >/dev/null 2>&1; then
  ok "npm $(npm --version)"
else
  fail "npm not found even after Node.js install. Something went wrong."
  info "Try: source ~/.nvm/nvm.sh && nvm install 20"
  exit 1
fi

# ── 3. Determine install location ─────────────────────────────
step "Installation location"

# If this script is already running inside an orchestrator clone, use that
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || pwd)"
ORCHESTRATOR_DIR=""

if [ -f "$SCRIPT_DIR/CLAUDE.md" ] && [ -d "$SCRIPT_DIR/discord-image-dashboard-bot" ] || \
   [ -f "$SCRIPT_DIR/CLAUDE.md" ] && [ -f "$SCRIPT_DIR/package.json" ]; then
  # Already inside the orchestrator
  ORCHESTRATOR_DIR="$SCRIPT_DIR"
  ok "Running from existing installation: $ORCHESTRATOR_DIR"
else
  # Fresh install — ask where to put it
  printf "\n"
  info "This will install Discord Image Dashboard to your system."
  prompt_value ORCHESTRATOR_DIR "Install directory" "$DEFAULT_INSTALL_DIR"

  # Expand ~ if user typed it literally
  ORCHESTRATOR_DIR="${ORCHESTRATOR_DIR/#\~/$HOME}"
fi

BOT_DIR="$ORCHESTRATOR_DIR/discord-image-dashboard-bot"
CLIENT_DIR="$ORCHESTRATOR_DIR/discord-image-dashboard-client"
LOGS_DIR="$ORCHESTRATOR_DIR/logs"

# ── 4. Clone / update orchestrator ────────────────────────────
if [ ! -d "$ORCHESTRATOR_DIR/.git" ]; then
  step "Cloning Discord Image Dashboard"
  if [ -d "$ORCHESTRATOR_DIR" ] && [ "$(ls -A "$ORCHESTRATOR_DIR" 2>/dev/null)" ]; then
    fail "Directory exists and is not empty: $ORCHESTRATOR_DIR"
    info "Choose a different location or empty the directory, then re-run."
    exit 1
  fi
  git clone "$ORCHESTRATOR_REPO" "$ORCHESTRATOR_DIR"
  ok "Orchestrator cloned to $ORCHESTRATOR_DIR"
else
  step "Updating orchestrator"
  git -C "$ORCHESTRATOR_DIR" pull --ff-only 2>/dev/null || warn "Could not pull latest — continuing with existing version"
  ok "Orchestrator up to date"
fi

# ── 5. Clone / update sub-repos ───────────────────────────────
step "Cloning sub-repos"

if [ ! -d "$BOT_DIR/.git" ]; then
  echo "  Cloning bot..."
  git clone "$BOT_REPO" "$BOT_DIR"
  ok "Bot cloned"
else
  echo "  Updating bot..."
  git -C "$BOT_DIR" pull --ff-only 2>/dev/null || warn "Could not pull bot — continuing with existing version"
  ok "Bot up to date"
fi

if [ ! -d "$CLIENT_DIR/.git" ]; then
  echo "  Cloning dashboard client..."
  git clone "$CLIENT_REPO" "$CLIENT_DIR"
  ok "Dashboard client cloned"
else
  echo "  Updating dashboard client..."
  git -C "$CLIENT_DIR" pull --ff-only 2>/dev/null || warn "Could not pull client — continuing with existing version"
  ok "Dashboard client up to date"
fi

# ── 6. Check existing config ──────────────────────────────────
EXISTING_ENV=false
RECONFIGURE=true

if [ -f "$BOT_DIR/.env" ] && grep -q "DISCORD_BOT_TOKEN=" "$BOT_DIR/.env" 2>/dev/null; then
  CURRENT_TOKEN=$(grep "^DISCORD_BOT_TOKEN=" "$BOT_DIR/.env" | cut -d= -f2-)
  if [ -n "$CURRENT_TOKEN" ] && [ "$CURRENT_TOKEN" != "your_bot_token_here" ]; then
    EXISTING_ENV=true
  fi
fi

if [ "$EXISTING_ENV" = true ]; then
  printf "\n"
  hr
  warn "Existing configuration found in discord-image-dashboard-bot/.env"
  printf "\n"
  printf "  ${BOLD}Reconfigure credentials?${RESET} [${CYAN}y/N${RESET}]: "
  read -r reconfigure_choice
  if [[ "$reconfigure_choice" =~ ^[Yy]$ ]]; then
    RECONFIGURE=true
  else
    RECONFIGURE=false
    ok "Keeping existing credentials"
  fi
fi

# ── 7. Credential wizard ──────────────────────────────────────
if [ "$RECONFIGURE" = true ]; then
  printf "\n"
  hr
  step "Discord credentials"
  printf "\n"

  # DISCORD_BOT_TOKEN
  printf "  ${CYAN}${BOLD}DISCORD_BOT_TOKEN${RESET}\n"
  printf "  Your bot's secret token. To get one:\n"
  printf "    1. Go to ${CYAN}https://discord.com/developers/applications${RESET}\n"
  printf "    2. Click ${BOLD}New Application${RESET} (or select an existing one)\n"
  printf "    3. Go to the ${BOLD}Bot${RESET} tab in the left sidebar\n"
  printf "    4. Click ${BOLD}Reset Token${RESET} and copy the value\n"
  printf "    5. Under Privileged Gateway Intents, enable:\n"
  printf "       • Server Members Intent\n"
  printf "       • Message Content Intent\n"
  printf "\n"
  prompt_secret BOT_TOKEN "Paste your bot token"
  while [ -z "$BOT_TOKEN" ]; do
    warn "Bot token cannot be empty."
    prompt_secret BOT_TOKEN "Paste your bot token"
  done
  ok "Bot token received"

  printf "\n"

  # DISCORD_GUILD_ID
  printf "  ${CYAN}${BOLD}DISCORD_GUILD_ID${RESET}\n"
  printf "  Your Discord server (guild) ID. To find it:\n"
  printf "    1. Open Discord → Settings → Advanced\n"
  printf "    2. Enable ${BOLD}Developer Mode${RESET}\n"
  printf "    3. Right-click your server icon in the left sidebar\n"
  printf "    4. Click ${BOLD}Copy Server ID${RESET}\n"
  printf "\n"
  prompt_value GUILD_ID "Paste your server ID" ""
  while [ -z "$GUILD_ID" ]; do
    warn "Server ID cannot be empty."
    prompt_value GUILD_ID "Paste your server ID" ""
  done
  ok "Server ID received"

  printf "\n"

  # Optional settings
  hr
  step "Optional settings (press Enter to accept defaults)"
  printf "\n"
  prompt_value BOT_PORT "Bot API port" "5001"
  prompt_value DATA_DIR "Bot data directory (relative to bot folder)" "./data"

  # Write .env
  printf "\n"
  step "Writing configuration files"

  cat > "$BOT_DIR/.env" <<EOF
# Discord Bot Configuration
# Generated by setup.sh — do not commit this file
DISCORD_BOT_TOKEN=$BOT_TOKEN
DISCORD_GUILD_ID=$GUILD_ID

# Server Configuration
PORT=$BOT_PORT
DATA_DIR=$DATA_DIR
EOF

  ok "discord-image-dashboard-bot/.env written"
fi

# ── 8. Write bot-config.json ──────────────────────────────────
BOT_ABS_PATH="$(cd "$BOT_DIR" && pwd)"
cat > "$CLIENT_DIR/bot-config.json" <<EOF
{
  "botPath": "$BOT_ABS_PATH"
}
EOF
ok "discord-image-dashboard-client/bot-config.json written"
info "Bot path: $BOT_ABS_PATH"

# ── 9. Install npm dependencies ───────────────────────────────
printf "\n"
step "Installing Node.js dependencies"

printf "  Installing bot dependencies...\n"
(cd "$BOT_DIR" && npm install --silent)
ok "Bot dependencies installed"

printf "  Installing dashboard dependencies...\n"
(cd "$CLIENT_DIR" && npm install --silent)
ok "Dashboard dependencies installed"

# ── 10. Create logs directory ─────────────────────────────────
mkdir -p "$LOGS_DIR"

# ── 11. Start services ────────────────────────────────────────
printf "\n"
hr
step "Starting services"
printf "\n"

BOT_PORT_NUM=$(grep "^PORT=" "$BOT_DIR/.env" | cut -d= -f2-)
BOT_PORT_NUM="${BOT_PORT_NUM:-5001}"

# Stop any existing PIDs
for pidfile in "$LOGS_DIR/bot.pid" "$LOGS_DIR/dashboard.pid"; do
  if [ -f "$pidfile" ]; then
    OLD_PID=$(cat "$pidfile")
    if kill -0 "$OLD_PID" 2>/dev/null; then
      info "Stopping previous process (PID $OLD_PID)..."
      kill "$OLD_PID" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$pidfile"
  fi
done

# Start bot
printf "  Starting Discord bot (API on port %s)...\n" "$BOT_PORT_NUM"
(cd "$BOT_DIR" && npm start > "$LOGS_DIR/bot.log" 2>&1) &
BOT_PID=$!
echo "$BOT_PID" > "$LOGS_DIR/bot.pid"

sleep 2

if kill -0 "$BOT_PID" 2>/dev/null; then
  ok "Bot started (PID $BOT_PID)"
else
  fail "Bot process exited. Check logs: tail -f $LOGS_DIR/bot.log"
  printf "\n  Last 10 lines of bot log:\n"
  tail -10 "$LOGS_DIR/bot.log" 2>/dev/null || true
  printf "\n"
  warn "Dashboard will still start — fix bot credentials and re-run to restart the bot."
fi

# Start dashboard
printf "  Starting dashboard server (port 5002)...\n"
(cd "$CLIENT_DIR" && npm start > "$LOGS_DIR/dashboard.log" 2>&1) &
DASHBOARD_PID=$!
echo "$DASHBOARD_PID" > "$LOGS_DIR/dashboard.pid"

sleep 1

if kill -0 "$DASHBOARD_PID" 2>/dev/null; then
  ok "Dashboard started (PID $DASHBOARD_PID)"
else
  fail "Dashboard process exited. Check logs: tail -f $LOGS_DIR/dashboard.log"
  tail -10 "$LOGS_DIR/dashboard.log" 2>/dev/null || true
fi

# ── 12. Create desktop shortcut ──────────────────────────────
step "Creating desktop shortcut"

DESKTOP_DIR="$HOME/Desktop"
DASHBOARD_URL="http://localhost:5002"

if [[ "$OS" == "macos" ]]; then
  # macOS: create a .webloc file (opens in default browser on double-click)
  SHORTCUT="$DESKTOP_DIR/Discord Image Dashboard.webloc"
  cat > "$SHORTCUT" <<WEBLOC
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>URL</key>
  <string>$DASHBOARD_URL</string>
</dict>
</plist>
WEBLOC
  ok "Desktop shortcut created: ~/Desktop/Discord Image Dashboard.webloc"

elif [ -d "$DESKTOP_DIR" ]; then
  # Linux with desktop (GNOME/KDE/XFCE etc.) — create a .desktop file
  SHORTCUT="$DESKTOP_DIR/discord-image-dashboard.desktop"
  cat > "$SHORTCUT" <<DESKTOP_FILE
[Desktop Entry]
Version=1.0
Type=Link
Name=Discord Image Dashboard
Comment=Open the Discord Image Dashboard
URL=$DASHBOARD_URL
Icon=text-html
DESKTOP_FILE
  chmod +x "$SHORTCUT"
  ok "Desktop shortcut created: $DESKTOP_DIR/discord-image-dashboard.desktop"

else
  warn "No Desktop folder found — skipping shortcut creation"
  info "Open the dashboard at: $DASHBOARD_URL"
fi

# ── 13. Summary ───────────────────────────────────────────────
printf "\n"
hr
printf "\n"
printf "${GREEN}${BOLD}  Setup complete!${RESET}\n"
printf "\n"
printf "  ${BOLD}Services running:${RESET}\n"
printf "    Bot API    →  ${CYAN}http://localhost:%s${RESET}\n" "$BOT_PORT_NUM"
printf "    Dashboard  →  ${CYAN}http://localhost:5002${RESET}\n"
printf "\n"
printf "  ${BOLD}Installation:${RESET}\n"
printf "    %s\n" "$ORCHESTRATOR_DIR"
printf "\n"
printf "  ${BOLD}Logs:${RESET}\n"
printf "    tail -f %s/bot.log\n" "$LOGS_DIR"
printf "    tail -f %s/dashboard.log\n" "$LOGS_DIR"
printf "\n"
printf "  ${BOLD}To stop services:${RESET}\n"
printf "    kill \$(cat %s/bot.pid) \$(cat %s/dashboard.pid)\n" "$LOGS_DIR" "$LOGS_DIR"
printf "\n"
printf "  ${BOLD}To re-run setup:${RESET}  ${CYAN}bash %s/setup.sh${RESET}\n" "$ORCHESTRATOR_DIR"
printf "\n"
printf "  ${BOLD}Desktop shortcut:${RESET} double-click to open the dashboard\n"
printf "\n"
hr
