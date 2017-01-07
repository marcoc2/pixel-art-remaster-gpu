// simpleVBO.cpp (Rob Farber)

// includes, GL
#include <GL/glew.h>
#include <GL/gl.h>
#include <GL/glext.h>

// includes
#include <helper_cuda_gl.h>
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <rendercheck_gl.h>

#include "point.cu"

//#define USE_CUDA3

extern float animTime;

////////////////////////////////////////////////////////////////////////////////
// VBO specific code

#define CELL_SIZE 45
#define VBO_RENDER 88
#define VERTEX_RENDER 99

// constants
const unsigned int mesh_width = 128;
const unsigned int mesh_height = 128;
const unsigned int RestartIndex = 0xffffffff;

extern char* img_data;
extern int img_width;
extern int img_height;
extern int img_nchannels;
extern int img_widthstep;
extern char* graph;
extern char* videodata;

bool AA = true;
bool subdivide = false;

float scale = 8;
int counter = 0;

typedef struct
{
    GLuint vbo;
    GLuint typeSize;
    #ifdef USE_CUDA3
    struct cudaGraphicsResource* cudaResource;
    #else
    void* space;
    #endif
} mappedBuffer_t;

extern "C"
Point * launch_kernel( float2 * pos, uchar4 * colorPos,
                       float time, char* img_data, int img_width, int img_height,
                       int img_widthstep, int* polygonTCA, char* graph_h, bool subdivide );

// vbo variables
mappedBuffer_t vertexVBO = { NULL, sizeof( float2 ), NULL };
mappedBuffer_t colorVBO = { NULL, sizeof( uchar4 ), NULL };

// polygon triangles
Point* polygon_tri;
// triangle count array
int* polygonTCA;

////////////////////////////////////////////////////////////////////////////////
//! Create VBO
////////////////////////////////////////////////////////////////////////////////
//void createVBO(GLuint* vbo, unsigned int typeSize)
void createVBO( mappedBuffer_t* mbuf )
{
    // create buffer object
    glGenBuffers( 1, &( mbuf->vbo ) );
    glBindBuffer( GL_ARRAY_BUFFER, mbuf->vbo );

    // initialize buffer object
    unsigned int size = img_width * img_height * CELL_SIZE * mbuf->typeSize;

    glBufferData( GL_ARRAY_BUFFER, size, 0, GL_DYNAMIC_DRAW );

    glBindBuffer( GL_ARRAY_BUFFER, 0 );

    #ifdef USE_CUDA3
    cudaGraphicsGLRegisterBuffer( &( mbuf->cudaResource ), mbuf->vbo,
                                  cudaGraphicsMapFlagsNone );
    #else
    // register buffer object with CUDA
    cudaGLRegisterBufferObject( mbuf->vbo );
    #endif
}


//! Delete VBO
void deleteVBO( mappedBuffer_t* mbuf )
{
    glBindBuffer( 1, mbuf->vbo );
    glDeleteBuffers( 1, &( mbuf->vbo ) );

    #ifdef USE_CUDA3
    cudaGraphicsUnregisterResource( mbuf->cudaResource );
    mbuf->cudaResource = NULL;
    mbuf->vbo = NULL;
    #else
    cudaGLUnregisterBufferObject( mbuf->vbo );
    mbuf->vbo = NULL;
    #endif
}


void cleanupCuda()
{
    deleteVBO( &vertexVBO );
    deleteVBO( &colorVBO );
}


void createTCA()
{
    polygonTCA = ( int* )malloc( img_width * img_height * sizeof( int ) );
}


