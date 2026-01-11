#!/bin/bash

APP_NAME="Paperenamer"
BUILD_DIR="build"
SOURCES="Sources/PaperenamerApp.swift Sources/ContentView.swift Sources/PaperLogic.swift"
ICON_SOURCE="icon_source.png"
ICONSET_DIR="Paperenamer.iconset"
ICON_FILE="AppIcon.icns"

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

if [ -f "$ICON_SOURCE" ]; then
    echo "Generating App Icon from $ICON_SOURCE..."
    mkdir -p "$ICONSET_DIR"
    
    # Generate standard icon sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

    echo "Converting to .icns..."
    iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/$APP_NAME.app/Contents/Resources/$ICON_FILE"
    
    # Clean up
    rm -rf "$ICONSET_DIR"
    echo "Icon set successfully."
else
    echo "No icon source found ($ICON_SOURCE), using default system icon."
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
    <string>com.example.Paperenamer</string>
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "Build complete! App located at $BUILD_DIR/$APP_NAME.app"
echo "You can run it with: open '$BUILD_DIR/$APP_NAME.app'"