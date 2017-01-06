//#include <cuda.h>

/** Check bit value */
#define CHECK_BIT( var, pos ) ( ( var ) & ( 1 << ( pos ) ) )

/** Clean bit then set */
#define SET_BIT( var, pos, data ) var &= ~( 1 << pos );var |= data << pos

#define SET_BIT_ATOMIC( var, pos, data ) atomicAnd( ( int* )&var, ~( 1 << pos ) );atomicOr( ( int* )&var, data << pos )

#define Ymask 0x00FF0000
#define Umask 0x0000FF00
#define Vmask 0x000000FF
/* Original trY  */
//#define trY   0x00300000
/* Better value when not using Splines with difusion (Empirical value) */
#define trY 0x00050000
#define trU 0x00000700
#define trV 0x00000006

#define RGBA 0x00000000

#define PIXEL( i, j, widthstep, n_channels ) ( ( j * ( widthstep ) ) + ( i * n_channels ) )

// Retorna posição do bit da aresta da célula vizinha
__device__ int conected_edge( int edge )
{
    return ( 8 - 1 ) - edge;

    /*    switch(edge)
        {
            case 0: return 7;
            case 1: return 6;
            case 2: return 5;
            case 3: return 4;
            case 4: return 3;
            case 5: return 2;
            case 6: return 1;
            case 7: return 0;
        }
    */
}


// Calcula índice da célula vizinha de acordo com a aresta conectada
__device__ int calc_index( int index, int edge, int width )
{
    switch( edge )
    {
        case 0:
            return index + width - 1;

        case 1:
            return index + width;

        case 2:
            return index + width + 1;

        case 3:
            return index - 1;

        case 4:
            return index + 1;

        case 5:
            return index - width - 1;

        case 6:
            return index - width;

        case 7:
            return index - width + 1;
    }

    return 0;
}


/* Initalize RGB to YUV lookup table */
__device__ unsigned int RGBtoYUV( int c )
{
    int r, g, b, y, u, v;

    r = ( c & 0x0000FF );
    g = ( c & 0x00FF00 ) >> 8;
    b = ( c & 0xFF0000 ) >> 16;
    //r = (c & 0xFF0000) >> 16;
    //g = (c & 0x00FF00) >> 8;
    //b = c & 0x0000FF;
    y = int( ( 0.299 * float( r ) + 0.587 * float( g ) + 0.114 * float( b ) ) );
    //u = (unsigned int)(-0.169*r - 0.331*g + 0.5*b) + 128; //Cb
    //v = (unsigned int)(0.5*r - 0.419*g - 0.081*b) + 128;  //Cr
    u = int( ( ( b - y ) * 0.492f ) );
    v = int( ( ( r - y ) * 0.877f ) );


    return ( unsigned int )( ( y << 16 ) + ( u << 8 ) + v );
}


/* Convert value to int type */
__device__ unsigned int DATAtoINT( unsigned int r, unsigned int g, unsigned int b )
{
    unsigned int result;

    /* R_ = xxxx xxxx xxxx xxxx xxxx xxxx RRRR RRRR*/
    unsigned int R_ = ( unsigned int ) r;

    /* G_ = xxxx xxxx xxxx xxxx GGGG GGGG xxxx xxxx*/
    unsigned int G_ = ( unsigned int ) g << 8;

    /* B_ = xxxx xxxx BBBB BBBB xxxx xxxx rrrr rrrr*/
    unsigned int B_ = ( unsigned int ) b << 16;
    //unsigned int A_ = 0x00FFFFFF;


    /* R_ = 0000 0000 0000 0000 0000 0000 RRRR RRRR*/
    R_ &= 0x000000FF;

    /* G_ = 0000 0000 0000 0000 GGGG GGGG 0000 0000*/
    G_ = ( G_ & 0x0000FF00 );

    /* B_ = 0000 0000 BBBB BBBB 0000 0000 0000 0000*/
    B_ = ( B_ & 0x00FF0000 );


    /* result = 0000 0000 BBBB BBBB GGGG GGGG RRRR RRRR*/
    result = ( ( R_ | G_ | B_ ) );

    return result;
}


int __device__ abs_( int a )
{
    if( a < 0 )
    {
        return ( -1 * a );
    }
    else
    {
        return a;
    }
}


__device__ int diff( int w, int h, int pos, int width, int height, int img_widthstep, char* pixel_data )
{
    int result;
    unsigned int YUV1;
    unsigned int YUV2;

    /* Pixels colors in RGB to be converted */
    char* pixel_src, * pixel_dst;

    /* Pixels colors in YUV space to be compared */
    unsigned int pixel_src_YUV, pixel_dst_YUV;

    /* Height and Width position of pixel_dst */
    int n_h, n_w;

    //   +----+----+----+
    //   |    |    |    |
    //   | 0  | 1  | 2  |
    //   +----+----+----+
    //   |    |    |    |
    //   | 3  | x  | 4  |
    //   +----+----+----+
    //   |    |    |    |
    //   | 5  | 6  | 7  |
    //   +----+----+----+

    //    uchar r = img->imageData[h*img->widthStep + w*nChannels];
    //    uchar g = img->imageData[h*img->widthStep + w*nChannels+1];
    //    uchar b = img->imageData[h*img->widthStep + w*nChannels+2];

    pixel_src = &( pixel_data[ PIXEL( w, h, img_widthstep, 3 ) ] );

    // __DEBUG__
//    if ( (w == 2) && (h == 1) )
//    {
//        printf("w: %d, h: %d, pos: %d\n", w, h, pos);
//        printf("width: %d\n", width);
//        printf("n_channels: %d\n", 3);
//        printf("index: %d\n", PIXEL(w, h, img_widthstep, 3));
//        printf("widthstep: %d\n", img_widthstep);
//        printf("pixel_src[0]: %d\n", (unsigned char) pixel_src[0]);
//        printf("pixel_src[1]: %d\n", (unsigned char) pixel_src[1]);
//        printf("pixel_src[2]: %d\n", (unsigned char) pixel_src[2]);
//    }

    pixel_src_YUV = DATAtoINT( pixel_src[ 0 ], pixel_src[ 1 ], pixel_src[ 2 ] );

    switch( pos )
    {
        case 0:
            n_w = ( w - 1 );
            n_h = ( h + 1 );
            break;

        case 1:
            n_w = ( w );
            n_h = ( h + 1 );
            break;

        case 2:
            n_w = ( w + 1 );
            n_h = ( h + 1 );
            break;

        case 3:
            n_w = ( w - 1 );
            n_h = ( h );
            break;

        case 4:
            n_w = ( w + 1 );
            n_h = ( h );
            break;

        case 5:
            n_w = ( w - 1 );
            n_h = ( h - 1 );
            break;

        case 6:
            n_w = ( w );
            n_h = ( h - 1 );
            break;

        case 7:
            n_w = ( w + 1 );
            n_h = ( h - 1 );
            break;
    }


    //printf("pos: %d, n_w: %d, n_h: %d\n", pos, n_w, n_h);


    //index = n_h*img->getWidth() + n_w;

    /* Check if index is inside image boundaries */
    //if ((index > 0) && (index < ((img->getWidth())*(img->getHeight())-1)))
    if( !( ( n_w < 0 ) || ( n_h < 0 ) ||
           ( n_w >= width ) ||
           ( n_h >= height ) ) )
    {
        pixel_dst = &( pixel_data[ PIXEL( n_w, n_h, img_widthstep, 3 ) ] );

        pixel_dst_YUV = DATAtoINT( pixel_dst[ 0 ], pixel_dst[ 1 ], pixel_dst[ 2 ] );

        if( ( w == 1 ) && ( h == 1 ) )
        {
            //printf("pos: %d, pixel_dst[0]: %d, pixel_dst[1]: %d, pixel_dst[2]: %d\n",
            //         pos, (unsigned char) pixel_dst[0], (unsigned char) pixel_dst[1], (unsigned char) pixel_dst[2]);
        }


        /* Mask against RGB_MASK to discard the alpha channel */
        YUV1 = RGBtoYUV( pixel_src_YUV );
        YUV2 = RGBtoYUV( pixel_dst_YUV );

        /* __DEBUG__ */
//        if ((w == 2) && (h==1)){
//            printf("YUV_src: %d, YUV_dest: %d \n",
//                     YUV1,
//                     YUV2);
//            printf("trY: %d, trU: %d, trV: %d \n",
//                     trY,
//                     trU,
//                     trV);
//            printf("maskY_src: %d , maskY_dst: %d, diff: %d, abs_diff: %d\n",
//                     YUV1 & Ymask,
//                     YUV2 & Ymask,
//                     ( ( YUV1 & Ymask ) - ( YUV2 & Ymask ) ),
//                     abs_( ( YUV1 & Ymask ) - ( YUV2 & Ymask ) ) );
//            printf("maskU_src: %d , maskU_dst: %d, diff: %d, abs_diff: %d\n",
//                     YUV1 & Umask,
//                     YUV2 & Umask,
//                     ( ( YUV1 & Umask ) - ( YUV2 & Umask ) ),
//                     abs_((YUV1 & Umask) - (YUV2 & Umask)));
//            printf("maskV_src: %d , maskV_dst: %d, diff: %d, abs_diff: %d\n",
//                     YUV1 & Vmask,
//                     YUV2 & Vmask,
//                     ( ( YUV1 & Vmask ) - ( YUV2 & Vmask ) ),
//                     abs_((YUV1 & Vmask) - (YUV2 & Vmask)));
//        }

        /* cound not use "fabs" function because of weirds results */
        result = ( ( abs_( ( YUV1 & Ymask ) - ( YUV2 & Ymask ) ) > trY ) ||
                   ( abs_( ( YUV1 & Umask ) - ( YUV2 & Umask ) ) > trU ) ||
                   ( abs_( ( YUV1 & Vmask ) - ( YUV2 & Vmask ) ) > trV ) );

        //printf("result: %d \n", result);

        /* Print function data */

        //std::cout << "index src - x: " << w << " y:  " << h << std::endl;
        //std::cout << "index dst - x: " << n_w << " y:  " << n_h << std::endl;
        //std::cout << "pos: " << pos << " - ";
        //std::cout << "results: " << result << std::endl;

        //if (result != 0) {cout << result << endl;}
        return result;
    }
    else
    {
        return 1;
    }
}


