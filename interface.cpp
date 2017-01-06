// includes, GL
#include <GL/glew.h>
#include <GL/gl.h>
#include <GL/glext.h>

#include "simpleVBO.h"
#include "simplePBO.h"

// includes
#include <cuda_runtime.h>
#include <cutil_inline.h>
#include <cutil_gl_inline.h>
#include <cuda_gl_interop.h>
#include <rendercheck_gl.h>

extern float animTime;

extern char* img_data;
extern int img_width;
extern int img_height;
extern int img_nchannels;

GLuint textureID=NULL;

const unsigned int mesh_width = 128;
const unsigned int mesh_height = 128;
const unsigned int RestartIndex = 0xffffffff;

extern "C"
void launch_kernel(float4* pos, uchar4* posColor,
                   unsigned int img_width, unsigned int img_height, float time, char* img_data);

// vbo variables
mappedBuffer_t vertexVBO = {NULL, sizeof(float4), NULL};
mappedBuffer_t colorPBO =  {NULL, sizeof(uchar4), NULL};

////////////////////////////////////////////////////////////////////////////////
//! Run the Cuda part of the computation
////////////////////////////////////////////////////////////////////////////////
void runCuda()
{
    // map OpenGL buffer object for writing from CUDA
    float4 *dptr;
    uchar4 *cptr;
    uint *iptr;
#ifdef USE_CUDA3
    size_t start;
    cudaGraphicsMapResources( 1, &vertexVBO.cudaResource, NULL );
    cudaGraphicsResourceGetMappedPointer( ( void ** )&dptr, &start,
                                          vertexVBO.cudaResource );
    cudaGraphicsMapResources( 1, &colorVBO.cudaResource, NULL );
    cudaGraphicsResourceGetMappedPointer( ( void ** )&cptr, &start,
                                          colorVBO.cudaResource );
#else
    cudaGLMapBufferObject((void**)&dptr, vertexVBO.vbo);
    cudaGLMapBufferObject((void**)&cptr, colorPBO.vbo);
#endif

    // execute the kernel
    launch_kernel(dptr, cptr, mesh_width, mesh_height, animTime, img_data);

    // unmap buffer object
#ifdef USE_CUDA3
    cudaGraphicsUnmapResources( 1, &vertexVBO.cudaResource, NULL );
    cudaGraphicsUnmapResources( 1, &colorVBO.cudaResource, NULL );
#else
    cudaGLUnmapBufferObject(vertexVBO.vbo);
    cudaGLUnmapBufferObject(colorPBO.vbo);
#endif
}

void cleanupCuda()
{
    deleteVBO(&vertexVBO);
    deleteVBO(&colorPBO);
    //deleteTexture(&textureID);
}

void initCuda(int argc, char** argv)
{
    // First initialize OpenGL context, so we can properly set the GL
    // for CUDA.  NVIDIA notes this is necessary in order to achieve
    // optimal performance with OpenGL/CUDA interop.  use command-line
    // specified CUDA device, otherwise use device with highest Gflops/s
    if( cutCheckCmdLineFlag(argc, (const char**)argv, "device") ) {
        cutilGLDeviceInit(argc, argv);
    } else {
        cudaGLSetGLDevice( cutGetMaxGflopsDeviceId() );
    }

    createVBO(&vertexVBO);
    //loadTexture(&textureID, img_width, img_height, img_data);
    //createTexture(&textureID, img_width, img_height);

    //createPBO_tex(&colorPBO, &textureID);
    createVBO(&colorPBO);
    // make certain the VBO gets cleaned up on program exit
    atexit(cleanupCuda);

    runCuda();

}


void renderCuda(int drawMode)
{
    /* Render on a quad if there is no VBO */
    if (vertexVBO.vbo){
        glBindBuffer(GL_ARRAY_BUFFER, vertexVBO.vbo);
        glVertexPointer(4, GL_FLOAT, 0, 0);
        glEnableClientState(GL_VERTEX_ARRAY);

        glBindBuffer(GL_ARRAY_BUFFER, colorPBO.vbo);
        glColorPointer(4, GL_UNSIGNED_BYTE, 0, 0);
        glEnableClientState(GL_COLOR_ARRAY);

        switch(drawMode) {
        case GL_LINE_STRIP:
            for(int i=0 ; i < mesh_width*mesh_height; i+= mesh_width)
                glDrawArrays(GL_LINE_STRIP, i, mesh_width);
            break;
        case GL_TRIANGLE_FAN: {
            static GLuint* qIndices=NULL;
            int size = 5*(mesh_height-1)*(mesh_width-1);

            if(qIndices == NULL) { // allocate and assign trianglefan indicies
                qIndices = (GLuint *) malloc(size*sizeof(GLint));
                int index=0;
                for(int i=1; i < mesh_height; i++) {
                    for(int j=1; j < mesh_width; j++) {
                        qIndices[index++] = (i)*mesh_width + j;
                        qIndices[index++] = (i)*mesh_width + j-1;
                        qIndices[index++] = (i-1)*mesh_width + j-1;
                        qIndices[index++] = (i-1)*mesh_width + j;
                        qIndices[index++] = RestartIndex;
                    }
                }
            }
            glPrimitiveRestartIndexNV(RestartIndex);
            glEnableClientState(GL_PRIMITIVE_RESTART_NV);
            glDrawElements(GL_TRIANGLE_FAN, size, GL_UNSIGNED_INT, qIndices);
            glDisableClientState(GL_PRIMITIVE_RESTART_NV);
        } break;
        default:
            glDrawArrays(GL_POINTS, 0, mesh_width * mesh_height);
            break;
        }

        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
    } else {
        // Create a texture from the buffer
        glBindBuffer( GL_PIXEL_UNPACK_BUFFER, colorPBO.vbo);

        // bind texture from PBO
        glBindTexture(GL_TEXTURE_2D, textureID);


        // Note: glTexSubImage2D will perform a format conversion if the
        // buffer is a different format from the texture. We created the
        // texture with format GL_RGBA8. In glTexSubImage2D we specified
        // GL_BGRA and GL_UNSIGNED_INT. This is a fast-path combination

        // Note: NULL indicates the data resides in device memory
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, img_width, img_height,
                        GL_RGBA, GL_UNSIGNED_BYTE, NULL);


        // Draw a single Quad with texture coordinates for each vertex.

        glBegin(GL_QUADS);
        glTexCoord2f(0.0f,1.0f); glVertex3f(0.0f,0.0f,0.0f);
        glTexCoord2f(0.0f,0.0f); glVertex3f(0.0f,1.0f,0.0f);
        glTexCoord2f(1.0f,0.0f); glVertex3f(1.0f,1.0f,0.0f);
        glTexCoord2f(1.0f,1.0f); glVertex3f(1.0f,0.0f,0.0f);
        glEnd();

    }
}
