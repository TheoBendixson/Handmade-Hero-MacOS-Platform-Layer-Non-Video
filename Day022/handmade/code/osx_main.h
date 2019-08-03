// OSX Main.h
// Handmade Hero Mac Port
// by Ted Bendixson
//

#include "../cpp/code/handmade.h"

#define MAC_MAX_FILENAME_SIZE 4096

struct mac_sound_output 
{
    uint32 SamplesPerSecond; 
    uint32 BytesPerSample;
    uint32 RunningSampleIndex;
    uint32 BufferSize;
    uint32 SafetyBytes;
    uint32 WriteCursor;
    uint32 PlayCursor;
    void *Data;
};

struct mac_debug_time_marker 
{
    uint32 OutputPlayCursor;
    uint32 OutputWriteCursor;
    uint32 OutputLocation;
    uint32 OutputByteCount;
    uint32 ExpectedFlipPlayCursor;
    uint32 FlipWriteCursor;
    uint32 FlipPlayCursor;
};

struct mac_state
{
    char AppFileName[MAC_MAX_FILENAME_SIZE];
    char *OnePastLastAppFileNameSlash;

    // TODO: (ted)  Still not sure if FILE* is what we want
    FILE *RecordingHandle;
    int InputRecordingIndex = 0;

    FILE *PlaybackHandle;
    int InputPlayingIndex = 0;
};

struct mac_game_code 
{
    void *GameCodeDLL;
    time_t DLLLastWriteTime;

    game_update_and_render *UpdateAndRender;
    game_get_sound_samples *GetSoundSamples;

    bool32 IsValid;
};

struct mac_recorded_iput
{
    int InputCount;
    game_input *InputStream;
};
