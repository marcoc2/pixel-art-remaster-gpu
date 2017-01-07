// includes, GL
#include <GL/glew.h>
#include "Image.h"

// includes
#include <helper_timer.h>
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>
#include <rendercheck_gl.h>

#include <fstream>
#include <iostream>

// The user must create the following routines:
void initCuda( int argc, char** argv );
void loadTexture();

// GLUT specific variables
const unsigned int window_width = 1200;
const unsigned int window_height = 800;

char* file_path;

int scale_graph = 20;

StopWatchInterface *timer = NULL;

Image* img = new Image();
Image* graph_img = new Image();
/* accessed externaly */
char* img_data;
int img_width;
int img_height;
int img_nchannels;
int img_widthstep;

char* graph;
char* videodata;

// Forward declaration of GL functionality
bool initGL( int argc, char** argv );

// Rendering callbacks
void fpsDisplay(), display();
void keyboard( unsigned char key, int x, int y );
void mouse( int button, int state, int x, int y );
void motion( int x, int y );


void load_image(char* f_path, int argc)
{
    if (argc > 1)
    {
        img->loadImage(f_path, CV_LOAD_IMAGE_COLOR );
    } else
    {
        img->loadImage("/local/msilva/Pictures/pixelart/emoji_1f44c_16-2x.png", CV_LOAD_IMAGE_COLOR );
    }
    img->reverses();
    img_data = img->getImageData();
    img_width = img->getWidth();
    img_height = img->getHeight();
    img_nchannels = img->getNchannels();
    img_widthstep = img->getWidthStep();


    //videodata = (char*)malloc(img->getHeight()*img->getWidthStep() * 2000);
    //
    //std::ifstream myfile;
    //myfile.open("/home/marco/Dropbox/Programação/Mestrado/Estudo Orientado/graph_cv_gl/video/rawvideo.bin", std::ios_base::binary);
    //myfile.seekg(40*img->getHeight()*img->getWidthStep());
    //myfile.read(videodata, img->getHeight()*img->getWidthStep() * 2000);
    //myfile.close();
    //img->copyByPixel(imgdata);
    //img->saveImage("/home/marco/Dropbox/Programação/Mestrado/Estudo Orientado/graph_cv_gl/video/teste.png");
}

/* Make a image representation of the graph */
void printToImage(char* graph, Image* src, Image* img_out)
{
//    graph_img = cvCreateImage( cvSize(img->width*scale_graph,img->height*scale_graph), IPL_DEPTH_8U, 3 );
//    cvSet( graph_img, bkgnd_color, 0 );

    int index;
    //int n_index;
    int n_j, n_i;
    int half_sg = scale_graph/2;

    for(int j = 0 ; j < src->getHeight() ; j++ )
    {
        for(int i = 0 ; i < src->getWidth() ; i++ )
        {
            index = (j*src->getWidth() + i);
            n_j = j*scale_graph + half_sg-1;
            n_i = i*scale_graph + half_sg-1;
            //if ((index > 0) && (index < (graph_img->width*graph_img->height)-1)) {
                if CHECK_BIT(graph[index], 0) {
                    //cvCircle( graph_img, cvPoint(((j+1)*10),((i+1)*10)), 1, CV_RGB( 0, 0, 0 ), CV_FILLED, 8, 0 );
                    cvLine( img_out->getImg(), cvPoint(n_i-half_sg,n_j+half_sg),
                            cvPoint(n_i,n_j), CV_RGB( 0, 0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 1)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i,n_j+half_sg),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 2)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i+half_sg,n_j+half_sg),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 3)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i-half_sg,n_j),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 4)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i+half_sg,n_j),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 5)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i-half_sg,n_j-half_sg),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 6)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i,n_j-half_sg),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
                if CHECK_BIT(graph[index], 7)
                {
                    cvLine( img_out->getImg(), cvPoint(n_i+half_sg,n_j-half_sg),
                            cvPoint(n_i,n_j), CV_RGB( 0,  0, 0 ), 1, CV_AA, 0 );
                }
        }
    }
}