__device__ bool crossedEdge( char* graph, int i, int j, int width, int edge )
{
    int index = ( j * width + i );

    int i0 = ( ( j + 1 ) * width + i - 1 );
    int i1 = ( ( j + 1 ) * width + i );
    int i2 = ( ( j + 1 ) * width + i + 1 );
    int i3 = ( ( j ) * width + i - 1 );
    int i4 = ( ( j ) * width + i + 1 );
    int i5 = ( ( j - 1 ) * width + i - 1 );
    int i6 = ( ( j - 1 ) * width + i );
    int i7 = ( ( j - 1 ) * width + i + 1 );

    switch( edge )
    {
        case 0:
            if( ( CHECK_BIT( graph[ i3 ], 2 ) ) &&
                ( CHECK_BIT( graph[ i0 ], 7 ) ) &&
                ( CHECK_BIT( graph[ index ], 0 ) ) &&
                ( CHECK_BIT( graph[ i1 ], 5 ) ) )
            {
                return true;
            }

        case 2:
            if( ( CHECK_BIT( graph[ index ], 2 ) ) &&
                ( CHECK_BIT( graph[ i1 ], 7 ) ) &&
                ( CHECK_BIT( graph[ i4 ], 0 ) ) &&
                ( CHECK_BIT( graph[ i2 ], 5 ) ) )
            {
                return true;
            }

        case 7:
            if( ( CHECK_BIT( graph[ i5 ], 2 ) ) &&
                ( CHECK_BIT( graph[ i3 ], 7 ) ) &&
                ( CHECK_BIT( graph[ i6 ], 0 ) ) &&
                ( CHECK_BIT( graph[ index ], 5 ) ) )
            {
                return true;
            }

        case 5:
            if( ( CHECK_BIT( graph[ i6 ], 2 ) ) &&
                ( CHECK_BIT( graph[ index ], 7 ) ) &&
                ( CHECK_BIT( graph[ i7 ], 0 ) ) &&
                ( CHECK_BIT( graph[ i4 ], 5 ) ) )
            {
                return true;
            }
    }

    return false;
}


__device__ bool checkValence2EdgeGPU( char* graph, int i_1, int j_1, int i_2, int j_2, int width, int edge_1,
                                      int edge_2, char nodeResult )
{
    //int k_n;     // last conected edge
    int sum_1 = 0;
    int sum_2 = 0; // soma de arestas conectadas além da 2
    int index_1 = ( j_1 * width + i_1 );
    int index_2 = ( j_2 * width + i_2 );

    char node_1 = graph[ index_1 ];

    if( nodeResult != 255 )
    {
        node_1 = nodeResult;
    }

    for( int k = ( edge_1 + 1 ); k < ( edge_1 + 8 ); k++ )
    {
        if( CHECK_BIT( node_1, k % 8 ) )
        {
            //if (!crossedEdge(graph, i_1, j_1, width, k%8))
            //{
            sum_1++;
            //k_n = k;
            //}
        }
    }
    for( int k = ( edge_2 + 1 ); k < ( edge_2 + 8 ); k++ )
    {
        if( CHECK_BIT( graph[ index_2 ], k % 8 ) )
        {
            //if (!crossedEdge(graph, i_2, j_2, width, k%8))
            //{
            sum_2++;
            //k_n = k;
            //}
        }
    }
    //cout << "sum_1: " << sum_1 << endl;
    //cout << "sum_2: " << sum_2 << endl;
    if( ( sum_1 == 1 ) && ( sum_2 == 1 ) )
    {
        return true;
    }
    else
    {
        return false;
    }
}


__device__ bool checkValence2Edge( char* graph, int index_1, int index_2, int edge_1, int edge_2 )
{
    //int k_n;     // last conected edge
    int sum_1 = 0;
    int sum_2 = 0; // soma de arestas conectadas além da 2

    for( int k = ( edge_1 + 1 ); k < ( edge_1 + 8 ); k++ )
    {
        if( CHECK_BIT( graph[ index_1 ], k % 8 ) )
        {
            sum_1++;
            //k_n = k;
        }
    }
    for( int k = ( edge_2 + 1 ); k < ( edge_2 + 8 ); k++ )
    {
        if( CHECK_BIT( graph[ index_2 ], k % 8 ) )
        {
            sum_2++;
            //k_n = k;
        }
    }
    //cout << "sum_1: " << sum_1 << endl;
    //cout << "sum_2: " << sum_2 << endl;
    if( ( sum_1 == 1 ) && ( sum_2 == 1 ) )
    {
        return true;
    }
    else
    {
        return false;
    }
}


/* Varre o nó para saber se existe algum outro bit ativo
   Retorna true se apenas edge_1 está ativo             */
__device__ bool checkValence2Vertex( char* graph, int index_1, int edge_1 )
{
    //int k_n;     // last conected edge
    int sum = 0; // soma de arestas conectadas além da 2
    for( int k = ( edge_1 + 1 ); k < ( edge_1 + 8 ); k++ )
    {
        if( CHECK_BIT( graph[ index_1 ], k % 8 ) )
        {
            sum++;
            //k_n = k;
        }
    }
    //cout << sum << endl;
    if( sum == 0 )
    {
        return true;
    }
    else
    {
        return false;
    }
}


