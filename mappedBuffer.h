#ifndef MAPPEDBUFFER_H
#define MAPPEDBUFFER_H

typedef struct {
    GLuint vbo;
    GLuint typeSize;
#ifdef USE_CUDA3
    struct cudaGraphicsResource *cudaResource;
#else
    void* space;
#endif
} mappedBuffer_t;

#endif // MAPPEDBUFFER_H
