#!/usr/bin/env bash
# scripts/version-management.sh
# Comprehensive version management for Rumble

set -euo pipefail

PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"
DATE=$(date +%Y-%m-%d)

usage() {
    echo "Usage: $0 <version> [message]"
    echo "Example: $0 0.20.1 \"feat: initial release\""
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

TARGET_VERSION=$1
MESSAGE=${2:-"release: $TARGET_VERSION"}

# 1. Validate version format (X.Y.Z)
if [[ ! "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in X.Y.Z format (e.g., 0.20.0). Found '$TARGET_VERSION'."
    exit 1
fi

# 2. Check branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: Releases can only be made from the 'main' branch (current: $CURRENT_BRANCH)."
    exit 1
fi

# 3. Parse current version and build number from pubspec.yaml
FULL_VERSION_LINE=$(grep "^version: " "$PUBSPEC")
CURRENT_FULL_VERSION=${FULL_VERSION_LINE#version: }
CURRENT_VERSION=${CURRENT_FULL_VERSION%+*}
CURRENT_BUILD=${CURRENT_FULL_VERSION#*+}

# 4. Compare versions
function version_to_int() {
    echo "$1" | awk -F. '{ printf("%d%03d%03d", $1,$2,$3); }'
}

if [ $(version_to_int "$TARGET_VERSION") -le $(version_to_int "$CURRENT_VERSION") ]; then
    echo "Error: New version $TARGET_VERSION must be greater than current version $CURRENT_VERSION."
    exit 1
fi

# 5. Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))
NEW_FULL_VERSION="$TARGET_VERSION+$NEW_BUILD"

echo "Releasing $NEW_FULL_VERSION (Old: $CURRENT_FULL_VERSION)..."

# 6. Update pubspec.yaml (Portable sed approach)
sed "s/^version: .*/version: $NEW_FULL_VERSION/" "$PUBSPEC" > "$PUBSPEC.tmp" && mv "$PUBSPEC.tmp" "$PUBSPEC"

# 7. Update CHANGELOG.md
if [ ! -f "$CHANGELOG" ]; then
    echo "# Changelog" > "$CHANGELOG"
    echo "" >> "$CHANGELOG"
fi

TEMP_CHANGELOG=$(mktemp)
echo "## [$TARGET_VERSION] - $DATE" > "$TEMP_CHANGELOG"
echo "- $MESSAGE" >> "$TEMP_CHANGELOG"
echo "" >> "$TEMP_CHANGELOG"

# Prepend after the header
if head -n 1 "$CHANGELOG" | grep -q "# Changelog"; then
    echo "# Changelog" > "$TEMP_CHANGELOG.final"
    echo "" >> "$TEMP_CHANGELOG.final"
    cat "$TEMP_CHANGELOG" >> "$TEMP_CHANGELOG.final"
    tail -n +2 "$CHANGELOG" | sed '1{/^$/d;}' >> "$TEMP_CHANGELOG.final"
    mv "$TEMP_CHANGELOG.final" "$CHANGELOG"
else
    cat "$CHANGELOG" >> "$TEMP_CHANGELOG"
    mv "$TEMP_CHANGELOG" "$CHANGELOG"
fi

# 8. Git Ops
if [ "${SKIP_GIT_OPS:-0}" != "1" ]; then
    git add "$PUBSPEC" "$CHANGELOG"
    git commit -m "chore: bump version to $NEW_FULL_VERSION"
    git tag "v$TARGET_VERSION"
    # shellcheck disable=SC2154
    git push origin main
    git push origin "v$TARGET_VERSION"
    echo "Successfully released $NEW_FULL_VERSION and pushed tag v$TARGET_VERSION."
fi
