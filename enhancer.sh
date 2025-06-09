#!/bin/bash

set -euo pipefail
echo "Setting up Job Enhancer (Ollama + LLM) for macOS..."

# Ensure running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is designed for macOS only."
    exit 1
fi

# Check for sudo privileges
if [[ $EUID -eq 0 ]]; then
    SUDO_CMD=""
else
    echo "Checking for administrator privileges..."
    if sudo -n true 2>/dev/null; then
        echo "Administrator privileges confirmed (cached)."
        SUDO_CMD="sudo"
    else
        echo "Administrator privileges required. You will be prompted for your password."
        sudo -v || { echo "Sudo required but not granted. Exiting."; exit 1; }
        SUDO_CMD="sudo"
    fi
fi

# Determine user's shell and profile
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

    # Fallbacks
    [[ -z "$shell_profile" && -f "$HOME/.profile" ]] && shell_profile="$HOME/.profile"
    [[ -z "$shell_profile" ]] && shell_profile="$HOME/.zshrc"

    # Ensure profile exists
    [[ ! -f "$shell_profile" ]] && touch "$shell_profile" && echo "Created $shell_profile"
    echo "$shell_profile"
}

SHELL_PROFILE="$(detect_shell_profile)"
echo "Using shell profile: $SHELL_PROFILE"

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon or Intel
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_PROFILE"
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    export PATH="$PATH:$(brew --prefix)/bin"
    echo "Homebrew installed and shell environment updated."
else
    echo "Homebrew is already installed."
fi

# Install Ollama if missing
if ! command -v ollama &>/dev/null; then
    echo "Installing Ollama..."
    brew install ollama
    echo "Ollama installed successfully."
else
    echo "Ollama is already installed."
fi

# Ensure Ollama is in PATH for current session
export PATH="$PATH:$(brew --prefix)/bin"

# Source the profile to ensure PATH is up-to-date
echo "Sourcing profile $SHELL_PROFILE ..."
# shellcheck source=/dev/null
source "$SHELL_PROFILE"

echo "Starting Ollama service..."
brew services start ollama

# Wait for Ollama service to become available (by checking ollama list)
echo "Waiting for Ollama service to be available..."
MAX_WAIT=60
while ! ollama list &>/dev/null; do
    sleep 2
    MAX_WAIT=$((MAX_WAIT-2))
    if (( MAX_WAIT <= 0 )); then
        echo "Ollama service failed to start within expected time."
        exit 1
    fi
done
echo "Ollama service is running."

echo "Pulling and loading Gemma 3 model (this may take a few minutes)..."
ollama pull gemma3:4b

echo "Verifying installation..."
if ollama list | grep -q "gemma3:4b"; then
    echo "Gemma 3 model is installed and ready."
else
    echo "Failed to install Gemma 3 model."
    exit 1
fi

echo
echo "Setup complete! The Job Enhancer is ready to use."
echo