/* Varre o nó para saber se existe algum outro bit ativo
   Retorna true quando mais um (e apenas um) link estiver atvo            */
__device__ bool checkVertexV2( char* graph, int index_1, int edge_1 )
{
    //int k_n;     // last conected edge
    int sum = 0; // soma de arestas conectadas além da 2
    for( int k = ( edge_1 + 1 ); k < ( edge_1 + 8 ); k++ )
    {
        if( CHECK_BIT( graph[ index_1 ], k % 8 ) )
        {
            sum++;
            //k_n = k;
        }
    }
    //cout << sum << endl;
    if( sum == 1 )
    {
        return true;
    }
    else
    {
        return false;
    }
}


__device__ bool checkValence2VertexGPU( char* graph, int index_1, int edge_1, char nodeResult )
{
    //int k_n;     // last conected edge
    int sum = 0; // soma de arestas conectadas além da 2

    char node_1 = graph[ index_1 ];

    if( nodeResult != 255 )
    {
        node_1 = nodeResult;
    }

    for( int k = ( edge_1 + 1 ); k < ( edge_1 + 8 ); k++ )
    {
        if( CHECK_BIT( node_1, k % 8 ) )
        {
            sum++;
            //k_n = k;
        }
    }
    //cout << sum << endl;
    if( sum == 0 )
    {
        return true;
    }
    else
    {
        return false;
    }
}


/* Calculate the size of a valence-2 path starting prom index */
__device__ int calcVal2PathSize( char* graph, int index, int edge, int& result, int width )
{
    int k_n; // Outra aresta quando o segmento é de valência 2
    int sum = 0;
    //switch (side){
    //    case 0: {
    // a partir de edge + 1 (edge já é conexo)
    for( int k = ( edge + 1 ); k < ( edge + 8 ); k++ )
    {
        if( CHECK_BIT( graph[ index ], k % 8 ) )
        {
            sum++;
            k_n = k;
        }
    }
    // Compare to a big number to not enter in loop
    if( result > 30 )
    {
        return result;
    }
    if( sum == 1 )
    {
        result++;
        calcVal2PathSize( graph, calc_index( index, k_n % 8, width ), conected_edge( k_n % 8 ), result, width );
    }
    else if( sum == 0 )
    {
        return result;
    }
    return result;
    //}
    //}
}


__device__ void processHeuristics( char* graph, int i, int j, int width, int height )
{
    int seg_size = 0;
    int seg_size2 = 0;

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );



    // Both edges are
    if( ( checkValence2Edge( graph, i1, i4, 2, 5 ) ) && ( checkValence2Edge( graph, i3, i2, 0, 7 ) ) )
    {
    }
    else
    {
        /* Just i1-i4 edge is valence 2 */
        /*  i2  /i4
               /
            i1/  i3  */
        if( checkValence2Edge( graph, i1, i4, 2, 5 ) )
        {
            /* Remove i2-i3 edge */
            SET_BIT( graph[ i2 ], 7, 0 );
            SET_BIT( graph[ i3 ], 0, 0 );
        }
        else
        /* Just i2-i3 edge is valence 2 */
        /*  i2\  i4
               \
            i1  \i3  */
        if( checkValence2Edge( graph, i3, i2, 0, 7 ) )
        {
            /* Remove i1-i4 edge */
            SET_BIT( graph[ i1 ], 2, 0 );
            SET_BIT( graph[ i4 ], 5, 0 );
        }
        else
        /* Island Heuristic */
        if( ( ( checkValence2Vertex( graph, i1, 2 ) ) || ( checkValence2Vertex( graph, i4, 5 ) ) ) &&
            ( !( checkValence2Vertex( graph, i3, 0 ) ) ) && ( !( checkValence2Vertex( graph, i2, 7 ) ) ) )
        {
            SET_BIT( graph[ i2 ], 7, 0 );
            SET_BIT( graph[ i3 ], 0, 0 );
        }
        else
        /* Island Heuristic */
        if( ( checkValence2Vertex( graph, i3, 0 ) ) || ( checkValence2Vertex( graph, i2, 7 ) ) &&
            ( !( checkValence2Vertex( graph, i1, 2 ) ) ) && ( !( checkValence2Vertex( graph, i4, 5 ) ) ) )
        {
            SET_BIT( graph[ i1 ], 2, 0 );
            SET_BIT( graph[ i4 ], 5, 0 );
        }
        else
        {
            // Calcula tamanho partindo da aresta 2 de i1 e partindo da aresta 5 de i4. Depois soma

            //usleep(5000 * 1000);
            calcVal2PathSize( graph, i1, 2, seg_size, width );

            calcVal2PathSize( graph, i4, 5, seg_size, width );
            //cout << "i1 seg_size total: " << seg_size << endl;


            // Calcula tamanho partindo da aresta 0 de i3 e partindo de 7 da aresta i2. Depois soma

            //usleep(5000 * 1000);
            calcVal2PathSize( graph, i3, 0, seg_size2, width );

            calcVal2PathSize( graph, i2, 7, seg_size2, width );
            //cout << "  i3 seg_size total: " << seg_size2 << endl;

            // compara tamanho de cada curva e retira aresta da menor
            if( seg_size2 < seg_size )
            {
                //cout << "seg_size maior retira aresta 7 e 0" << endl;
                SET_BIT( graph[ i2 ], 7, 0 );
                SET_BIT( graph[ i3 ], 0, 0 );
            }
            else
            {
                //cout << "seg_size2 maior retira aresta 2 e 5" << endl;
                SET_BIT( graph[ i1 ], 2, 0 );
                SET_BIT( graph[ i4 ], 5, 0 );
            }
        }
    }
}


__device__ int processHeuristics22( char* graph, int i, int j, int width, int height, char nodeResult )
{
    int seg_size = 0;
    int seg_size2 = 0;

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );


    // Both edges are
//    if ((checkValence2Edge(graph, i1, i4, 2, 5)) && (checkValence2Edge(graph, i3, i2, 0, 7)))
//    {

//    } else {
    /* Just i1-i4 edge is valence 2 */
    /*  i2  /i4
           /
        i1/  i3  */
    //if (checkValence2Edge(graph, i1, i4, 2, 5)){
    if( checkValence2EdgeGPU( graph, i, j, i + 1, j + 1, width, 2, 5, nodeResult ) )
    {
        /* Remove i2-i3 edge */
        return false;
    }
    else
    /* Just i2-i3 edge is valence 2 */
    /*  i2\  i4
           \
        i1  \i3  */
    //if(checkValence2Edge(graph, i3, i2, 0, 7)){
    if( checkValence2EdgeGPU( graph, i + 1, j, i, j + 1, width, 0, 7, 255 ) )
    {
        /* Remove i1-i4 edge */
        return true;
    }
    else
    /* Island Heuristic */
    if( ( ( checkValence2VertexGPU( graph, i1, 2, nodeResult ) ) || ( checkValence2Vertex( graph, i4, 5 ) ) ) &&
        ( !( checkValence2Vertex( graph, i3, 0 ) ) ) && ( !( checkValence2Vertex( graph, i2, 7 ) ) ) )
    {
        return false;
    }
    else
    /* Island Heuristic */
    if( ( checkValence2Vertex( graph, i3, 0 ) ) || ( checkValence2Vertex( graph, i2, 7 ) ) &&
        ( !( checkValence2VertexGPU( graph, i1, 2, nodeResult ) ) ) && ( !( checkValence2Vertex( graph, i4, 5 ) ) ) )
    {
        return true;
    }
    else
    {
        // Calcula tamanho partindo da aresta 2 de i1 e partindo da aresta 5 de i4. Depois soma

        //usleep(5000 * 1000);
        calcVal2PathSize( graph, i1, 2, seg_size, width );

        calcVal2PathSize( graph, i4, 5, seg_size, width );
        //cout << "i1 seg_size total: " << seg_size << endl;


        // Calcula tamanho partindo da aresta 0 de i3 e partindo de 7 da aresta i2. Depois soma

        //usleep(5000 * 1000);
        calcVal2PathSize( graph, i3, 0, seg_size2, width );

        calcVal2PathSize( graph, i2, 7, seg_size2, width );
        //cout << "  i3 seg_size total: " << seg_size2 << endl;

        // compara tamanho de cada curva e retira aresta da menor
        if( seg_size2 < seg_size )
        {
            //cout << "seg_size maior retira aresta 7 e 0" << endl;
            return false;
        }
        else
        {
            //cout << "seg_size2 maior retira aresta 2 e 5" << endl;
            return true;
        }


        // Link can't be solved with this four nodes
        //if ( (seg_size == 0) && (seg_size2 == 0) )
        //{
        //crossCheck_Neighbors(graph, i, j, width, height);
        //}
    }
    //}
}


