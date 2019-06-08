echo Building Handmade Hero

mkdir ../../build
pushd ../../build
clang -g -o handmade ../handmade/code/osx_main.mm
popd
