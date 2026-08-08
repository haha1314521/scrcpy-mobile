#!/bin/bash

# Src root
SOURCE_ROOT=$(cd $(dirname $0)/../.. && pwd);

# Setup iphone deploy target
DEPLOYMENT_TARGET=13.0;
CMAKE_TOOLCHAIN_FILE=$SOURCE_ROOT/ios-cmake/ios.toolchain.cmake;
PLATFORM=$(echo "$target" | cut -d: -f2);
FULL_OUTPUT="$(cd "$output_dir" && pwd)/$(echo "$target" | cut -d: -f1)";
echo " - CMake Toolchain: $CMAKE_TOOLCHAIN_FILE";
echo " - CMake PLATFORM: $PLATFORM";
echo " - Full Output: $FULL_OUTPUT";

[[ -d $FULL_OUTPUT ]] || mkdir -pv "$FULL_OUTPUT";

cmake_root=./cmake/out;

# Clean built products
[[ -d "$cmake_root" ]] && rm -rfv "$cmake_root";
mkdir -pv "$cmake_root";

cd "$cmake_root" || exit;

cmake .. -G Xcode -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TOOLCHAIN_FILE" -DPLATFORM="$PLATFORM" \
	-DDEPLOYMENT_TARGET=$DEPLOYMENT_TARGET;
cmake --build . --config Debug --target scrcpy --parallel 8;
find . -name "*.a" -exec cp -av {} "$FULL_OUTPUT" \;
