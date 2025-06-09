#!/bin/bash

set -e
echo "Setting up Job Enhancer (Ollama + LLM) for macOS..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is designed for macOS only."
    exit 1
fi

# Check for sudo access
echo "Checking for administrator privileges..."
if ! sudo -n true 2>/dev/null; then
    echo "This script requires administrator privileges to install Homebrew and Ollama."
    echo "You will be prompted for your password once."
    echo "Press Ctrl+C to cancel, or Enter to continue..."
    read -r
    
    # Validate sudo access and cache credentials for 5 minutes
    if ! sudo -v; then
        echo "Error: Administrator privileges are required. Exiting."
        exit 1
    fi
else
    echo "Administrator privileges confirmed."
fi

# Determine and create shell profile if needed
SHELL_PROFILE=""
if [[ "$SHELL" == *"zsh"* ]] || [[ "$0" == *"zsh"* ]]; then
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.zprofile" ]; then
        SHELL_PROFILE="$HOME/.zprofile"
    else
        SHELL_PROFILE="$HOME/.zshrc"
        touch "$SHELL_PROFILE"
        echo "Created $SHELL_PROFILE"
    fi
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    SHELL_PROFILE="$HOME/.profile"
else
    SHELL_PROFILE="$HOME/.zshrc"
    touch "$SHELL_PROFILE"
    echo "Created $SHELL_PROFILE"
fi

echo "Using shell profile: $SHELL_PROFILE"

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    # Keep sudo session alive
    sudo -v
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
        if [ $? -eq 0 ]; then
            echo "Added Homebrew to shell profile: $SHELL_PROFILE"
        else
            echo "Warning: Could not write to shell profile: $SHELL_PROFILE"
        fi
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    # Refresh the terminal environment
    echo "Refreshing terminal environment..."
    source "$SHELL_PROFILE" 2>/dev/null || true
else
    echo "Homebrew is already installed"
fi

if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    brew install ollama
    echo "Ollama installed successfully"
else
    echo "Ollama is already installed"
fi

echo "Ensuring Ollama is available in current session..."
source "$SHELL_PROFILE" 2>/dev/null || true

if command -v ollama &> /dev/null; then
    echo "Ollama is available in current session"
else
    echo "Ollama may require a new terminal session to be available"
fi

echo "Starting Ollama service..."
brew services start ollama

sleep 5

echo "Pulling and loading Gemma 3 model (this may take a few minutes)..."
ollama pull gemma3:4b

echo "Loading model into memory..."
ollama run gemma3:4b ""

echo "Verifying installation..."
if ollama list | grep -q "gemma3:4b"; then
    echo "Gemma 3 model is installed and ready"
else
    echo "Failed to install Gemma 3 model"
    exit 1
fi

if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "Ollama service is running on http://localhost:11434"
else
    echo "Ollama service is not responding"
    exit 1
fi
echo ""
echo "Setup complete! The job enhancer is ready to use."
echo ""