__device__ int processHeuristics2( char* graph, int i, int j, int width, int height )
{
    int seg_size = 0;
    int seg_size2 = 0;

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );


    // Both edges are
//    if ((checkValence2Edge(graph, i1, i4, 2, 5)) && (checkValence2Edge(graph, i3, i2, 0, 7)))
//    {

//    } else {
    /* Just i1-i4 edge is valence 2 */
    /*  i2  /i4
           /
        i1/  i3  */
    if( checkValence2Edge( graph, i1, i4, 2, 5 ) )
    {
        /* Remove i2-i3 edge */
        return false;
    }
    else
    /* Just i2-i3 edge is valence 2 */
    /*  i2\  i4
           \
        i1  \i3  */
    if( checkValence2Edge( graph, i3, i2, 0, 7 ) )
    {
        /* Remove i1-i4 edge */
        return true;
    }
    else
    /* Island Heuristic */
    if( ( ( checkValence2Vertex( graph, i1, 2 ) ) || ( checkValence2Vertex( graph, i4, 5 ) ) ) &&
        ( !( checkValence2Vertex( graph, i3, 0 ) ) ) && ( !( checkValence2Vertex( graph, i2, 7 ) ) ) )
    {
        return false;
    }
    else
    /* Island Heuristic */
    if( ( checkValence2Vertex( graph, i3, 0 ) ) || ( checkValence2Vertex( graph, i2, 7 ) ) &&
        ( !( checkValence2Vertex( graph, i1, 2 ) ) ) && ( !( checkValence2Vertex( graph, i4, 5 ) ) ) )
    {
        return true;
    }
    else
    {
        // Calcula tamanho partindo da aresta 2 de i1 e partindo da aresta 5 de i4. Depois soma

        //usleep(5000 * 1000);
        calcVal2PathSize( graph, i1, 2, seg_size, width );

        calcVal2PathSize( graph, i4, 5, seg_size, width );
        //cout << "i1 seg_size total: " << seg_size << endl;


        // Calcula tamanho partindo da aresta 0 de i3 e partindo de 7 da aresta i2. Depois soma

        //usleep(5000 * 1000);
        calcVal2PathSize( graph, i3, 0, seg_size2, width );

        calcVal2PathSize( graph, i2, 7, seg_size2, width );
        //cout << "  i3 seg_size total: " << seg_size2 << endl;

        // compara tamanho de cada curva e retira aresta da menor
        if( seg_size2 < seg_size )
        {
            //cout << "seg_size maior retira aresta 7 e 0" << endl;
            return false;
        }
        else
        {
            //cout << "seg_size2 maior retira aresta 2 e 5" << endl;
            return true;
        }


        // Link can't be solved with this four nodes
        //if( ( seg_size == 0 ) && ( seg_size2 == 0 ) )
        //{
            //crossCheck_Neighbors(graph, i, j, width, height);
        //}
    }
    //}
}


//__device__ int processHeuristicsNeighbors(char* graph, int i, int j, int width, int height){
//    int seg_size = 0;
//    int seg_size2 = 0;

//    int i1 = (j*width + i);
//    int i2 = ((j+1)*width + i);
//    int i3 = (j*width + i+1);
//    int i4 = ((j+1)*width + i+1);

//    int i0 = ((j+1)*width + i-1);
//    int i1 = ((j+1)*width + i);
//    int i2 = ((j+1)*width + i+1);
//    int i3 = ((j)*width + i-1);
//    int i4 = ((j)*width + i+1);
//    int i5 = ((j-1)*width + i-1);
//    int i6 = ((j-1)*width + i);
//    int i7 = ((j-1)*width + i+1);


//    // Both edges are
////    if ((checkValence2Edge(graph, i1, i4, 2, 5)) && (checkValence2Edge(graph, i3, i2, 0, 7)))
////    {

////    } else {
//        /* Just i1-i4 edge is valence 2 */
//        /*  i2  /i4
//               /
//            i1/  i3  */
//        if (checkValence2Edge(graph, i1, i4, 2, 5)){
//            /* Remove i2-i3 edge */
//            return false;
//        } else
//            /* Just i2-i3 edge is valence 2 */
//            /*  i2\  i4
//                   \
//                i1  \i3  */
//            if(checkValence2Edge(graph, i3, i2, 0, 7)){
//                /* Remove i1-i4 edge */
//                return true;
//            } else
//                /* Island Heuristic */
//                if( ( (checkValence2Vertex(graph, i1, 2)) || (checkValence2Vertex(graph, i4, 5)) ) &&
//                        (!(checkValence2Vertex(graph, i3, 0))) && (!(checkValence2Vertex(graph, i2, 7))) ){
//                    return false;
//                } else
//                    /* Island Heuristic */
//                    if( (checkValence2Vertex(graph, i3, 0)) || (checkValence2Vertex(graph, i2, 7)) &&
//                            (!(checkValence2Vertex(graph, i1, 2))) && (!(checkValence2Vertex(graph, i4, 5))) ){
//                        return true;
//                    } else {

//            // Calcula tamanho partindo da aresta 2 de i1 e partindo da aresta 5 de i4. Depois soma

//            //usleep(5000 * 1000);
//            calcVal2PathSize(graph, i1, 2, seg_size, width);

//            calcVal2PathSize(graph, i4, 5, seg_size, width);
//            //cout << "i1 seg_size total: " << seg_size << endl;


//            // Calcula tamanho partindo da aresta 0 de i3 e partindo de 7 da aresta i2. Depois soma

//            //usleep(5000 * 1000);
//            calcVal2PathSize(graph, i3, 0, seg_size2, width);

//            calcVal2PathSize(graph, i2, 7, seg_size2, width);
//            //cout << "  i3 seg_size total: " << seg_size2 << endl;

//            // compara tamanho de cada curva e retira aresta da menor
//            if (seg_size2 < seg_size)
//            {
//                //cout << "seg_size maior retira aresta 7 e 0" << endl;
//                return false;
//            } else
//            {
//                //cout << "seg_size2 maior retira aresta 2 e 5" << endl;
//                return true;
//            }
//        }
//    //}

//}

//__device__ char crossCheck_Neighbors(char* graph, int width, int height, int i, int j)
//{
//    char node = graph[index];
//    int x = i; int y = j;

//    int index = (y*width + x);

//    int i0 = ((j+1)*width + i-1);
//    int i1 = ((j+1)*width + i);
//    int i2 = ((j+1)*width + i+1);
//    int i3 = ((j)*width + i-1);
//    int i4 = ((j)*width + i+1);
//    int i5 = ((j-1)*width + i-1);
//    int i6 = ((j-1)*width + i);
//    int i7 = ((j-1)*width + i+1);