////////////////////////////////////////////////////////////////////////////////
//! Run the Cuda part of the computation
////////////////////////////////////////////////////////////////////////////////
void runCuda()
{
    // map OpenGL buffer object for writing from CUDA
    float2* dptr;
    uchar4* cptr;
    //uint* iptr;
    #ifdef USE_CUDA3
    size_t start;
    cudaGraphicsMapResources( 1, &vertexVBO.cudaResource, NULL );
    cudaGraphicsResourceGetMappedPointer( ( void** )&dptr, &start,
                                          vertexVBO.cudaResource );
    cudaGraphicsMapResources( 1, &colorVBO.cudaResource, NULL );
    cudaGraphicsResourceGetMappedPointer( ( void** )&cptr, &start,
                                          colorVBO.cudaResource );
    #else
    cudaGLMapBufferObject( ( void** )&dptr, vertexVBO.vbo );
    cudaGLMapBufferObject( ( void** )&cptr, colorVBO.vbo );
    #endif

    // execute the kernel
    polygon_tri = launch_kernel( dptr, cptr, animTime,
                                 img_data, img_width, img_height,
                                 img_widthstep, polygonTCA, graph, subdivide );
    //img_data = &videodata[img_height*img_widthstep*++counter];
    //sleep(0.001);

    // unmap buffer object
    cudaGLUnmapBufferObject( vertexVBO.vbo );
    cudaGLUnmapBufferObject( colorVBO.vbo );
}


void initCuda( int argc, char** argv )
{
    //if( cutCheckCmdLineFlag(argc, (const char**)argv, "device") )
    //{
    //    cutilGLDeviceInit(argc, argv);
    //}
    //else
    //{
    cudaGLSetGLDevice( 0 );     //gpuGetMaxGflopsDeviceId() );
    //}

    createVBO( &vertexVBO );
    createVBO( &colorVBO );
    // make certain the VBO gets cleaned up on program exit
    atexit( cleanupCuda );

    // Create Triangle Count Array
    createTCA();

    runCuda();
}


