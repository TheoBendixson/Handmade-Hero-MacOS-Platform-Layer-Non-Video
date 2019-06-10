// handmade.cpp
//
// Ted Bendixson 2019
//
#include <stdint.h>

struct game_offscreen_buffer {
    void *memory;
    int width;
    int height;
    int pitch;
};

static void gameUpdateAndRender(game_offscreen_buffer *buffer,
                                int blueOffset,
                                int greenOffset) {

    int width = buffer->width;
    int height = buffer->height;;

    uint8_t *row = (uint8_t *)buffer->memory;

    for ( int y = 0; y < height; ++y) {

        uint8_t *pixel = (uint8_t *)row;

        for(int x = 0; x < width; ++x) {
            
            /*  Pixel in memory: RR GG BB AA */

            //Red            
            *pixel = 0; 
            ++pixel;  

            //Green
            *pixel = (uint8_t)y+(uint8_t)greenOffset;;
            ++pixel;

            //Blue
            *pixel = (uint8_t)x+(uint8_t)blueOffset;
            ++pixel;

            //Alpha
            *pixel = 255;
            ++pixel;          
        }

        row += buffer->pitch;
    }
}

