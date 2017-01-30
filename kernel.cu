#include <stdio.h>
#include <iostream>
#include <assert.h>
#include <helper_timer.h>

#include "point.cu"

#define CELL_SIZE 45

#include "graph_functions.cu"
#include "diagram_functions.cu"
#include "triangulate_functions.cu"
#include "subdivision_functions.cu"

//#define PIXEL( i, j, widthstep, n_channels ) ( ( j * ( widthstep ) ) + ( i * n_channels ) )

#define N_CHANNELS 3

#define CUDA_ERROR_CHECK

#define CudaSafeCall( err ) __cudaSafeCall( err, __FILE__, __LINE__ )
#define CudaCheckError() __cudaCheckError( __FILE__, __LINE__ )

inline void __cudaSafeCall( cudaError err, const char* file, const int line )
{
    #ifdef CUDA_ERROR_CHECK
    if( cudaSuccess != err )
    {
        fprintf( stderr, "cudaSafeCall() failed at %s:%i : %s\n",
                 file, line, cudaGetErrorString( err ) );
        exit( -1 );
    }
    #endif

    return;
}


inline void __cudaCheckError( const char* file, const int line )
{
    #ifdef CUDA_ERROR_CHECK
    cudaError err = cudaGetLastError();
    if( cudaSuccess != err )
    {
        fprintf( stderr, "cudaCheckError() failed at %s:%i : %s\n",
                 file, line, cudaGetErrorString( err ) );
        exit( -1 );
    }

    // More careful checking. However, this will affect performance.
    // Comment away if needed.
    err = cudaDeviceSynchronize();
    if( cudaSuccess != err )
    {
        fprintf( stderr, "cudaCheckError() with sync failed at %s:%i : %s\n",
                 file, line, cudaGetErrorString( err ) );
        exit( -1 );
    }
    #endif

    return;
}


/* Put pixel colors on an array */

__global__ void color_kernel( uchar4* colorPos,
                              unsigned int width, unsigned int height, char* img_data, int img_widthstep,
                              int* edge_count )
{
    unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int j = blockIdx.y * blockDim.y + threadIdx.y;

    // calculate uv coordinates


    // calculate simple sine wave pattern
    if( ( i < width ) && ( j < height ) )
    {
        int node_index = ( ( j * width ) + i ) * CELL_SIZE;

        for( int t = 0; t < CELL_SIZE; t++ )
        {
//            if (t < (((edge_count[node_index]-2)*3)))
//            {

//                colorPos[node_index+t].x =  (unsigned char) img_data[PIXEL(i,j,img_widthstep, N_CHANNELS) + 2];
//                colorPos[node_index+t].y = (unsigned char) img_data[PIXEL(i,j,img_widthstep, N_CHANNELS) + 1];
//                colorPos[node_index+t].z =(unsigned char) img_data[PIXEL(i,j,img_widthstep, N_CHANNELS) + 0];
//                colorPos[node_index+t].w = (unsigned char)255;
//            } else
//            {
//                colorPos[node_index+t].x = (unsigned char)0;
//                colorPos[node_index+t].y = (unsigned char)128;
//                colorPos[node_index+t].z = (unsigned char)0;
//                colorPos[node_index+t].w = (unsigned char)255;
//            }
            colorPos[ node_index + t ].x = ( unsigned char ) img_data[ PIXEL( i, j, img_widthstep, N_CHANNELS ) + 2 ];
            colorPos[ node_index + t ].y = ( unsigned char ) img_data[ PIXEL( i, j, img_widthstep, N_CHANNELS ) + 1 ];
            colorPos[ node_index + t ].z = ( unsigned char ) img_data[ PIXEL( i, j, img_widthstep, N_CHANNELS ) + 0 ];
            colorPos[ node_index + t ].w = ( unsigned char )255;
        }
    }
}


/* Put vertex coordinates on an array for VBO */

