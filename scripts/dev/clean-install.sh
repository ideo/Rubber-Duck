#!/bin/bash
# ============================================================
# Clean Install — Remove all Duck Duck Duck traces for testing
# ============================================================
#
# USE WITH CARE: This removes the duck plugin, app data, and
# settings entries. Other Claude plugins and settings are NOT
# touched. Safe to run, but make sure Claude Desktop and the
# duck widget are NOT running first.
#
# Usage: ./scripts/dev/clean-install.sh
# Then install the DMG fresh and test the install flow.
# ============================================================

set -e

echo "=== Duck Duck Duck — Clean Install Reset ==="
echo ""

# 1. Kill duck processes
echo "[1/8] Stopping duck processes..."
killall "Duck Duck Duck" 2>/dev/null || true
killall DuckDuckDuck 2>/dev/null || true
killall RubberDuckWidget 2>/dev/null || true
echo "  Done"

# 2. Remove duck plugin from Claude's plugin cache
echo "[2/8] Removing plugin cache..."
rm -rf ~/.claude/plugins/cache/duck-duck-duck-marketplace
rm -rf ~/.claude/plugins/marketplaces/duck-duck-duck-marketplace
echo "  Done"

# 3. Remove duck from installed_plugins.json
echo "[3/8] Cleaning installed_plugins.json..."
python3 -c "
import json, os
f = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
if os.path.exists(f):
    d = json.load(open(f))
    removed = d.get('plugins', {}).pop('duck-duck-duck@duck-duck-duck-marketplace', None)
    json.dump(d, open(f, 'w'), indent=2)
    print('  Removed' if removed else '  Already clean')
else:
    print('  File not found (ok)')
"

# 4. Remove duck from known_marketplaces.json
echo "[4/8] Cleaning known_marketplaces.json..."
python3 -c "
import json, os
f = os.path.expanduser('~/.claude/plugins/known_marketplaces.json')
if os.path.exists(f):
    d = json.load(open(f))
    removed = d.pop('duck-duck-duck-marketplace', None)
    json.dump(d, open(f, 'w'), indent=2)
    print('  Removed' if removed else '  Already clean')
else:
    print('  File not found (ok)')
"

# 5. Remove duck from settings.json (enabledPlugins + extraKnownMarketplaces)
echo "[5/8] Cleaning settings.json..."
python3 -c "
import json, os
f = os.path.expanduser('~/.claude/settings.json')
if os.path.exists(f):
    d = json.load(open(f))
    r1 = d.get('enabledPlugins', {}).pop('duck-duck-duck@duck-duck-duck-marketplace', None)
    r2 = d.get('extraKnownMarketplaces', {}).pop('duck-duck-duck-marketplace', None)
    json.dump(d, open(f, 'w'), indent=2)
    print('  Removed' if (r1 or r2) else '  Already clean')
else:
    print('  File not found (ok)')
"

# 6. Remove duck app data (logs, session state, API keys)
echo "[6/9] Removing app data..."
rm -rf ~/Library/Application\ Support/DuckDuckDuck/
echo "  Done"

# 7. Reset UserDefaults (eval provider, volume, mode, voice, etc.)
echo "[7/9] Resetting UserDefaults..."
defaults delete com.duckduckduck.widget 2>/dev/null && echo "  Done" || echo "  Already clean"

# 8. Remove from Applications
echo "[8/9] Removing from Applications..."
rm -rf /Applications/DuckDuckDuck.app
echo "  Done"

# 9. Verify clean state
echo "[9/9] Verifying..."
echo ""
CLEAN=true
if ls ~/.claude/plugins/cache/ 2>/dev/null | grep -q duck; then
    echo "  WARNING: Plugin cache still has duck files"
    CLEAN=false
fi
if grep -q "duck-duck-duck" ~/.claude/settings.json 2>/dev/null; then
    echo "  WARNING: settings.json still references duck"
    CLEAN=false
fi
if [ -d ~/Library/Application\ Support/DuckDuckDuck ]; then
    echo "  WARNING: App data still exists"
    CLEAN=false
fi
if [ -d /Applications/DuckDuckDuck.app ]; then
    echo "  WARNING: App still in Applications"
    CLEAN=false
fi

if $CLEAN; then
    echo "  All clean. Ready for fresh install."
else
    echo ""
    echo "  Some items remain — check warnings above."
fi
echo ""
echo "=== Done ==="
