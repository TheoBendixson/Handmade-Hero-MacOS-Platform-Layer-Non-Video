echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit 
              -framework IOKit
              -framework AudioToolbox"

HANDMADE_RESOURCES_PATH="../handmade/resources/"

HANDMADE_CODE_PATH="../handmade/cpp/code"

mkdir ../../build
pushd ../../build
clang -DHANDMADE_SLOW=1 -DHANDMADE_INTERNAL=1 -g $OSX_LD_FLAGS -o handmade ${HANDMADE_CODE_PATH}/"handmade.cpp" "../handmade/code/osx_main.mm" 
rm -rf handmade.app
mkdir handmade.app
cp handmade handmade.app/handmade
cp ${HANDMADE_RESOURCES_PATH}Info.plist handmade.app/Info.plist
popd
