echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit 
              -framework IOKit
              -framework AudioToolbox"

HANDMADE_RESOURCES_PATH="../handmade/resources/"

mkdir ../../build
pushd ../../build
clang -g $OSX_LD_FLAGS -o handmade "../handmade/code/osx_main.mm" 
rm -rf handmade.app
mkdir handmade.app
cp handmade handmade.app/handmade
cp ${HANDMADE_RESOURCES_PATH}Info.plist handmade.app/Info.plist
popd
