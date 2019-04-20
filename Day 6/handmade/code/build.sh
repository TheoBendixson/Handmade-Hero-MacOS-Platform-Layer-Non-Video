echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit -framework IOKit"

HANDMADE_CODE_PATH="../handmade/code/"

OSX_TARGET_INCLUDES="${HANDMADE_CODE_PATH}osx_main.mm 
                     ${HANDMADE_CODE_PATH}osx_handmade_main_window_delegate.mm
                     ${HANDMADE_CODE_PATH}osx_handmade_controllers.m"

mkdir ../../build
pushd ../../build
clang -g $OSX_LD_FLAGS -o handmade $OSX_TARGET_INCLUDES 
cp handmade handmade.app
popd
