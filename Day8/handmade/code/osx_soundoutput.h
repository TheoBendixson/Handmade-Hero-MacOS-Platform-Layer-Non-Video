struct MacOSSoundOutput {
    int samplesPerSecond; 
    uint32 bufferSize;
    int16* coreAudioBuffer;
    int16* readCursor;
    int16* writeCursor;
};
