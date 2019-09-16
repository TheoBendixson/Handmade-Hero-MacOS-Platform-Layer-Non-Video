echo Building Handmade Hero

OSX_LD_FLAGS="-framework AppKit 
              -framework IOKit
              -framework QuartzCore 
              -framework AudioToolbox"

HANDMADE_RESOURCES_PATH="../handmade/resources"

HANDMADE_CODE_PATH="../handmade/cpp/code"

COMPILER_WARNING_FLAGS="-Werror -Weverything"

DISABLED_ERRORS="-Wno-gnu-anonymous-struct 
                 -Wno-c++11-compat-deprecated-writable-strings                
                 -Wno-pedantic
                 -Wno-unused-variable
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
                 -Wno-tautological-compare
                 -Wno-c++11-long-long
                 -Wno-cast-align"

COMMON_COMPILER_FLAGS="$COMPILER_WARNING_FLAGS
                       $DISABLED_ERRORS
                       -DHANDMADE_SLOW=1
                       -DHANDMADE_INTERNAL=1
                       $OSX_LD_FLAGS"

mkdir ../../build
pushd ../../build
clang -g -o GameCode.dylib ${COMMON_COMPILER_FLAGS} -dynamiclib ../handmade/cpp/code/handmade.cpp 
clang -g ${COMMON_COMPILER_FLAGS} -o handmade "../handmade/code/osx_main.mm" 
rm -rf handmade.app
mkdir -p handmade.app/Contents/Resources
cp handmade handmade.app/handmade
cp GameCode.dylib handmade.app/Contents/Resources/GameCode.dylib
cp -r GameCode.dylib.dSYM handmade.app/Contents/Resources/GameCode.dylib.dSYM
cp "${HANDMADE_RESOURCES_PATH}/Info.plist" handmade.app/Info.plist
cp -r "${HANDMADE_RESOURCES_PATH}/test/" handmade.app/Contents/Resources/
popd
