#!/bin/bash
cd lib/hidapi/

mkdir -p build
cd build
cmake .. -DBUILD_SHARED_LIBS=false
make

cd ..
mkdir -p build_x86
cd build_x86
cmake .. -DBUILD_SHARED_LIBS=false -DCMAKE_C_FLAGS="-target x86_64-apple-macos10.15 -arch x86_64" -DCMAKE_EXE_LINKER_FLAGS="-target x86_64-apple-macos10.15"
make

