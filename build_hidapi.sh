#!/bin/bash
set -e
cd lib/hidapi/

# hidapi's CMakeLists.txt declares an ancient cmake minimum that newer
# cmake (>= 4) refuses; allow it to configure anyway.
CMAKE_POLICY_FLAG="-DCMAKE_POLICY_VERSION_MINIMUM=3.5"

rm -rf build build_x86
mkdir -p build
cd build
cmake .. -DBUILD_SHARED_LIBS=false $CMAKE_POLICY_FLAG
make

cd ..
mkdir -p build_x86
cd build_x86
cmake .. -DBUILD_SHARED_LIBS=false $CMAKE_POLICY_FLAG -DCMAKE_C_FLAGS="-target x86_64-apple-macos11 -arch x86_64" -DCMAKE_EXE_LINKER_FLAGS="-target x86_64-apple-macos11"
make

