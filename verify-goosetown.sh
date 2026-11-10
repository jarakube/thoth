#!/bin/bash
# Verification script for goose and goosetown integration

set -e

echo "🔍 Verifying goose and goosetown integration..."

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found!"
    exit 1
fi

# Check if goose binary is referenced in Dockerfile
if ! grep -q "goose-v1.25.0-linux-amd64" Dockerfile; then
    echo "❌ goose binary download not found in Dockerfile!"
    exit 1
fi

# Check if goosetown directory copy is in Dockerfile
if ! grep -q "COPY goosetown/ /app/goosetown/" Dockerfile; then
    echo "❌ goosetown directory copy not found in Dockerfile!"
    exit 1
fi

# Check if goose_gui is copied
if ! grep -q "goose_gui" Dockerfile; then
    echo "❌ goose_gui copy not found in Dockerfile!"
    exit 1
fi

# Check if gtwall is copied
if ! grep -q "gtwall" Dockerfile; then
    echo "❌ gtwall copy not found in Dockerfile!"
    exit 1
fi

# Check if GOOSETOWN_DIR environment variable is set
if ! grep -q 'GOOSETOWN_DIR="/app/goosetown"' Dockerfile; then
    echo "❌ GOOSETOWN_DIR environment variable not set in Dockerfile!"
    exit 1
fi

# Check if python3-yaml is installed
if ! grep -q "python3-yaml" Dockerfile; then
    echo "❌ python3-yaml dependency not found in Dockerfile!"
    exit 1
fi

# Check if pipx is installed
if ! grep -q "pipx" Dockerfile; then
    echo "❌ pipx dependency not found in Dockerfile!"
    exit 1
fi

echo "✅ All goose and goosetown integration checks passed!"
echo ""
echo "Summary of changes:"
echo "- goose binary will be installed from GitHub releases"
echo "- goosetown directory will be copied to /app/goosetown"
echo "- goose_gui, gtwall, and dashboard scripts will be available"
echo "- Environment variables will be set for goosetown"
echo "- Python dependencies (starlette, uvicorn, pyyaml) are available"
echo ""
echo "To build the container with goose and goosetown support:"
echo "  docker build -t thoth ."
echo ""
echo "To test the container:"
echo "  docker run -it thoth bash"
echo "  goose --version"
echo "  ls -la /app/goosetown/"

exit 0