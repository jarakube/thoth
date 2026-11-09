# Goose and Goosetown Integration

This document describes the changes made to integrate goose and goosetown into the coding agent container.

## Changes Made

### 1. Updated Dockerfile

The main Dockerfile (`Dockerfile`) has been updated to include goose and goosetown support.

#### Added Dependencies:
- `python3-yaml` - Required by goosetown
- `pipx` - For Python package management
- `wget` - For downloading goose binary
- `unzip` - For extracting packages

#### Added goose Binary Installation:
```dockerfile
RUN mkdir -p /usr/local/bin \
    && curl -fsSL https://github.com/aaif-goose/goose/releases/download/v1.25.0/goose-v1.25.0-linux-amd64 -o /usr/local/bin/goose \
    && chmod +x /usr/local/bin/goose
```

#### Added goosetown Directory:
```dockerfile
# Install goosetown
RUN mkdir -p /app/goosetown
COPY goosetown/ /app/goosetown/
```

#### Added goosetown Scripts for appuser:
```dockerfile
# Copy goosetown scripts for appuser
COPY --chown=appuser:appuser goosetown/goose_gui /usr/local/bin/goose_gui
COPY --chown=appuser:appuser goosetown/gtwall /usr/local/bin/gtwall
COPY --chown=appuser:appuser goosetown/dashboard /usr/local/bin/goosetown-dashboard
```

#### Added Environment Setup:
```dockerfile
# Set up goosetown environment for appuser
RUN echo 'export PATH="/usr/local/bin:$PATH"' >> /home/appuser/.bashrc \
    && echo 'export GOOSETOWN_DIR="/app/goosetown"' >> /home/appuser/.bashrc \
    && echo 'export PYTHONPATH="/app/goosetown:${PYTHONPATH:-}"' >> /home/appuser/.bashrc
```

#### Updated File Permissions:
```dockerfile
RUN chown -R appuser:appuser /home/appuser/.local /home/appuser/.ssh /home/appuser/.config /app/goosetown /app/scripts
```

## What This Enables

With these changes, the coding agent container now includes:

1. **goose CLI** - The AI agent framework from block/aaif-goose
   - Available at `/usr/local/bin/goose`
   - Can be invoked directly or via the entrypoint

2. **goosetown** - The multi-agent coordination framework
   - Located at `/app/goosetown`
   - Includes all goosetown scripts (goose, goose_gui, gtwall, dashboard)
   - Environment variables are set for easy access

3. **Telepathy Support** - Enables orchestrator → delegate communication
   - The goose wrapper creates telepathy files for session-based communication
   - Wall files for inter-agent communication

## Usage Examples

### Running goose directly:
```bash
./goose session
```

### Running goosetown orchestrator:
```bash
./goose load source:goosetown-orchestrator
```

### Using gtwall for communication:
```bash
./gtwall --usage
```

## Backward Compatibility

The changes maintain backward compatibility:
- The default CMD is still `opencode`
- The entrypoint script remains unchanged
- Existing workflows continue to work
- New functionality is additive only

## Testing

To test the integration:

1. Build the container:
   ```bash
   docker build -t goosetown-agent .
   ```

2. Run the container:
   ```bash
   docker run -it goosetown-agent bash
   ```

3. Verify goose is available:
   ```bash
   goose --version
   ```

4. Verify goosetown files are present:
   ```bash
   ls -la /app/goosetown/
   ```

5. Test telepathy:
   ```bash
   ./goose doctor
   ```

## Notes

- The goose binary is downloaded from GitHub releases (v1.25.0)
- goosetown is copied from the local directory structure
- Python dependencies for goosetown can be installed using pipx by users as needed
- The integration follows the existing container structure and patterns