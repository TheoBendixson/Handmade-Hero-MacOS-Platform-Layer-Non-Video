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

struct mac_replay_buffer
{
    char ReplayFileName[MAC_MAX_FILENAME_SIZE];
    void *MemoryBlock;
};

struct mac_state
{
    void *GameMemoryBlock;
    uint64 PermanentStorageSize;

    mac_replay_buffer ReplayBuffers[4];

    char AppFileName[MAC_MAX_FILENAME_SIZE];
    char *OnePastLastAppFileNameSlash;

    FILE *RecordingHandle;
    int InputRecordingIndex;

    FILE *PlaybackHandle;
	int InputPlayingIndex;

	char ResourcesDirectory[MAC_MAX_FILENAME_SIZE];
	int ResourcesDirectorySize;

};

struct mac_recorded_iput
{
    int InputCount;
    game_input *InputStream;
};

struct mac_game_code 
{
    void *GameCodeDLL;
    time_t DLLLastWriteTime;

    // IMPORTANT:   Either of these can be null. Check before using.
    game_update_and_render *UpdateAndRender;
    game_get_sound_samples *GetSoundSamples;

    bool32 IsValid;
};

