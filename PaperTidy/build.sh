#!/bin/bash

APP_NAME="Paper Tidy"
BUILD_DIR="build"
SOURCES="Sources/PaperTidyApp.swift Sources/ContentView.swift Sources/PaperLogic.swift"

echo "Cleaning..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

echo "Compiling Swift sources..."
# Compile for the current architecture
swiftc $SOURCES \
    -o "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    -target $ARCH-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path)

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo "Creating Info.plist..."
cat <<EOF > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.PaperTidy</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Build complete! App located at $BUILD_DIR/$APP_NAME.app"
echo "You can run it with: open '$BUILD_DIR/$APP_NAME.app'"