template< typename T >
__global__ void position_kernel( float2* pos, T* diagram, int* edge_count, unsigned int width, unsigned int height )
{
    unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int j = blockIdx.y * blockDim.y + threadIdx.y;

    // calculate uv coordinates


    // calculate simple sine wave pattern
    if( ( i < width ) && ( j < height ) )
    {
        int cell_index = ( ( j * width ) + i ) * CELL_SIZE;
        int node_index = ( ( j * width ) + i );
        for( int t = 0; t < CELL_SIZE; t++ )
        {
            if( t < ( ( ( edge_count[ node_index ] - 2 ) * 3 ) ) )
            {
                pos[ cell_index + t ].x = diagram[ cell_index + t ].x;
                pos[ cell_index + t ].y = diagram[ cell_index + t ].y;
            }
            else
            {
                pos[ cell_index + t ].x = -100.0f;
                pos[ cell_index + t ].y = -100.0f;
            }
        }
    }
}


__global__ void graph_Kernel( char* a, int size, int width, int height, int img_widthstep, char* graph_out )
{
    int i = ( blockIdx.x * blockDim.x + threadIdx.x );
    int j = ( blockIdx.y * blockDim.y + threadIdx.y );

    if( ( i < width ) && ( j < height ) )
    {
        for( int e = 0; e < 8; e++ )
        {
            if( diff( i, j, e, width, height, img_widthstep, a ) )
            {
                SET_BIT( graph_out[ ( j * width ) + i ], e, 0 );
            }
            else
            {
                SET_BIT( graph_out[ ( j * width ) + i ], e, 1 );
            }
        }
    }
}


__global__ void trivial_cross_Kernel( int width, int height, char* graph )
{
    int i = ( blockIdx.x * blockDim.x + threadIdx.x );
    int j = ( blockIdx.y * blockDim.y + threadIdx.y );

    if( ( ( i >= 0 ) && ( j >= 0 ) ) && ( ( i < width ) && ( j < height ) ) )
    {
        //if ((i==1) && (j ==1)){

        //crossCheck(graph, width, height, 0, 0);
        //crossCheck(graph, width, height);

        crossCheck_4( graph, width, height, i, j );
        //crossCheck_Heuristics(graph, width, height, i, j);
    }
}


__global__ void ambiguous_cross_Kernel( int width, int height, char* graph, char* graph_aux, bool* flagSync )
{
    int i = ( blockIdx.x * blockDim.x + threadIdx.x );
    int j = ( blockIdx.y * blockDim.y + threadIdx.y );

    if( ( i < width ) && ( j < height ) )
    {
        crossCheck_Heuristics( graph, graph_aux, width, height, i, j, flagSync );
    }
}


template< typename T >
__global__ void cells_Kernel( int width, int height, char* graph, T* diagram, int* edge_count )
{
    int i = ( blockIdx.x * blockDim.x + threadIdx.x );
    int j = ( blockIdx.y * blockDim.y + threadIdx.y );

    if( ( i < width ) && ( j < height ) )
    {
        int cell_index = ( ( j * width ) + i ) * CELL_SIZE;
        int node_index = ( ( j * width ) + i );


        edge_count[ ( j * width ) + i ] = createCellFromPattern< T >( graph[ ( j * width ) + i ],
                                                                      graph[ node_index - 1 ], graph[ node_index + 1 ],
                                                                      diagram, cell_index,
                                                                      i, j );


//        edge_count[(j*width) + i] = createCellFromPattern(64, 4, 0, diagram, cell_index,
//                              i, j);
    }
}


template< typename T >
__global__ void subdivision_Kernel( char* image_data, int width, int img_widthstep, int height, char* graph,
                                    T* diagram, T* diagram_aux, int* edge_count, int* edge_count_old, bool* edge_status,
                                    int* link_index )
{
    int i = ( blockIdx.x * blockDim.x + threadIdx.x );
    int j = ( blockIdx.y * blockDim.y + threadIdx.y );

    if( ( i < width ) && ( j < height ) )
    {
        int cell_index = ( ( j * width ) + i ) * CELL_SIZE;
        int node_index = ( ( j * width ) + i );
        //int old_e_count = edge_count[ node_index ];

        /* Do not process internal node */
        if( graph[ node_index ] == 90 )
        {
            return;
        }

        //checkEdges(&edge_status[cell_index], &diagram[ (node_index * CELL_SIZE)], graph[node_index], edge_count[node_index], i, j, &link_index[cell_index]);

        int new_edge_count = subdivision( image_data, &diagram[ cell_index ], diagram_aux, edge_count_old, node_index,
                                          width, img_widthstep, height, i, j, graph[ node_index ],
                                          &edge_status[ cell_index ],
                                          &link_index[ cell_index ] );

        __syncthreads();

        edge_count[ node_index ] = new_edge_count;

//        if ( (i == 2) && (j == 2) )
//        {
//            printf("edge status: ");
//            for (int t = 0; t < old_e_count; t++)
//                printf("%d, ", edge_status[cell_index + t]);
//            printf("\n");

//            printf("link index: ");
//            for (int t = 0; t < old_e_count; t++)
//                printf("%d, ", link_index[cell_index + t]);
//            printf("\n");
//            printf("node: %d\n", graph[node_index]);
//        }
    }
}


