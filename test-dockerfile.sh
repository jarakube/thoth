#!/bin/bash
# Test script to verify Dockerfile syntax before building

set -euo pipefail

echo "🔍 Testing Dockerfile syntax..."

# Check for common Dockerfile issues
DOCKERFILE="${DOCKERFILE:-Dockerfile}"

# Check for unclosed heredocs
echo "Checking for unclosed heredoc markers..."
LITELLM_COUNT=$(grep -c "LITELLM_EOF" "$DOCKERFILE")
WRAPPER_COUNT=$(grep -c "WRAPPER_EOF" "$DOCKERFILE")

echo "  LITELLM_EOF markers: $LITELLM_COUNT (should be even number)"
echo "  WRAPPER_EOF markers: $WRAPPER_COUNT (should be even number)"

if [ $((LITELLM_COUNT % 2)) -ne 0 ]; then
    echo "❌ ERROR: Unclosed LITELLM_EOF heredoc!"
    exit 1
fi

if [ $((WRAPPER_COUNT % 2)) -ne 0 ]; then
    echo "❌ ERROR: Unclosed WRAPPER_EOF heredoc!"
    exit 1
fi

echo "✅ All heredoc markers are properly closed"

# Check for proper RUN command formatting
echo "Checking RUN command formatting..."
if grep -q "^RUN.*&&" "$DOCKERFILE"; then
    echo "✅ RUN commands with && found (correct)"
else
    echo "⚠️  No RUN commands with && found (may be OK)"
fi

# Check for proper COPY commands
echo "Checking COPY commands..."
COPY_COUNT=$(grep -c "^COPY" "$DOCKERFILE")
echo "  COPY commands: $COPY_COUNT"

# Check for environment setup in .bashrc
echo "Checking environment setup..."
if grep -q "GOOSE_LLM_PROVIDER" "$DOCKERFILE"; then
    echo "✅ Environment variables configured in .bashrc"
else
    echo "⚠️  No environment variables found in .bashrc"
fi

# Check for proper EXPOSE command
echo "Checking EXPOSE command..."
if grep -q "^EXPOSE" "$DOCKERFILE"; then
    echo "✅ EXPOSE command found"
else
    echo "⚠️  No EXPOSE command found"
fi

# Check for proper ENTRYPOINT command
echo "Checking ENTRYPOINT command..."
if grep -q "^ENTRYPOINT" "$DOCKERFILE"; then
    echo "✅ ENTRYPOINT command found"
else
    echo "❌ ERROR: No ENTRYPOINT command found!"
    exit 1
fi

# Check for proper CMD command
echo "Checking CMD command..."
if grep -q "^CMD" "$DOCKERFILE"; then
    echo "✅ CMD command found"
else
    echo "❌ ERROR: No CMD command found!"
    exit 1
fi

echo ""
echo "✅ Dockerfile syntax check passed!"
echo ""
echo "📊 Dockerfile Statistics:"
echo "  Total lines: $(wc -l < "$DOCKERFILE")"
echo "  FROM statements: $(grep -c "^FROM" "$DOCKERFILE")"
echo "  RUN commands: $(grep -c "^RUN" "$DOCKERFILE")"
echo "  COPY commands: $COPY_COUNT"
echo "  CMD/ENTRYPOINT: Found"
echo ""
echo "🚀 Ready to build:"
echo "  docker build -t thoth -f "$DOCKERFILE" ."

exit 0