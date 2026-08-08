#!/bin/bash
# Build script for LeakSexTape Flutter App
# Run this script to build the APK

set -e

echo "=== LeakSexTape App Build Script ==="

# Configuration
FLUTTER_DIR="${FLUTTER_DIR:-/home/z/flutter}"
ANDROID_SDK="${ANDROID_HOME:-/home/z/android-sdk}"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

export PATH="$FLUTTER_DIR/bin:$PATH"
export ANDROID_HOME="$ANDROID_SDK"
export GRADLE_OPTS="-Xmx4g -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8"

echo "Flutter: $(flutter --version 2>&1 | head -1)"
echo "Project: $PROJECT_DIR"
echo "Android SDK: $ANDROID_SDK"

cd "$PROJECT_DIR"

# Clean previous builds
echo "[1/5] Cleaning previous builds..."
flutter clean

# Get dependencies
echo "[2/5] Getting dependencies..."
flutter pub get

# Run code analysis (optional)
echo "[3/5] Running analysis..."
flutter analyze || echo "Analysis completed with warnings"

# Build type selection
BUILD_TYPE="${1:-debug}"

if [ "$BUILD_TYPE" = "release" ]; then
    echo "[4/5] Building RELEASE APK..."
    flutter build apk --release \
        --shrink \
        --obfuscate \
        --split-debug-info=build/debug-info
else
    echo "[4/5] Building DEBUG APK..."
    flutter build apk --debug
fi

# Output results
echo "[5/5] Build complete!"
echo ""
echo "APK Location:"
find build -name "*.apk" -type f 2>/dev/null | head -5
echo ""
echo "=== Build Successful ==="
