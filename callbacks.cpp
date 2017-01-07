//callbacksVBO.cpp (Rob Farber)
// includes, GL
#include <GL/glew.h>

// includes
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <rendercheck_gl.h>

extern float animTime;
extern float scale;
extern bool AA;
extern bool subdivide;

#define VBO_RENDER 88
#define VERTEX_RENDER 99

// The user must create the following routines:
void initCuda( int argc, char** argv );
void runCuda();
void renderCuda( int );

// Callbacks

int drawMode = VBO_RENDER; // the default draw mode

// mouse controls
int mouse_old_x, mouse_old_y;
int mouse_buttons = 0;
float rotate_x = 0.0, rotate_y = 0.0;
float translate_z = -3.0;
float translate_x = 1;
float translate_y = 1;
int antialiasing = 8;

//! Display callback for GLUT
//! Keyboard events handler for GLUT
//! Display callback for GLUT
void display( void )
{
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    //glClear(GL_ACCUM_BUFFER_BIT);

    // set view matrix
    glMatrixMode( GL_MODELVIEW );
    glLoadIdentity();
    glTranslatef( translate_x, translate_y, translate_z );
    glRotatef( rotate_x, 1.0, 0.0, 0.0 );
    glRotatef( rotate_y, 0.0, 1.0, 0.0 );

    //float mat[ 16 ] = {
    //    1.0, 0.0, 0.0, 0.0,
    //    0.0, -1.0, 0.0, 0.0,
    //    0.0, 0.0, 0.0, 0.0,
    //    0.0, 0.0, 0.0, 1.0
    //};

    //glTranslatef(0.0,224*scale,0.0);
    //glMultMatrixf(mat);

    // run CUDA kernel to generate vertex positions
    runCuda();

    // render the data
    renderCuda( drawMode );
    //renderCuda(88);

    glutSwapBuffers();
    glutPostRedisplay();

    animTime += 0.005;
}


//! Keyboard events handler for GLUT
void keyboard( unsigned char key, int x, int y )
{
    switch( key )
    {
        case ( 27 ):
            exit( 0 );
            break;

        case 'o':
            drawMode = VERTEX_RENDER;
            break;

        case 'p':
            drawMode = VBO_RENDER;
            break;

        case 'q':
            drawMode = GL_QUADS;
            break;

        case 'a':
        {
            if( AA == true )
            {
                AA = false;
            }
            else
            {
                AA = true;
            }
        }
        break;

        case 's':
        {
            if( subdivide == true )
            {
                subdivide = false;
            }
            else
            {
                subdivide = true;
            }
        }
        break;

        case 'd':
        case 'D':
            switch( drawMode )
            {
                case GL_POINTS:
                    drawMode = GL_LINE_STRIP;
                    break;

                case GL_LINE_STRIP:
                    drawMode = GL_TRIANGLE_FAN;
                    break;

                case GL_TRIANGLE_FAN:
                    drawMode = GL_TRIANGLES;
                    break;

                default:
                    drawMode = GL_POINTS;
            }
            break;
    }
    glutPostRedisplay();
}


// Mouse event handlers for GLUT
void mouse( int button, int state, int x, int y )
{
    if( state == GLUT_DOWN )
    {
        mouse_buttons |= 1 << button;
    }
    else if( state == GLUT_UP )
    {
        mouse_buttons = 0;
    }

    /* Scrool Wheel*/
    if( ( button == 4 ) && ( state == 1 ) )
    {
        scale -= 0.5;
    }
    else if( ( button == 3 ) && ( state == 1 ) )
    {
        scale += 0.5;
    }

    printf( "state: %d\n", state );
    printf( "button: %d\n", button );

    mouse_old_x = x;
    mouse_old_y = y;
    glutPostRedisplay();
}


void motion( int x, int y )
{
    float dx, dy;
    dx = x - mouse_old_x;
    dy = y - mouse_old_y;

    if( mouse_buttons & 1 )
    {
        rotate_x += dy * 0.2;
        rotate_y += dx * 0.2;
    }
    else if( mouse_buttons & 4 )
    {
        translate_z += dy * 0.01;
        translate_x += dx * 0.6;
        translate_y -= dy * 0.6;
    }
    else if( mouse_buttons & 2 )
    {
        scale += dy * 0.01;
    }

    mouse_old_x = x;
    mouse_old_y = y;
}