//    if ( (CHECK_BIT(graph[i3],2)) &&
//         (CHECK_BIT(graph[i0],7)) &&
//         (CHECK_BIT(graph[index],0)) &&
//         (CHECK_BIT(graph[i1],5)) )
//    {
//        if (!(processHeuristics2(graph, i-1, j, width, height)) )
//            SET_BIT(node, 0, 0);
//    }

//    if ( (CHECK_BIT(graph[i5],2)) &&
//         (CHECK_BIT(graph[i3],7)) &&
//         (CHECK_BIT(graph[i6],0)) &&
//         (CHECK_BIT(graph[index],5)) )
//    {
//        if (processHeuristics2(graph, i-1, j-1, width, height))
//            SET_BIT(node, 5, 0);
//    }

//    if ( (CHECK_BIT(graph[i6],2)) &&
//         (CHECK_BIT(graph[index],7)) &&
//         (CHECK_BIT(graph[i7],0)) &&
//         (CHECK_BIT(graph[i4],5)) )
//    {
//        if (!(processHeuristics2(graph, i, j-1, width, height)) )
//            SET_BIT(node, 7, 0);
//    }

//    if ( (CHECK_BIT(graph[index],2)) &&
//         (CHECK_BIT(graph[i1],7)) &&
//         (CHECK_BIT(graph[i4],0)) &&
//         (CHECK_BIT(graph[i2],5)) )
//    {
//        if (processHeuristics2(graph, i, j, width, height))
//            SET_BIT(node, 2, 0);
//    }

//    return node;
//}

/* Verifica ambiguidade de aresta cruzada nos quatro vizinhos da diagonal e tira só as arestas do nó interior "index" */
/* Maneira de resolver problema de concorrência */
__device__ void processHeuristicsCases( char* graph, int j, int i, int width, int height )
{
    //   +----+----+----+
    //   |    |    |    |
    //   | i2 |    | i3 |
    //   +----+----+----+
    //   |    |    |    |
    //   |    | i  |    |
    //   +----+----+----+
    //   |    |    |    |
    //   | i1 |    | i4 |
    //   +----+----+----+

    //int index = ( ( i ) * width - j );
    //int i1 = ((i - 1) * width + (j - 1));
    //int i2 = ((i + 1) * width + (j - 1));
    //int i3 = ((i - 1) * width + (j + 1));
    //int i4 = ((i + 1) * width + (j + 1));

    //if (processHeuristics2(graph, j-1, i-1, width, height))
    //    SET_BIT(index, 5, 0);
    //if (processHeuristics2(graph, j-1, i+1, width, height))
    //    SET_BIT(index, 0, 0);
    //if (processHeuristics2(graph, j+1, i-1, width, height))
    //    SET_BIT(index, 2, 0);
    //if (processHeuristics2(graph, j+1, i+1, width, height))
    //    SET_BIT(index, 7, 0);
}


/* Change edges according to heuristics */
__device__ void crossCheck( char* graph, int width, int height, int i, int j )
{
    for( int i = 0; i < height; i++ )
    {
        for( int j = 0; j < width; j++ )
        {
            /*    i2 --- i4
                  |      |
                  i1 --- i3    */

            int i1 = ( i * width + j );
            int i2 = ( ( i + 1 ) * width + j );
            int i3 = ( i * width + j + 1 );
            int i4 = ( ( i + 1 ) * width + j + 1 );

            // Checa se blocos 2x2 estão totalmente conectados

            /* Checa se blocos 2x2 estão totalmente conectados */

            /*  3--- i2 ---(4)   (3)--- i4 ---4
                    / | \              / | \
                   /  |  \            /  |  \
                  5  (6)  7          5  (6)  7


                  0  (1)   2         0  (1)   2
                   \  |   /           \  |   /
                    \ |  /             \ |  /
                 3--- i1 ---(4)   (3)--- i3 ---4         */

            if( ( CHECK_BIT( graph[ i1 ], 1 ) ) && ( CHECK_BIT( graph[ i1 ], 4 ) ) &&
                ( CHECK_BIT( graph[ i2 ], 6 ) ) && ( CHECK_BIT( graph[ i2 ], 4 ) ) &&
                ( CHECK_BIT( graph[ i3 ], 3 ) ) && ( CHECK_BIT( graph[ i3 ], 1 ) ) &&
                ( CHECK_BIT( graph[ i4 ], 6 ) ) && ( CHECK_BIT( graph[ i4 ], 3 ) ) )
            {
                //cvCircle( graph_img, cvPoint(n_j+half_sg,n_i+half_sg), 3, CV_RGB( 0,  0, 0 ), CV_FILLED, 8, 0 );
                //remove arestas cruzadas
                SET_BIT( graph[ i1 ], 2, 0 );
                SET_BIT( graph[ i2 ], 7, 0 );
                SET_BIT( graph[ i3 ], 0, 0 );
                SET_BIT( graph[ i4 ], 5, 0 );
            }
            // Checa pelas arestas cruzadas

            /*  3--- i2 ---4        3--- i4 ---4
                    / | \              / | \
                   /  |  \            /  |  \
                  5   6   (7)       (5)  6   7


                  0   1   (2)       (0)  1    2
                   \  |   /           \  |   /
                    \ |  /             \ |  /
                 3--- i1 ---4       3--- i3 ---4         */

            if( ( CHECK_BIT( graph[ i1 ], 2 ) ) &&
                ( CHECK_BIT( graph[ i2 ], 7 ) ) &&
                ( CHECK_BIT( graph[ i3 ], 0 ) ) &&
                ( CHECK_BIT( graph[ i4 ], 5 ) ) )
            {
                processHeuristics( graph, j, i, width, height );
            }
        }
    }
}


/* Change edges according to heuristics */
__device__ void crossCheck_2( char* graph, int width, int height, int i, int j )
{
    /*    i2 --- i4
          |      |
          i1 --- i3    */

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );

    // Checa se blocos 2x2 estão totalmente conectados

    /* Checa se blocos 2x2 estão totalmente conectados */

    /*  3--- i2 ---(4)   (3)--- i4 ---4
            / | \              / | \
           /  |  \            /  |  \
          5  (6)  7          5  (6)  7


          0  (1)   2         0  (1)   2
           \  |   /           \  |   /
            \ |  /             \ |  /
         3--- i1 ---(4)   (3)--- i3 ---4         */

    if( ( CHECK_BIT( graph[ i1 ], 1 ) ) && ( CHECK_BIT( graph[ i1 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i2 ], 6 ) ) && ( CHECK_BIT( graph[ i2 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i3 ], 3 ) ) && ( CHECK_BIT( graph[ i3 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i4 ], 6 ) ) && ( CHECK_BIT( graph[ i4 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ i1 ], 2, 0 );
        SET_BIT( graph[ i2 ], 7, 0 );
        SET_BIT( graph[ i3 ], 0, 0 );
        SET_BIT( graph[ i4 ], 5, 0 );
    }
}


