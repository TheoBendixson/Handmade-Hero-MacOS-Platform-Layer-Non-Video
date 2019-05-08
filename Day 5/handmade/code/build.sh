echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit"

HANDMADE_CODE_PATH="../handmade/code/"

OSX_TARGET_INCLUDES="${HANDMADE_CODE_PATH}osx_main.mm 
                     ${HANDMADE_CODE_PATH}osx_handmade_windows.mm"

mkdir ../../build
pushd ../../build
clang -g $OSX_LD_FLAGS -o handmade $OSX_TARGET_INCLUDES 
popd
