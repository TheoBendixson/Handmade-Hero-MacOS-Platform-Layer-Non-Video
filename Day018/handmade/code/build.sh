echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit 
              -framework IOKit
              -framework AudioToolbox"

HANDMADE_RESOURCES_PATH="../handmade/resources/"

HANDMADE_CODE_PATH="../handmade/cpp/code"

COMPILER_WARNING_FLAGS="-Werror -Weverything"

DISABLED_ERRORS="-Wno-gnu-anonymous-struct 
                 -Wno-nested-anon-types
                 -Wno-old-style-cast
                 -Wno-unused-macros
                 -Wno-padded
                 -Wno-unused-function
                 -Wno-missing-prototypes
                 -Wno-unused-parameter
                 -Wno-implicit-atomic-properties
                 -Wno-objc-missing-property-synthesis
                 -Wno-nullable-to-nonnull-conversion
                 -Wno-direct-ivar-access
                 -Wno-sign-conversion
                 -Wno-sign-compare
                 -Wno-double-promotion
                 -Wno-c++11-long-long"

mkdir ../../build
pushd ../../build
clang $COMPILER_WARNING_FLAGS $DISABLED_ERRORS -DHANDMADE_SLOW=1 -DHANDMADE_INTERNAL=1 -g $OSX_LD_FLAGS -o handmade ${HANDMADE_CODE_PATH}/"handmade.cpp" "../handmade/code/osx_main.mm" 
rm -rf handmade.app
mkdir handmade.app
cp handmade handmade.app/handmade
cp ${HANDMADE_RESOURCES_PATH}Info.plist handmade.app/Info.plist
popd