void renderCuda( int drawMode )
{
    glBindBuffer( GL_ARRAY_BUFFER, vertexVBO.vbo );
    glVertexPointer( 2, GL_FLOAT, 0, 0 );
    glEnableClientState( GL_VERTEX_ARRAY );

    glBindBuffer( GL_ARRAY_BUFFER, colorVBO.vbo );
    glColorPointer( 4, GL_UNSIGNED_BYTE, 0, 0 );
    glEnableClientState( GL_COLOR_ARRAY );

    glBindBuffer( GL_ARRAY_BUFFER, 0 );

    switch( drawMode )
    {
        case GL_LINE_STRIP:
            for( int i = 0; i < mesh_width * mesh_height; i += mesh_width )
            {
                glDrawArrays( GL_LINE_STRIP, i, mesh_width );
            }
            break;

        case GL_TRIANGLE_FAN:
        {
            static GLuint* qIndices = NULL;
            int size = 5 * ( mesh_width ) * ( mesh_height );

            if( qIndices == NULL ) // allocate and assign trianglefan indicies
            {
                qIndices = ( GLuint* ) malloc( size * sizeof( GLint ) );
                int index = 0;
                for( int i = 1; i < mesh_height; i++ )
                {
                    for( int j = 1; j < mesh_width; j++ )
                    {
                        qIndices[ index++ ] = ( i ) * mesh_width + j;
                        qIndices[ index++ ] = ( i ) * mesh_width + j - 1;
                        qIndices[ index++ ] = ( i - 1 ) * mesh_width + j - 1;
                        qIndices[ index++ ] = ( i - 1 ) * mesh_width + j;
                        qIndices[ index++ ] = RestartIndex;
                    }
                }
            }
            glPrimitiveRestartIndexNV( RestartIndex );
            glEnableClientState( GL_PRIMITIVE_RESTART_NV );
            glDrawElements( GL_TRIANGLE_FAN, size, GL_UNSIGNED_INT, qIndices );
            glDisableClientState( GL_PRIMITIVE_RESTART_NV );
        }
        break;

        /* Draw VBO Test */
        case VBO_RENDER:
        {
            if( AA )
            {
                glEnable( GL_MULTISAMPLE );
//            glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
//            glEnable (GL_BLEND);
//            glEnable (GL_POLYGON_SMOOTH);
//            glEnable (GL_DEPTH_TEST);
            }
            else
            {
                glDisable( GL_MULTISAMPLE );
//            glClear (GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
//            glDisable (GL_BLEND);
//            glDisable (GL_POLYGON_SMOOTH);
//            glEnable (GL_DEPTH_TEST);
            }

            int size = CELL_SIZE * ( img_width ) * ( img_height );


            glScalef( scale, scale, scale );

//        glBindBuffer(GL_ARRAY_BUFFER, vertexVBO.vbo);
//        glVertexAttribPointer(0, 2, GL_FLOAT, 0, NULL);

//        float2* vboContents = (float2*) glMapBuffer(GL_ARRAY_BUFFER, GL_READ_WRITE);

//        if(vboContents)
//        {
//            std::fstream out("/home/marco/Desktop/vbo.txt", std::ios_base::out);

//            out << "size: " << size << std::endl;

//            for(int i = 0; i < size; ++i)
//            {
//                out << std::fixed << i << " : " << vboContents[i].x  << " " << vboContents[i].y << std::endl;

//            }
//        }

//        glUnmapBuffer(GL_ARRAY_BUFFER);

            //glDrawElements(GL_TRIANGLES, size,  GL_UNSIGNED_SHORT, (void*)0);
            glDrawArrays( GL_TRIANGLES, 0, size );
            //printf("size: %d", size);
            //glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, (void*)0);
        }
        break;

        /* Draw Quads for each pixel */
        case GL_QUADS:
        {
            for( int i = 0; i < img_height; i++ )
            {
                for( int j = 0; j < img_width; j++ )
                {
                    int c_index = ( i * img_widthstep ) + ( j * img_nchannels );


                    for( int t = 0; t < 6; t = t + 3 )
                    {
                        glBegin( GL_TRIANGLES );

                        glColor3f( ( int )( unsigned char )img_data[ c_index + 2 ] / ( float )255,
                                   ( int )( unsigned char )img_data[ c_index + 1 ] / ( float )255,
                                   ( int )( unsigned char )img_data[ c_index + 0 ] / ( float )255 );


                        float offset = scale;
                        glVertex3f( j * offset, i * offset, 1.0f );
                        glVertex3f( j * offset, i * offset + offset, 1.0f );
                        glVertex3f( j * offset + offset, i * offset + offset, 1.0f );

                        glEnd();


                        glBegin( GL_TRIANGLES );

                        glColor3f( ( int )( unsigned char )img_data[ c_index + 2 ] / ( float )255,
                                   ( int )( unsigned char )img_data[ c_index + 1 ] / ( float )255,
                                   ( int )( unsigned char )img_data[ c_index + 0 ] / ( float )255 );


                        glVertex3f( j * offset + offset, i * offset + offset, 1.0f );
                        glVertex3f( j * offset + offset, i * offset, 1.0f );
                        glVertex3f( j * offset, i * offset, 1.0f );

                        glEnd();
                    }
                }
                //printf("\n");
            }
        }
        break;

        case VERTEX_RENDER:
        {
            //glBindBuffer(GL_ARRAY_BUFFER, vertexVBO.vbo);
            //float2* vboContents = (float2*) glMapBuffer(GL_ARRAY_BUFFER, GL_READ_ONLY);

//        for(int i = 0 ; i < 2 ; i++ )
//        {
//            for(int j = 0 ; j < 2 ; j++ )
//            {
//                int c_index = ((i*(img_width)) + j) * CELL_SIZE ;
//                printf("index: %d\n", c_index);
//                printf("edge count: %d\n", polygonTCA[ ((i*(img_width)) + j)]);
//                for(int t = 0 ; t < CELL_SIZE ; t++ )
//                {
//                    printf("vbo.x: %2.2f ", vboContents[c_index + t].x);
//                    printf("vbo.y: %2.2f \n", vboContents[c_index + t].y);
//                }
//            }
//        }

//        if (AA)
//        {
//            glEnable(GL_POLYGON_SMOOTH);
//            //glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);  // dont need on 480
//            glEnable(GL_BLEND);
//            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//            //glShadeModel(GL_POLYGON_SMOOTH);  // dont need on 480
//        } else
//        {
//            glDisable(GL_POLYGON_SMOOTH);
//            //glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);  // dont need on 480
//            glDisable(GL_BLEND);
//            printf("sem AA\n");
//            //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
//            //glShadeModel(GL_POLYGON_SMOOTH);  // dont need on 480
//        }

            for( int i = 0; i < img_height; i++ )
            {
                for( int j = 0; j < img_width; j++ )
                {
                    int c_index = ( i * img_widthstep ) + ( j * img_nchannels );
                    int e_index = ( i * ( img_width ) ) + j;

                    //if ((i == 6) && (j == 12))
                    //{
                    //printf("polygonTCA[ %d ]: %d\n", e_index, polygonTCA[e_index]);
                    //}

                    /* Polygon edge number minus two to get the number of triangle */
                    /* Number of triangles times 3 to get number of vertices */
                    for( int t = 0; t < ( ( polygonTCA[ e_index ] - 2 ) * 3 ); t = t + 3 )
                    //for (int t = 0; t < ( (4 - 2) * 3) ; t = t + 3)
                    {
                        int polygon_index = e_index * CELL_SIZE;

//                    if ((i == 2) && (j == 4))
//                    {
//                        printf("polygon_tri[ %d ] x: %2.2f y: %2.2f\n", (polygon_index + t  ), polygon_tri[(polygon_index + t)].x, polygon_tri[(polygon_index + t)].y);
//                        printf("polygon_tri[ %d ] x: %2.2f y: %2.2f\n", (polygon_index + t + 1), polygon_tri[(polygon_index + t) + 1].x, polygon_tri[(polygon_index + t + 1)].y );
//                        printf("polygon_tri[ %d ] x: %2.2f y: %2.2f\n", (polygon_index + t + 2), polygon_tri[(polygon_index + t) + 2].x, polygon_tri[(polygon_index + t + 2)].y);
//                    }


                        glBegin( GL_TRIANGLES );


                        glColor3f( ( int )( unsigned char )img_data[ c_index + 2 ] / ( float )255,
                                   ( int )( unsigned char )img_data[ c_index + 1 ] / ( float )255,
                                   ( int )( unsigned char )img_data[ c_index + 0 ] / ( float )255 );

//                    glVertex3f(polygon_tri[(polygon_index + t)    ].x*scale + (j*scale), polygon_tri[(polygon_index + t)    ].y*scale + (i*scale), 1.0f);    // lower left vertex
//                    glVertex3f(polygon_tri[(polygon_index + t) + 1].x*scale + (j*scale), polygon_tri[(polygon_index + t) + 1].y*scale + (i*scale), 1.0f);    // lower right vertex
//                    glVertex3f(polygon_tri[(polygon_index + t) + 2].x*scale + (j*scale), polygon_tri[(polygon_index + t) + 2].y*scale + (i*scale), 1.0f);    // upper vertex

                        glVertex3f( polygon_tri[ ( polygon_index + t ) ].x * scale,
                                    polygon_tri[ ( polygon_index + t ) ].y * scale, 1.0f );                                           // lower left vertex
                        glVertex3f( polygon_tri[ ( polygon_index + t ) + 1 ].x * scale,
                                    polygon_tri[ ( polygon_index + t ) + 1 ].y * scale, 1.0f );                                       // lower right vertex
                        glVertex3f( polygon_tri[ ( polygon_index + t ) + 2 ].x * scale,
                                    polygon_tri[ ( polygon_index + t ) + 2 ].y * scale, 1.0f );

                        glEnd();


//                    if ((i == 6) && (j == 12))
//                    {
//                        printf("(float)img_data[c_index    ]/255: %2.2f\n", (int)(unsigned char)img_data[c_index    ]/(float)255   );
//                    }
                    }
                }
                //printf("\n");
            }
        }
            glUnmapBuffer( GL_ARRAY_BUFFER );

        default:
            //glDrawArrays(GL_POINTS, 0, mesh_width * mesh_height);
            break;
    }

    glDisableClientState( GL_VERTEX_ARRAY );
    glDisableClientState( GL_COLOR_ARRAY );

    free( polygon_tri );
}