template< typename T >
__global__ void triangulate_Kernel( int width, int height, T* diagram, int* edge_count )
{
    int i = ( blockIdx.x * blockDim.x + threadIdx.x );
    int j = ( blockIdx.y * blockDim.y + threadIdx.y );


    if( ( i < width ) && ( j < height ) )
    {
        int cell_index = ( ( j * width ) + i ) * CELL_SIZE;
        int edge_c_index = ( ( j * width ) + i );

        /* Polygon Triangulation Function */
        triangulate_polygon( &diagram[ cell_index ], edge_count, edge_c_index, CELL_SIZE, i, j );

        /* Set the number of triangules for the polygon */
        //edge_count[edge_c_index] = (edge_count[edge_c_index] - 2);
    }
}


// Wrapper for the __global__ call that sets up the kernel call
extern "C" Point * launch_kernel( float2 * pos, uchar4 * colorPos, float time,
                                  char* img_data, int img_width, int img_height, int img_widthstep, int* edge_count_h,
                                  char* graph_h, bool subdivide )
{
    /* c_pattern.png */
    //char graph_dump[64] = {18, 26, 26, 25, 28, 26, 26, 10, 82, 90, 201, 17, 12, 116, 90, 74, 82, 202, 130, 18, 14, 32, 115, 74,
    //                       82, 74, 66, 82, 90, 186, 90, 74, 82, 74, 66, 82, 90, 93, 90, 74, 82, 78, 68, 80, 200, 1, 115, 74,
    //                       82, 90, 46, 48, 136, 147, 90, 74, 80, 88, 88, 56, 152, 88, 88, 72 };

    /* alex.png */
    //char graph_dump[576] = {(char) 18, (char) 26, (char) 26, (char) 26, (char) 10, (char) 18, (char) 25, (char) 24, (char) 24, (char) 28, (char) 26, (char) 26, (char) 25, (char) 24, (char) 24, (char) 28, (char) 10, (char) 18, (char) 26, (char) 26, (char) 26, (char) 26, (char) 26, (char) 10, (char) 82, (char) 90, (char) 90, (char) 90, (char) 78, (char) 196, (char) 20, (char) 26, (char) 26, (char) 10, (char) 114, (char) 202, (char) 18, (char) 26, (char) 26, (char) 9, (char) 97, (char) 83, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 46, (char) 36, (char) 112, (char) 88, (char) 72, (char) 82, (char) 74, (char) 80, (char) 88, (char) 200, (char) 130, (char) 146, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 42, (char) 34, (char) 18, (char) 10, (char) 82, (char) 74, (char) 18, (char) 26, (char) 10, (char) 66, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 89, (char) 92, (char) 74, (char) 66, (char) 82, (char) 74, (char) 82, (char) 73, (char) 83, (char) 90, (char) 74, (char) 70, (char) 80, (char) 92, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 201, (char) 17, (char) 12, (char) 96, (char) 67, (char) 82, (char) 78, (char) 192, (char) 147, (char) 90, (char) 90, (char) 73, (char) 81, (char) 56, (char) 12, (char) 116, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 202, (char) 130, (char) 16, (char) 8, (char) 180, (char) 74, (char) 82, (char) 90, (char) 186, (char) 90, (char) 90, (char) 202, (char) 130, (char) 16, (char) 24, (char) 8, (char) 34, (char) 114, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 78, (char) 68, (char) 20, (char) 26, (char) 9, (char) 98, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 66, (char) 16, (char) 28, (char) 10, (char) 66, (char) 82, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 46, (char) 36, (char) 228, (char) 4, (char) 64, (char) 83, (char) 89, (char) 92, (char) 90, (char) 90, (char) 73, (char) 65, (char) 19, (char) 9, (char) 97, (char) 65, (char) 83, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 46, (char) 36, (char) 32, (char) 178, (char) 202, (char) 18, (char) 10, (char) 114, (char) 206, (char) 128, (char) 147, (char) 202, (char) 130, (char) 130, (char) 146, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 42, (char) 38, (char) 80, (char) 72, (char) 80, (char) 72, (char) 80, (char) 92, (char) 186, (char) 89, (char) 72, (char) 65, (char) 65, (char) 83, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 73, (char) 81, (char) 56, (char) 24, (char) 24, (char) 24, (char) 24, (char) 8, (char) 224, (char) 16, (char) 136, (char) 134, (char) 148, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 201, (char) 129, (char) 19, (char) 25, (char) 28, (char) 26, (char) 26, (char) 26, (char) 14, (char) 20, (char) 26, (char) 14, (char) 80, (char) 44, (char) 116, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 202, (char) 130, (char) 146, (char) 201, (char) 16, (char) 8, (char) 115, (char) 89, (char) 88, (char) 92, (char) 42, (char) 114, (char) 93, (char) 58, (char) 10, (char) 34, (char) 114, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 78, (char) 68, (char) 192, (char) 20, (char) 10, (char) 146, (char) 202, (char) 20, (char) 26, (char) 10, (char) 98, (char) 194, (char) 4, (char) 116, (char) 74, (char) 66, (char) 82, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 42, (char) 50, (char) 10, (char) 98, (char) 82, (char) 74, (char) 2, (char) 114, (char) 74, (char) 66, (char) 66, (char) 2, (char) 34, (char) 98, (char) 66, (char) 82, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 73, (char) 81, (char) 72, (char) 66, (char) 82, (char) 74, (char) 64, (char) 83, (char) 73, (char) 65, (char) 67, (char) 66, (char) 66, (char) 66, (char) 66, (char) 82, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 202, (char) 130, (char) 6, (char) 4, (char) 64, (char) 83, (char) 78, (char) 144, (char) 200, (char) 129, (char) 147, (char) 73, (char) 66, (char) 66, (char) 66, (char) 66, (char) 82, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 78, (char) 68, (char) 84, (char) 46, (char) 180, (char) 90, (char) 90, (char) 57, (char) 136, (char) 147, (char) 206, (char) 4, (char) 64, (char) 67, (char) 64, (char) 67, (char) 82, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 42, (char) 34, (char) 114, (char) 46, (char) 112, (char) 200, (char) 19, (char) 154, (char) 90, (char) 90, (char) 46, (char) 176, (char) 72, (char) 146, (char) 73, (char) 83, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 78, (char) 68, (char) 84, (char) 90, (char) 58, (char) 154, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 58, (char) 10, (char) 194, (char) 146, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 46, (char) 36, (char) 112, (char) 92, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 89, (char) 72, (char) 65, (char) 83, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 82, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 46, (char) 48, (char) 12, (char) 112, (char) 88, (char) 88, (char) 88, (char) 88, (char) 200, (char) 17, (char) 136, (char) 147, (char) 90, (char) 90, (char) 90, (char) 90, (char) 90, (char) 74, (char) 80, (char) 88, (char) 88, (char) 88, (char) 88, (char) 88, (char) 88, (char) 56, (char) 8, (char) 48, (char) 24, (char) 24, (char) 24, (char) 24, (char) 136, (char) 16, (char) 152, (char) 88, (char) 88, (char) 88, (char) 88, (char) 88, (char) 88, (char) 72 };

    StopWatchInterface* timer = NULL;
    sdkCreateTimer( &timer );
    sdkResetTimer( &timer );
    sdkStartTimer( &timer );

    /* Size needed to hold image data */
    size_t img_size = img_widthstep * img_height * sizeof( char );


    //size_t size = N_CHANNELS * img_width * img_height * sizeof( char );


    /*----------- Image Device -------------*/

    /* Image data pointer to device memory */
    char* img_data_d;

    /* Allocates memory in device to image */
    cudaMalloc( ( void** ) &img_data_d, img_size );

    /* Copy data from host to device */
    cudaMemcpy( img_data_d, img_data, img_size, cudaMemcpyHostToDevice );


    /*----------- Graph Device -------------*/

    /* Graph data pointer to device memory */
    char* graph_d;

    /* Allocates memory in device to graph */
    cudaMalloc( ( void** ) &graph_d, img_width * img_height * sizeof( char ) );

    /* Aux Graph data pointer to device memory */
    char* graph_d_aux;

    /* Allocates memory in device to graph */
    cudaMalloc( ( void** ) &graph_d_aux, img_width * img_height * sizeof( char ) );

    /* ------- TEST FOR NOT FERMI GPUS  -------- */
    /* Copy data from host to device */
    cudaMemcpy( graph_d, graph_h, img_width * img_height * sizeof( char ), cudaMemcpyHostToDevice );


    /*----------- Diagram Device -------------*/

    /* Diagram data pointer to host memory */
    Point* diagram_h;
    /* Diagram data pointer to device memory */
    Point* diagram_d;
    /* Auxiliar diagram data pointer to device memory (to be used on subdivision) */
    Point* diagram_aux_d;

    /* Allocates memory in host to diagram */
    diagram_h = ( Point* )malloc( img_width * img_height * sizeof( Point ) * CELL_SIZE );
    /* Allocates memory in device to diagram */
    cudaMalloc( ( void** ) &diagram_d, img_width * img_height * sizeof( Point ) * CELL_SIZE );
    /* Allocates memory in device to auxiliar diagram */
    cudaMalloc( ( void** ) &diagram_aux_d, img_width * img_height * sizeof( Point ) * CELL_SIZE );


    /*----------- Polygon Edge Count Device -------------*/

    /* Int array data pointer to device memory */
    //int* edge_count_h;
    /* Int array data pointer to host memory */
    int* edge_count_d;
    /* Auxiliar Int array data pointer to host memory */
    int* edge_count_aux_d;

    /* Allocates memory in host to array of vertices count */
    //edge_count_h = (int*)malloc(img_width*img_height*sizeof(int));
    /* Allocates memory in device to array of vertices count */
    cudaMalloc( ( void** ) &edge_count_d, img_width * img_height * sizeof( int ) );
    /* Allocates memory in device to array of vertices count */
    cudaMalloc( ( void** ) &edge_count_aux_d, img_width * img_height * sizeof( int ) );

    /*-------------- Flag Array to Synchronize (still unused) ---------------*/

    bool* flagSync_d;
    cudaMalloc( ( void** ) &flagSync_d, img_width * img_height * sizeof( bool ) );


    /*-------------- Arrays needed on Subdivision Kernel ---------------*/

    bool* edge_status_d;

    cudaMalloc( ( void** ) &edge_status_d, img_width * img_height * sizeof( bool ) * CELL_SIZE );

    int* link_index_d;

    cudaMalloc( ( void** ) &link_index_d, img_width * img_height * sizeof( int ) * CELL_SIZE );


    /* set grid and blocks */
    dim3 threadsPerBlock( 2, 2 );
    dim3 numBlocks( ( img_width / threadsPerBlock.x ) + ( img_width % threadsPerBlock.x == 0 ? 0 : 1 ),
                    ( img_height / threadsPerBlock.y ) + ( img_height % threadsPerBlock.y == 0 ? 0 : 1 ) );

    printf( "numblocks.x = %d\n", numBlocks.x );
    printf( "numblocks.y = %d\n", numBlocks.y );

    /* ********************* Beginning of the Kernel Pipeline ********************* */

    /* Graph Stage */
    graph_Kernel <<< numBlocks, threadsPerBlock >>> ( img_data_d,
                                                      img_size,
                                                      img_width,
                                                      img_height,
                                                      img_widthstep,
                                                      graph_d );
    cudaThreadSynchronize();

    /* Graph's Cross Check Stage (trivial case) */
    trivial_cross_Kernel <<< numBlocks, threadsPerBlock >>> ( img_width,
                                                              img_height,
                                                              graph_d );

    cudaMemcpy( graph_d_aux, graph_d, img_width * img_height * sizeof( char ), cudaMemcpyDeviceToDevice );
    cudaThreadSynchronize();

    /* Graph's Heuristics Stage */
    ambiguous_cross_Kernel <<< numBlocks, threadsPerBlock >>> ( img_width,
                                                                img_height,
                                                                graph_d,
                                                                graph_d_aux,
                                                                flagSync_d );

    /* Diagram Stage */
    cells_Kernel< Point > <<< numBlocks, threadsPerBlock >>> ( img_width,
                                                               img_height,
                                                               graph_d,
                                                               diagram_d,
                                                               edge_count_d );

    //cells_Kernel<float2> <<< numBlocks, threadsPerBlock >>> (img_width, img_height, graph_d, pos, edge_count_d);

    cudaMemcpy( diagram_aux_d, diagram_d,
                img_width * img_height * sizeof( Point ) * CELL_SIZE, cudaMemcpyDeviceToDevice );
    cudaMemcpy( edge_count_aux_d, edge_count_d,
                img_width * img_height * sizeof( int ), cudaMemcpyDeviceToDevice );

    /* Cell Smoothing Stage */
    if( subdivide )
    {
        subdivision_Kernel< Point > <<< numBlocks, threadsPerBlock >>> ( img_data_d,
                                                                         img_width,
                                                                         img_widthstep,
                                                                         img_height,
                                                                         graph_d,
                                                                         diagram_d,
                                                                         diagram_aux_d,
                                                                         edge_count_d,
                                                                         edge_count_aux_d,
                                                                         edge_status_d,
                                                                         link_index_d );
    }

    /* Cell's Triangulation Stage */
    triangulate_Kernel< Point > <<< numBlocks, threadsPerBlock >>> ( img_width,
                                                                     img_height,
                                                                     diagram_d,
                                                                     edge_count_d );
    //triangulate_cell<float2> <<< numBlocks, threadsPerBlock >>> (img_width, img_height, pos, edge_count_d, CELL_SIZE);

    /* Put pixel colors on an array */
    color_kernel <<< numBlocks, threadsPerBlock >>> ( colorPos,
                                                      img_width,
                                                      img_height,
                                                      img_data_d,
                                                      img_widthstep,
                                                      edge_count_d );

    /* Put vertex coordinates on an array for VBO */
    position_kernel< Point ><<< numBlocks, threadsPerBlock >>> ( pos,
                                                                 diagram_d,
                                                                 edge_count_d,
                                                                 img_width,
                                                                 img_height );

    /* Check for errors */
    CudaCheckError();

    /* ********************* End of the Kernel Pipeline ********************* */

    sdkStopTimer( &timer );
    float kernelTime = sdkGetTimerValue( &timer );
    sdkDeleteTimer( &timer );

    printf( "Time for the kernels: %f ms\n", kernelTime );

    cudaMemcpy( edge_count_h, edge_count_d,
                img_width * img_height * sizeof( int ), cudaMemcpyDeviceToHost );
    cudaMemcpy( diagram_h, diagram_d,
                img_width * img_height * sizeof( Point ) * CELL_SIZE, cudaMemcpyDeviceToHost );
    cudaMemcpy( graph_h, graph_d,
                img_width * img_height * sizeof( char ), cudaMemcpyDeviceToHost );

    //pos = (float2*)diagram_h;

    /* Degub pixel/node/cell i x j */

    //    int i = 8;
    //    int j = 5;
    //    int index = (i*img_width) + j;
    //    int index_cell = ( (i*img_width) + j ) * CELL_SIZE;

    //    printf("edge_count[i]: %d\n", edge_count_h[index]);
    //    printf("node[i]: %d\n", (unsigned int) (unsigned char) graph_h[index]);

    //    printf("cell_index: %d :\n", index_cell);
    //    for (int t = 0; t < CELL_SIZE; t++){
    //        //cout << "P( " << diagram_h[i].x << ", " << diagram_h[i].y << " )" << endl;
    //        printf("P( %2.2f, %2.2f )\n", diagram_h[index_cell + t].x, diagram_h[index_cell + t].y);
    //    }

    /* clean up */
    cudaFree( img_data_d );
    cudaFree( graph_d );
    cudaFree( graph_d_aux );
    cudaFree( diagram_d );
    cudaFree( diagram_aux_d );
    cudaFree( flagSync_d );
    cudaFree( edge_status_d );
    cudaFree( edge_count_d );
    cudaFree( edge_count_aux_d );
    cudaFree( link_index_d );

    return diagram_h;
}