/* Change edges according to heuristics */
__device__ void crossCheck_3( char* graph, int width, int height, int i, int j )
{
    /*    i2 --- i4
          |      |
          i1 --- i3    */

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );

    int i5 = ( ( j + 1 ) * width + i );
    int i6 = ( ( j + 2 ) * width + i );
    int i7 = ( ( j + 1 ) * width + i + 1 );
    int i8 = ( ( j + 2 ) * width + i + 1 );

    int i9 = ( j * width + i + 1 );
    int i10 = ( ( j + 1 ) * width + i + 1 );
    int i11 = ( j * width + i + 2 );
    int i12 = ( ( j + 1 ) * width + i + 2 );

    int i13 = ( ( j + 1 ) * width + i + 1 );
    int i14 = ( ( j + 2 ) * width + i + 1 );
    int i15 = ( ( j + 1 ) * width + i + 2 );
    int i16 = ( ( j + 2 ) * width + i + 2 );

    // Checa se blocos 2x2 estão totalmente conectados

    /* Checa se blocos 2x2 estão totalmente conectados */

    /*  3--- i2 ---(4)   (3)--- i4 ---4
            / | \              / | \
           /  |  \            /  |  \
          5  (6)  7          5  (6)  7


          0  (1)   2         0  (1)   2
           \  |   /           \  |   /
            \ |  /             \ |  /
         3--- i1 ---(4)   (3)--- i3 ---4         */

    if( ( CHECK_BIT( graph[ i1 ], 1 ) ) && ( CHECK_BIT( graph[ i1 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i2 ], 6 ) ) && ( CHECK_BIT( graph[ i2 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i3 ], 3 ) ) && ( CHECK_BIT( graph[ i3 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i4 ], 6 ) ) && ( CHECK_BIT( graph[ i4 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ i4 ], 5, 0 );
    }
    if( ( CHECK_BIT( graph[ i5 ], 1 ) ) && ( CHECK_BIT( graph[ i5 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i6 ], 6 ) ) && ( CHECK_BIT( graph[ i6 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i7 ], 3 ) ) && ( CHECK_BIT( graph[ i7 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i8 ], 6 ) ) && ( CHECK_BIT( graph[ i8 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ i6 ], 7, 0 );
    }
    if( ( CHECK_BIT( graph[ i9 ], 1 ) ) && ( CHECK_BIT( graph[ i9 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i10 ], 6 ) ) && ( CHECK_BIT( graph[ i10 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i11 ], 3 ) ) && ( CHECK_BIT( graph[ i11 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i12 ], 6 ) ) && ( CHECK_BIT( graph[ i12 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ i11 ], 0, 0 );
    }
    if( ( CHECK_BIT( graph[ i13 ], 1 ) ) && ( CHECK_BIT( graph[ i13 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i14 ], 6 ) ) && ( CHECK_BIT( graph[ i14 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i15 ], 3 ) ) && ( CHECK_BIT( graph[ i15 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i16 ], 6 ) ) && ( CHECK_BIT( graph[ i16 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ i6 ], 5, 0 );
    }
}


/* Change edges according to heuristics */
__device__ void crossCheck_4( char* graph, int width, int height, int i, int j )
{
    int index = ( j * width + i );

    int i0 = ( ( j - 1 ) * width + i - 1 );
    int i1 = ( ( j ) * width + i - 1 );
    int i2 = ( ( j + 1 ) * width + i - 1 );
    int i3 = ( ( j - 1 ) * width + i );
    int i4 = ( ( j + 1 ) * width + i );
    int i5 = ( ( j - 1 ) * width + i + 1 );
    int i6 = ( ( j ) * width + i + 1 );
    int i7 = ( ( j + 1 ) * width + i + 1 );

    // Checa se blocos 2x2 estão totalmente conectados

    /* Checa se blocos 2x2 estão totalmente conectados */

    /*  3--- i2 ---(4)   (3)--- i4 ---4
            / | \              / | \
           /  |  \            /  |  \
          5  (6)  7          5  (6)  7


          0  (1)   2         0  (1)   2
           \  |   /           \  |   /
            \ |  /             \ |  /
         3--- i1 ---(4)   (3)--- i3 ---4         */

    if( ( CHECK_BIT( graph[ i1 ], 1 ) ) && ( CHECK_BIT( graph[ i1 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i2 ], 6 ) ) && ( CHECK_BIT( graph[ i2 ], 4 ) ) &&
        ( CHECK_BIT( graph[ index ], 3 ) ) && ( CHECK_BIT( graph[ index ], 1 ) ) &&
        ( CHECK_BIT( graph[ i4 ], 6 ) ) && ( CHECK_BIT( graph[ i4 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ index ], 0, 0 );
    }

    if( ( CHECK_BIT( graph[ index ], 1 ) ) && ( CHECK_BIT( graph[ index ], 4 ) ) &&
        ( CHECK_BIT( graph[ i4 ], 6 ) ) && ( CHECK_BIT( graph[ i4 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i6 ], 3 ) ) && ( CHECK_BIT( graph[ i6 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i7 ], 6 ) ) && ( CHECK_BIT( graph[ i7 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ index ], 2, 0 );
    }

    if( ( CHECK_BIT( graph[ i0 ], 1 ) ) && ( CHECK_BIT( graph[ i0 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i1 ], 6 ) ) && ( CHECK_BIT( graph[ i1 ], 4 ) ) &&
        ( CHECK_BIT( graph[ i3 ], 3 ) ) && ( CHECK_BIT( graph[ i3 ], 1 ) ) &&
        ( CHECK_BIT( graph[ index ], 6 ) ) && ( CHECK_BIT( graph[ index ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ index ], 5, 0 );
    }

    if( ( CHECK_BIT( graph[ i3 ], 1 ) ) && ( CHECK_BIT( graph[ i3 ], 4 ) ) &&
        ( CHECK_BIT( graph[ index ], 6 ) ) && ( CHECK_BIT( graph[ index ], 4 ) ) &&
        ( CHECK_BIT( graph[ i5 ], 3 ) ) && ( CHECK_BIT( graph[ i5 ], 1 ) ) &&
        ( CHECK_BIT( graph[ i6 ], 6 ) ) && ( CHECK_BIT( graph[ i6 ], 3 ) ) )
    {
        //remove arestas cruzadas
        SET_BIT( graph[ index ], 7, 0 );
    }
}


/* Return true if all nodes of the crossing edges are not valence 2 */
__device__ bool check_neighboord( char* graph, int i, int j, int width )
{
    /*  i2   i4

        i1   i3  */

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );

    if( !checkVertexV2( graph, i1, 2 )
        && !checkVertexV2( graph, i2, 7 )
        && !checkVertexV2( graph, i3, 0 )
        && !checkVertexV2( graph, i4, 5 ) )
    {
        return true;
    }
    else
    {
        return false;
    }
}


/**
 * @brief processHeuristics             Process heuristics to improve graph result
 * @param j                             Coordinate j - x axis
 * @param i                             Coordinate i - y axis
 */
__device__ void processHeuristicsWindow( char* matrix, int i, int j, int width )
{
    int seg_size = 0;
    int seg_size2 = 0;

    int i1 = ( j * width + i );
    int i2 = ( ( j + 1 ) * width + i );
    int i3 = ( j * width + i + 1 );
    int i4 = ( ( j + 1 ) * width + i + 1 );

    // Both edges are
//    if ((checkValence2Edge(i1, i4, 2, 5)) && (checkValence2Edge(i3, i2, 0, 7)))
//    {

//    } else {
    /* Just i1-i4 edge is valence 2 */
    /*  i2  /i4
           /
        i1/  i3  */
    if( ( checkValence2Edge( matrix, i1, i4, 2, 5 ) ) && !( checkValence2Edge( matrix, i3, i2, 0, 7 ) ) )
    {
        /* Remove i2-i3 edge */
        SET_BIT( matrix[ i2 ], 7, 0 );
        SET_BIT( matrix[ i3 ], 0, 0 );
    }
    else
    /* Just i2-i3 edge is valence 2 */
    /*  i2\  i4
           \
        i1  \i3  */
    if( ( checkValence2Edge( matrix, i3, i2, 0, 7 ) ) && !( checkValence2Edge( matrix, i1, i4, 2, 5 ) ) )
    {
        /* Remove i1-i4 edge */
        SET_BIT( matrix[ i1 ], 2, 0 );
        SET_BIT( matrix[ i4 ], 5, 0 );
    }
    else
    /* Island Heuristic */
    if( ( ( checkValence2Vertex( matrix, i1, 2 ) ) || ( checkValence2Vertex( matrix, i4, 5 ) ) ) &&
        ( !( checkValence2Vertex( matrix, i3, 0 ) ) ) && ( !( checkValence2Vertex( matrix, i2, 7 ) ) ) )
    {
        SET_BIT( matrix[ i2 ], 7, 0 );
        SET_BIT( matrix[ i3 ], 0, 0 );
    }
    else
    /* Island Heuristic */
    if( ( checkValence2Vertex( matrix, i3, 0 ) ) || ( checkValence2Vertex( matrix, i2, 7 ) ) &&
        ( !( checkValence2Vertex( matrix, i1, 2 ) ) ) && ( !( checkValence2Vertex( matrix, i4, 5 ) ) ) )
    {
        SET_BIT( matrix[ i1 ], 2, 0 );
        SET_BIT( matrix[ i4 ], 5, 0 );
    }
    else
    {
        // Calcula tamanho partindo da aresta 2 de i1 e partindo da aresta 5 de i4. Depois soma

        //usleep(5000 * 1000);
        calcVal2PathSize( matrix, i1, 2, seg_size, width );

        calcVal2PathSize( matrix, i4, 5, seg_size, width );
        //cout << "i1 seg_size total: " << seg_size << endl;


        // Calcula tamanho partindo da aresta 0 de i3 e partindo de i2 da aresta 0. Depois soma

        //usleep(5000 * 1000);
        calcVal2PathSize( matrix, i3, 0, seg_size2, width );

        calcVal2PathSize( matrix, i2, 7, seg_size2, width );
        //cout << "  i3 seg_size total: " << seg_size2 << endl;

        // compara tamanho de cada curva e retira aresta da menor
        if( seg_size2 < seg_size )
        {
            //cout << "seg_size maior retira aresta 7 e 0" << endl;
            SET_BIT( matrix[ i2 ], 7, 0 );
            SET_BIT( matrix[ i3 ], 0, 0 );
        }
        else
        {
            //cout << "seg_size2 maior retira aresta 2 e 5" << endl;
            SET_BIT( matrix[ i1 ], 2, 0 );
            SET_BIT( matrix[ i4 ], 5, 0 );
        }
    }
    //}
}


__device__ char crossCheck_Window( char* graph, int width, int i, int j )
{
    const int WIN_SIZE = 49;
    const int WIN_WIDTH = 7;
    char graphWindow[ WIN_SIZE ];

    for( int j_ = 0; j_ < WIN_WIDTH; j_++ )
    {
        for( int i_ = 0; i_ < WIN_WIDTH; i_++ )
        {
            /* WIN_WIDTH x WIN_WIDTH window - offset (WIN_WIDTH-1)/2 to center i,j */
            graphWindow[ j_ * WIN_WIDTH +
                         i_ ] =
                graph[ ( ( j - ( WIN_WIDTH - 1 ) / 2 ) + j_ ) * width + ( ( i - ( WIN_WIDTH - 1 ) / 2 ) + i_ ) ];
        }
    }

    for( int j_ = 0; j_ < ( WIN_WIDTH - 1 ); j_++ )
    {
        for( int i_ = 0; i_ < ( WIN_WIDTH - 1 ); i_++ )
        {
            if( ( CHECK_BIT( graphWindow[ j_ * WIN_WIDTH + i_ ], 2 ) ) &&
                ( CHECK_BIT( graphWindow[ ( j_ + 1 ) * WIN_WIDTH + i_ ], 7 ) ) &&
                ( CHECK_BIT( graphWindow[ j_ * WIN_WIDTH + i_ + 1 ], 0 ) ) &&
                ( CHECK_BIT( graphWindow[ ( j_ + 1 ) * WIN_WIDTH + i_ + 1 ], 5 ) ) )
            {
                processHeuristicsWindow( graphWindow, i_, j_, WIN_WIDTH );
            }
        }
    }

    /* return center node */
    return graphWindow[ WIN_SIZE / 2 ];
}


__device__ void crossCheck_Heuristics( char* graph, char* graph_aux, int width, int height, int i, int j,
                                       bool* flagSync )
{
    //char nodeResult = graph_aux[ j * width + i ];


    /* Nodes indexes */
    int index = ( j * width + i );

    int i0 = ( ( j + 1 ) * width + i - 1 );
    int i1 = ( ( j + 1 ) * width + i );
    int i2 = ( ( j + 1 ) * width + i + 1 );
    int i3 = ( ( j ) * width + i - 1 );
    int i4 = ( ( j ) * width + i + 1 );
    int i5 = ( ( j - 1 ) * width + i - 1 );
    int i6 = ( ( j - 1 ) * width + i );
    int i7 = ( ( j - 1 ) * width + i + 1 );


    //   Nodes Structure
    //   +----+----+----+
    //   |    |    |    |
    //   | i0 | i1 | i2 |
    //   +----+----+----+
    //   |    | in |    |
    //   | i3 | dex| i4 |
    //   +----+----+----+
    //   |    |    |    |
    //   | i5 | i6 | i7 |
    //   +----+----+----+


//    #!
//    if ( (CHECK_BIT(graph_aux[i1],2)) &&
//         (CHECK_BIT(graph_aux[i2],7)) &&
//         (CHECK_BIT(graph_aux[i3],0)) &&
//         (CHECK_BIT(graph_aux[i4],5)) )
//    {
//        processHeuristics(graph, i, j, width, height);
//    }

    /* old order and graph aux use */

    if( ( CHECK_BIT( graph_aux[ i3 ], 2 ) ) &&
        ( CHECK_BIT( graph_aux[ i0 ], 7 ) ) &&
        ( CHECK_BIT( graph_aux[ index ], 0 ) ) &&
        ( CHECK_BIT( graph_aux[ i1 ], 5 ) ) )
    {
        if( !( processHeuristics2( graph_aux, i - 1, j, width, height ) ) )
        {
            SET_BIT( graph[ index ], 0, 0 );
        }
    }

    if( ( CHECK_BIT( graph_aux[ i5 ], 2 ) ) &&
        ( CHECK_BIT( graph_aux[ i3 ], 7 ) ) &&
        ( CHECK_BIT( graph_aux[ i6 ], 0 ) ) &&
        ( CHECK_BIT( graph_aux[ index ], 5 ) ) )
    {
        if( processHeuristics2( graph_aux, i - 1, j - 1, width, height ) )
        {
            SET_BIT( graph[ index ], 5, 0 );
        }
    }

    if( ( CHECK_BIT( graph_aux[ i6 ], 2 ) ) &&
        ( CHECK_BIT( graph_aux[ index ], 7 ) ) &&
        ( CHECK_BIT( graph_aux[ i7 ], 0 ) ) &&
        ( CHECK_BIT( graph_aux[ i4 ], 5 ) ) )
    {
        if( !( processHeuristics2( graph_aux, i, j - 1, width, height ) ) )
        {
            SET_BIT( graph[ index ], 7, 0 );
        }
    }

    if( ( CHECK_BIT( graph_aux[ index ], 2 ) ) &&
        ( CHECK_BIT( graph_aux[ i1 ], 7 ) ) &&
        ( CHECK_BIT( graph_aux[ i4 ], 0 ) ) &&
        ( CHECK_BIT( graph_aux[ i2 ], 5 ) ) )
    {
        if( processHeuristics2( graph_aux, i, j, width, height ) )
        {
            SET_BIT( graph[ index ], 2, 0 );
        }
    }

//    return;

    /* Scanline order (botton-top) */

//    if ( (CHECK_BIT(graph_aux[i5],2)) &&
//         (CHECK_BIT(graph_aux[i3],7)) &&
//         (CHECK_BIT(graph_aux[i6],0)) &&
//         (CHECK_BIT(graph_aux[index], 5)) )
//    {
//        if (check_neighboord(graph_aux, i-1, j-1, width))
//        {
//            nodeResult = crossCheck_Window(graph_aux, width, i, j);
//            graph[index] = nodeResult;
//            return;
//        }
//        else
//        {
//            if (processHeuristics2(graph_aux, i-1, j-1, width, height))
//               SET_BIT(graph[index], 5, 0);
//        }
//    }

//    if ( (CHECK_BIT(graph_aux[i6],2)) &&
//         (CHECK_BIT(graph_aux[index],7)) &&
//         (CHECK_BIT(graph_aux[i7],0)) &&
//         (CHECK_BIT(graph_aux[i4],5)) )
//    {
//        if (check_neighboord(graph_aux, i, j-1, width))
//        {
//            nodeResult = crossCheck_Window(graph_aux, width, i, j);
//            graph[index] = nodeResult;
//            return;
//        }
//        else
//        {
//            if (!processHeuristics2(graph_aux, i, j-1, width, height))
//               SET_BIT(graph[index], 7, 0);
//        }
//    }

//    if ( (CHECK_BIT(graph_aux[i3],2)) &&
//         (CHECK_BIT(graph_aux[i0],7)) &&
//         (CHECK_BIT(graph_aux[index],0)) &&
//         (CHECK_BIT(graph_aux[i1],5)) )
//    {
//        if (check_neighboord(graph_aux, i-1, j, width))
//        {
//            nodeResult = crossCheck_Window(graph_aux, width, i, j);
//            graph[index] = nodeResult;
//            return;
//        }
//        else
//        {
//            if (!processHeuristics2(graph_aux, i-1, j, width, height))
//               SET_BIT(graph[index], 0, 0);
//        }
//    }

//    if ( (CHECK_BIT(graph_aux[index],2)) &&
//         (CHECK_BIT(graph_aux[i1],7)) &&
//         (CHECK_BIT(graph_aux[i4],0)) &&
//         (CHECK_BIT(graph_aux[i2],5)) )
//    {
//        if (check_neighboord(graph_aux, i, j, width))
//        {
//            nodeResult = crossCheck_Window(graph_aux, width, i, j);
//            graph[index] = nodeResult;
//            return;
//        }
//        else
//        {
//            if (processHeuristics2(graph_aux, i, j, width, height))
//               SET_BIT(graph[index], 2, 0);
//        }
//    }

    //graph[index] = nodeResult;

//    if (processHeuristics2(graph_aux, x, y, width, height))
//        SET_BIT(graph[i1], 2, 0);

//    if (!(processHeuristics2(graph_aux, x, y+1, width, height)) )
//        SET_BIT(graph[i2], 7, 0);

//    if  (!(processHeuristics2(graph_aux, x+1, y, width, height)) )
//        SET_BIT(graph[i3], 5, 0);

//    if (processHeuristics2(graph_aux, x+1, y+1, width, height))
//        SET_BIT(graph[i4], 0, 0);


//    if (processHeuristics2(graph_aux, j-1, i-1, width, height))
//        SET_BIT(graph[i1], 5, 0);
//    if (processHeuristics2(graph_aux, j-1, i+1, width, height))
//        SET_BIT(graph[i1], 0, 0);
//    if (processHeuristics2(graph_aux, j+1, i-1, width, height))
//        SET_BIT(graph[i1], 2, 0);
//    if (processHeuristics2(graph_aux, j+1, i+1, width, height))
//        SET_BIT(graph[i1], 7, 0);

//    if (processHeuristics2(graph_aux, j-1, i, width, height))
//        SET_BIT(graph[i2], 5, 0);
//    if (processHeuristics2(graph_aux, j-1, i+2, width, height))
//        SET_BIT(graph[i2], 0, 0);
//    if (processHeuristics2(graph_aux, j+1, i, width, height))
//        SET_BIT(graph[i2], 2, 0);
//    if (processHeuristics2(graph_aux, j+1, i+2, width, height))
//        SET_BIT(graph[i2], 7, 0);

//    if (processHeuristics2(graph_aux, j, i-1, width, height))
//        SET_BIT(graph[i3], 5, 0);
//    if (processHeuristics2(graph_aux, j, i+1, width, height))
//        SET_BIT(graph[i3], 0, 0);
//    if (processHeuristics2(graph_aux, j+2, i-1, width, height))
//        SET_BIT(graph[i3], 2, 0);
//    if (processHeuristics2(graph_aux, j+2, i+1, width, height))
//        SET_BIT(graph[i3], 7, 0);

//    if (processHeuristics2(graph_aux, j, i, width, height))
//        SET_BIT(graph[i4], 5, 0);
//    if (processHeuristics2(graph_aux, j, i+2, width, height))
//        SET_BIT(graph[i4], 0, 0);
//    if (processHeuristics2(graph_aux, j+2, i, width, height))
//        SET_BIT(graph[i4], 2, 0);
//    if (processHeuristics2(graph_aux, j+2, i+2, width, height))
//        SET_BIT(graph[i4], 7, 0);
}


///* Change edges according to heuristics */
//__device__ bool crossCheck(char* graph, int width, int height, int i, int j){

//    for(int i = 0 ; i < height ; i++ ) {
//        for(int j = 0 ; j < width ; j++ ) {

//            /*    i2 --- i4
//                  |      |
//                  i1 --- i3    */

//            int i1 = (i*width + j);
//            int i2 = ((i+1)*width + j);
//            int i3 = (i*width + j+1);
//            int i4 = ((i+1)*width + j+1);

//            // Checa se blocos 2x2 estão totalmente conectados

//            /* Checa se blocos 2x2 estão totalmente conectados */

//            /*  3--- i2 ---(4)   (3)--- i4 ---4
//                    / | \              / | \
//                   /  |  \            /  |  \
//                  5  (6)  7          5  (6)  7


//                  0  (1)   2         0  (1)   2
//                   \  |   /           \  |   /
//                    \ |  /             \ |  /
//                 3--- i1 ---(4)   (3)--- i3 ---4         */

//            if ( (CHECK_BIT(graph[i1],1)) && (CHECK_BIT(graph[i1],4)) &&
//                 (CHECK_BIT(graph[i2],6)) && (CHECK_BIT(graph[i2],4)) &&
//                 (CHECK_BIT(graph[i3],3)) && (CHECK_BIT(graph[i3],1)) &&
//                 (CHECK_BIT(graph[i4],6)) && (CHECK_BIT(graph[i4],3)) )
//            {
//                SET_BIT(graph[i1],2,0);
//                SET_BIT(graph[i2],7,0);
//                SET_BIT(graph[i3],0,0);
//                SET_BIT(graph[i4],5,0);
//            } else {
//                return false;
//            }

//        }
//    }
//}

///* Change edges according to heuristics */
//__device__ void removeCross(char* graph, int width, int height, int i, int j){

////    for(int i = 0 ; i < height ; i++ ) {
////        for(int j = 0 ; j < width ; j++ ) {

//            /*    i2 --- i4
//                  |      |
//                  i1 --- i3    */

//            int i1 = (i*width + j);
//            int i2 = ((i+1)*width + j);
//            int i3 = (i*width + j+1);
//            int i4 = ((i+1)*width + j+1);

//            // Checa se blocos 2x2 estão totalmente conectados

//            /* Checa se blocos 2x2 estão totalmente conectados */

//            /*  3--- i2 ---(4)   (3)--- i4 ---4
//                    / | \              / | \
//                   /  |  \            /  |  \
//                  5  (6)  7          5  (6)  7


//                  0  (1)   2         0  (1)   2
//                   \  |   /           \  |   /
//                    \ |  /             \ |  /
//                 3--- i1 ---(4)   (3)--- i3 ---4         */

//            SET_BIT(graph[i1],2,0);
//            SET_BIT(graph[i2],7,0);
//            SET_BIT(graph[i3],0,0);
//            SET_BIT(graph[i4],5,0);

////        }
////    }
//}
