#!/bin/bash
set -e

MODEL_NAME="qwen3:1.7b"

# Start Ollama server in the background
ollama serve &
SERVER_PID=$!

# Wait for server to be ready
echo "Waiting for Ollama server to start..."
sleep 5  # adjust if needed on Pi

# Only pull the model if it's not already present
echo "Checking if $MODEL_NAME is already available..."
if ! ollama list | grep -q "$MODEL_NAME"; then
    echo "Pulling $MODEL_NAME via Ollama..."
    ollama pull "$MODEL_NAME"
else
    echo "$MODEL_NAME is already available"
fi

# Wait for server process to keep container alive
wait $SERVER_PID