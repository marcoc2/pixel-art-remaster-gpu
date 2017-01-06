// simplePBO.cpp (Rob Farber)

// includes, GL
#include "simplePBO.h"

#include <GL/glew.h>
#include <GL/gl.h>
#include <GL/glext.h>

// includes
#include <cuda_runtime.h>
#include <cutil_inline.h>
#include <cutil_gl_inline.h>
#include <cuda_gl_interop.h>
#include <rendercheck_gl.h>


/* Must be assign in the other module before use here */
extern char* img_data;
extern int img_width;
extern int img_height;


void createPBO(mappedBuffer_t* mbuf)
{

    // set up vertex data parameter
    int num_texels = img_width * img_height;
    int num_values = num_texels *  mbuf->typeSize;
    int size_tex_data = sizeof(GLubyte) * num_values;

    // Generate a buffer ID called a PBO (Pixel Buffer Object)
    glGenBuffers(1,&(mbuf->vbo));
    // Make this the current UNPACK buffer (OpenGL is state-based)
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, mbuf->vbo);
    // Allocate data for the buffer. 4-channel 8-bit image
    glBufferData(GL_PIXEL_UNPACK_BUFFER, size_tex_data, NULL, GL_DYNAMIC_COPY);

#ifdef USE_CUDA3
    cudaGraphicsGLRegisterBuffer( &(mbuf->cudaResource), mbuf->vbo,
                                  cudaGraphicsMapFlagsNone );
#else
    // register buffer object with CUDA
    cudaGLRegisterBufferObject(mbuf->vbo);
#endif
}

void createPBO_tex(mappedBuffer_t* mbuf, GLuint* textureID )
{

#ifdef USE_CUDA3
    // register Image (texture) to CUDA Resource
    cutilSafeCall(cudaGraphicsGLRegisterImage( mbuf->cudaResource, textureID, GL_TEXTURE_3D, cudaGraphicsRegisterFlagsReadOnly));

    // map CUDA resource
    cutilSafeCall(cudaGraphicsMapResources(1, &cuda_image_resource, 0));
#endif



}

void deletePBO(mappedBuffer_t* mbuf)
{
    if (&(mbuf->vbo)) {
        // unregister this buffer object with CUDA
        cudaGLUnregisterBufferObject(mbuf->vbo);

        glBindBuffer(GL_ARRAY_BUFFER, mbuf->vbo);
        glDeleteBuffers(1, &(mbuf->vbo));

        mbuf->vbo = NULL;
    }
}

void loadTexture(GLuint* textureID, unsigned int size_x, unsigned int size_y, char* img_data)
{
    // Enable Texturing
    glEnable(GL_TEXTURE_2D);

    // Generate a texture identifier
    glGenTextures(1,textureID);

    // Make this the current texture (remember that GL is state-based)
    glBindTexture( GL_TEXTURE_2D, *textureID);

    // Allocate the texture memory. The last parameter is NULL since we only
    // want to allocate memory, not initialize it
    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA8, img_width, img_height, 0,
                  GL_BGRA,GL_UNSIGNED_BYTE, img_data);

    // Must set the filter mode, GL_LINEAR enables interpolation when scaling
    //    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    //    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);

    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_RECTANGLE_ARB,GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_RECTANGLE_ARB,GL_NEAREST);

    // Note: GL_TEXTURE_RECTANGLE_ARB may be used instead of
    // GL_TEXTURE_2D for improved performance if linear interpolation is
    // not desired. Replace GL_LINEAR with GL_NEAREST in the
    // glTexParameteri() call

}

void createTexture(GLuint* textureID, unsigned int size_x, unsigned int size_y)
{
    // Enable Texturing
    glEnable(GL_TEXTURE_2D);

    // Generate a texture identifier
    glGenTextures(1,textureID);

    // Make this the current texture (remember that GL is state-based)
    glBindTexture( GL_TEXTURE_2D, *textureID);

    // Allocate the texture memory. The last parameter is NULL since we only
    // want to allocate memory, not initialize it
    glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA8, img_width, img_height, 0,
                  GL_BGRA,GL_UNSIGNED_BYTE, NULL);

    // Must set the filter mode, GL_LINEAR enables interpolation when scaling
    //    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    //    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);

    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_RECTANGLE_ARB,GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_RECTANGLE_ARB,GL_NEAREST);
    // Note: GL_TEXTURE_RECTANGLE_ARB may be used instead of
    // GL_TEXTURE_2D for improved performance if linear interpolation is
    // not desired. Replace GL_LINEAR with GL_NEAREST in the
    // glTexParameteri() call

}

void deleteTexture(GLuint* tex)
{
    glDeleteTextures(1, tex);

    *tex = NULL;
}


