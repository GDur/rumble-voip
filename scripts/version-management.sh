#!/bin/bash
# scripts/version-management.sh

TYPE=$1
MESSAGE=$2

if [ -z "$TYPE" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <minor|patch> <message>"
    exit 1
fi

PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"
DATE=$(date +%Y-%m-%d)

# Extract version line from pubspec.yaml
VERSION_LINE=$(grep "^version:" $PUBSPEC)
# Format: version: x.y.z+n
VERSION=$(echo $VERSION_LINE | cut -d' ' -f2)

# Parse version
# x.y.z+n
BASE_VERSION=$(echo $VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $VERSION | cut -d'+' -f2)

MAJOR=$(echo $BASE_VERSION | cut -d'.' -f1)
MINOR=$(echo $BASE_VERSION | cut -d'.' -f2)
PATCH=$(echo $BASE_VERSION | cut -d'.' -f3)

if [ "$TYPE" == "minor" ]; then
    MINOR=$((MINOR + 1))
    PATCH=0
elif [ "$TYPE" == "patch" ]; then
    PATCH=$((PATCH + 1))
else
    echo "Unknown bump type: $TYPE"
    exit 1
fi

BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD_NUMBER"

# Update pubspec.yaml
# macOS sed requires -i ''
sed -i '' "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC

# Create CHANGELOG.md if it doesn't exist
if [ ! -f "$CHANGELOG" ]; then
    echo "# Changelog" > "$CHANGELOG"
    echo "" >> "$CHANGELOG"
fi

# Prepend to CHANGELOG.md
# We'll create a temp file and then move it back
TEMP_CHANGELOG=$(mktemp)
echo "## [$MAJOR.$MINOR.$PATCH] - $DATE" > $TEMP_CHANGELOG
echo "- $MESSAGE" >> $TEMP_CHANGELOG
echo "" >> $TEMP_CHANGELOG
# Skip the first line if it's "# Changelog" to keep it at the top
if head -n 1 "$CHANGELOG" | grep -q "# Changelog"; then
    echo "# Changelog" > $TEMP_CHANGELOG.final
    echo "" >> $TEMP_CHANGELOG.final
    cat $TEMP_CHANGELOG >> $TEMP_CHANGELOG.final
    tail -n +2 "$CHANGELOG" | sed '1{/^$/d;}' >> $TEMP_CHANGELOG.final
    mv $TEMP_CHANGELOG.final "$CHANGELOG"
else
    cat "$CHANGELOG" >> $TEMP_CHANGELOG
    mv $TEMP_CHANGELOG "$CHANGELOG"
fi

echo "Version bumped to $NEW_VERSION"
