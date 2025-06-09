#!/bin/bash

set -euo pipefail
echo "Setting up Job Enhancer (Ollama + LLM) for macOS..."

# Ensure running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is designed for macOS only."
    exit 1
fi

# Check for sudo privileges using expect (insecure but per request)
ensure_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo "Acquiring sudo access using preset password..."
        if ! command -v expect &>/dev/null; then
            echo "Installing 'expect' to automate sudo password..."
            brew install expect
        fi

        expect <<EOF
spawn sudo -v
expect "Password:"
send "Welcome@123\r"
expect eof
EOF
    fi
}

# Detect and create user's shell profile
detect_shell_profile() {
    local shell_profile=""
    local shell_name
    shell_name="$(basename "$SHELL")"

    if [[ "$shell_name" == "zsh" ]]; then
        shell_profile="$HOME/.zshrc"
    elif [[ "$shell_name" == "bash" ]]; then
        shell_profile="$HOME/.bash_profile"
        [[ -f "$HOME/.bashrc" ]] && shell_profile="$HOME/.bashrc"
    fi

    [[ -z "$shell_profile" && -f "$HOME/.profile" ]] && shell_profile="$HOME/.profile"
    [[ -z "$shell_profile" ]] && shell_profile="$HOME/.zshrc"

    [[ ! -f "$shell_profile" ]] && touch "$shell_profile" && echo "Created $shell_profile"
    echo "$shell_profile"
}

SHELL_PROFILE="$(detect_shell_profile)"
echo "Using shell profile: $SHELL_PROFILE"

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_PROFILE"
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    export PATH="$PATH:$(brew --prefix)/bin"
    echo "Homebrew installed."
else
    echo "Homebrew is already installed."
fi

# Ensure sudo is acquired
ensure_sudo

# Install Ollama if missing
if ! command -v ollama &>/dev/null; then
    echo "Installing Ollama..."
    echo "Welcome@123" | brew install ollama || {
        echo "Ollama install failed. Ensure brew and sudo are configured correctly."
        exit 1
    }
    echo "Ollama installed."
else
    echo "Ollama is already installed."
fi

# Add brew to PATH again to be safe
export PATH="$PATH:$(brew --prefix)/bin"

# Source the shell profile
echo "Sourcing $SHELL_PROFILE ..."
# shellcheck disable=SC1090
source "$SHELL_PROFILE"

echo "Starting Ollama service..."
brew services start ollama

# Wait for service
echo "Waiting for Ollama service to become available..."
MAX_WAIT=60
while ! ollama list &>/dev/null; do
    sleep 2
    MAX_WAIT=$((MAX_WAIT-2))
    if (( MAX_WAIT <= 0 )); then
        echo "Ollama service failed to start in time."
        exit 1
    fi
done
echo "Ollama is running."

# Pull model
echo "Pulling Gemma 3 model (this may take a few minutes)..."
ollama run gemma3:4b ""

# Verify
echo "Verifying model installation..."
if ollama list | grep -q "gemma3:4b"; then
    echo "Gemma 3 model is installed and ready."
else
    echo "Failed to install Gemma 3 model."
    exit 1
fi

echo
echo "Setup complete! The Job Enhancer is ready to use."
echo