void allocate_graph()
{
    graph = (char*)malloc(img_width*img_height*sizeof(char));
    graph_img->createImage(img->getWidth()*scale_graph, img->getHeight()*scale_graph, IPL_DEPTH_8U, 3);

    //std::ifstream myfile;
    //myfile.open("/home/marco/Dropbox/Programação/Mestrado/Dissertação/debug_spline_extraction-build-desktop-Qt_4_8_1_in_PATH__System__Debug/graph.txt", std::ios_base::binary);
    //myfile.read(graph, img->getWidth()*img->getHeight());
    //myfile.close();
}

void display_graph()
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    graph_img->setAllPixels(255,255,255);
    printToImage(graph, img, graph_img);
    //graph_img->reverses();

    glDrawPixels(graph_img->getWidth(), graph_img->getHeight(), GL_BGR_EXT, GL_UNSIGNED_BYTE, (uchar*) graph_img->getImageData());
    //glDrawPixels(img->getWidth(), img->getHeight(), GL_BGR_EXT, GL_UNSIGNED_BYTE, (uchar*) img->getImageData());

    glutSwapBuffers();
}

// Main program
int main( int argc, char** argv )
{
    // Create the CUTIL timer
    sdkCreateTimer( &timer );
    sdkResetTimer( &timer );

    file_path = argv[ 1 ];
    load_image( file_path, argc );
    allocate_graph();

    initGL( argc, argv );

    initCuda( argc, argv );

    // register callbacks
    glutDisplayFunc( fpsDisplay );
    glutKeyboardFunc( keyboard );
    glutMouseFunc( mouse );
    glutMotionFunc( motion );

    //glutDisplayFunc( display );

    // start rendering mainloop
    glutMainLoop();

    // clean up
    cudaThreadExit();
    //cutilExit(argc, argv);
}

// Simple method to display the Frames Per Second in the window title
void computeFPS()
{
    static int fpsCount=0;
    static int fpsLimit=100;

    fpsCount++;

    if (fpsCount == fpsLimit)
    {
        char fps[256];
        float ifps = 1.f / ( timer->getAverageTime() / 1000.f);
        sprintf(fps, "Cuda GL Interop Wrapper: %3.1f fps ", ifps);

        glutSetWindowTitle(fps);
        fpsCount = 0;

        sdkResetTimer( &timer );;
    }
}

void fpsDisplay()
{
    sdkStartTimer( &timer );

    display();

    sdkStopTimer( &timer );
    computeFPS();
}

float animTime = 0.0;    // time the animation has been running

// Initialize OpenGL window
bool initGL( int argc, char **argv )
{
    glutInit( &argc, argv );
    glutInitDisplayMode( GLUT_RGBA | GLUT_DOUBLE | GLUT_MULTISAMPLE );
    glutInitWindowSize( window_width, window_height );
    glutCreateWindow( "Output" );
    glutKeyboardFunc( keyboard );
    glutMotionFunc( motion );

    //### Segunda Janela (Graph) ###
//    glutInitWindowSize(img->getWidth()*scale_graph, img->getWidth()*scale_graph);
//    glutInitWindowPosition(600,200);
//    /* Usar caso precise de redisplay */
//    //janID = glutCreateWindow("Diagrama de Voronoi");
//    glutCreateWindow("Graph");
//    glutInitDisplayMode(GLUT_RGB | GLUT_DOUBLE | GLUT_DEPTH);
//    glutDisplayFunc(display_graph);
    //glutIdleFunc(idle);
    //######################

    // initialize necessary OpenGL extensions
    glewInit();
    if( !glewIsSupported( "GL_VERSION_2_0 " ) )
    {
        fprintf( stderr, "ERROR: Support for necessary OpenGL extensions missing." );
        fflush( stderr );
        return false;
    }

    // default initialization
    glClearColor( 0.0, 0.0, 0.0, 1.0 );
    glDisable( GL_DEPTH_TEST );

    // viewport
    glViewport( -window_height, 0, window_width, 0 );

    // set view matrix
    glMatrixMode( GL_MODELVIEW );
    glLoadIdentity();

    // projection
    glMatrixMode( GL_PROJECTION );
    glLoadIdentity();

//    gluPerspective(60.0, (GLfloat)window_width / (GLfloat) window_height,
//                   0.10, 10.0);
    glOrtho(0, (GLfloat)window_width, 0.0f, (GLfloat)window_height, -1000.0f, 1000.0f);


    return false;
}
