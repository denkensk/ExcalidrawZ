#!/bin/bash
set -e
mkdir -p tasks memory scripts
[ ! -f AGENTS.md ] && touch AGENTS.md
[ ! -f memory/decisions.md ] && touch memory/decisions.md
[ ! -f CLAUDE.md ] && printf '@AGENTS.md\n\n# Claude-specific overrides (optional)\n' > CLAUDE.md
echo "✓ Project memory initialized"
