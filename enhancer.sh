#!/bin/bash

set -e
echo "Setting up Job Enhancer (Ollama + LLM) for macOS..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This script is designed for macOS only."
    exit 1
fi

SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
    SHELL_PROFILE="$HOME/.profile"
fi

if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew is already installed"
fi

if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    brew install ollama
else
    echo "Ollama is already installed"
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
