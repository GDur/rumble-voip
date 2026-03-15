#!/bin/bash

# This script recreates all app icons and splash screens from assets/icon.png
# It uses the flutter_launcher_icons and flutter_native_splash packages.

echo "🚀 Generating launcher icons..."
dart run flutter_launcher_icons

echo "✨ Generating native splash screens..."
dart run flutter_native_splash:create

echo "✅ All branding assets updated!"
