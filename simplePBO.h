#ifndef SIMPLEPBO_H
#define SIMPLEPBO_H

// simplePBO.cpp (Rob Farber)

// includes, GL
#include <GL/glew.h>
#include <GL/gl.h>
#include <GL/glext.h>

#include "mappedBuffer.h"

void createPBO(mappedBuffer_t* mbuf);

void createPBO_tex(mappedBuffer_t* mbuf, GLuint* textureID );

void deletePBO(mappedBuffer_t* mbuf);

void loadTexture(GLuint* textureID, unsigned int size_x, unsigned int size_y, char* img_data);

void createTexture(GLuint* textureID, unsigned int size_x, unsigned int size_y);

void deleteTexture(GLuint* tex);



#endif // SIMPLEPBO_H
