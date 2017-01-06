//#include <cuda.h>

/** Check bit value */
#define CHECK_BIT(var,pos) ((var) & (1<<(pos)))

/** Clean bit then set */
#define SET_BIT(var,pos,data) var &= ~(1 << pos); var |= data << pos

#define Ymask 0x00FF0000
#define Umask 0x0000FF00
#define Vmask 0x000000FF
/* Original trY  */
#define trY   0x00300000
/* Better value when not using Splines with difusion (Empirical value) */
//#define trY   0x00050000
#define trU   0x00000700
#define trV   0x00000006

#define RGBA  0x00000000

#define PIXEL(i, j, width, n_channels) ((j*(n_channels*width))+(i*n_channels))

// Retorna posição do bit da aresta da célula vizinha
__device__ int conected_edge(int edge)
{
    return (8-1)-edge;

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
__device__ int calc_index(int index, int edge, int width)
{
    //int result;
    switch(edge)
    {
    case 0: return index + width - 1;
    case 1: return index + width;
    case 2: return index + width + 1;
    case 3: return index - 1;
    case 4: return index + 1;
    case 5: return index - width - 1;
    case 6: return index - width;
    case 7: return index - width + 1;
    }
    //return result;
}

/* Initalize RGB to YUV lookup table */
__device__ unsigned int RGBtoYUV(int c)
{
    int r, g, b, y, u, v;

    r = (c & 0x0000FF);
    g = (c & 0x00FF00) >> 8;
    b = (c & 0xFF0000) >> 16 ;
    //r = (c & 0xFF0000) >> 16;
    //g = (c & 0x00FF00) >> 8;
    //b = c & 0x0000FF;
    y = int((0.299*float(r) + 0.587*float(g) + 0.114*float(b)));
    //u = (unsigned int)(-0.169*r - 0.331*g + 0.5*b) + 128; //Cb
    //v = (unsigned int)(0.5*r - 0.419*g - 0.081*b) + 128;  //Cr
    u = int(((b - y) * 0.492f));
    v = int(((r - y) * 0.877f));


    return (unsigned int)((y << 16) + (u << 8) + v);

}

/* Convert value to int type */
__device__ unsigned int DATAtoINT(unsigned int r,unsigned int g,unsigned int b){

    unsigned int result;

    /* R_ = xxxx xxxx xxxx xxxx xxxx xxxx RRRR RRRR*/
    unsigned int R_ = (unsigned int) r;

    /* G_ = xxxx xxxx xxxx xxxx GGGG GGGG xxxx xxxx*/
    unsigned int G_ = (unsigned int) g << 8;

    /* B_ = xxxx xxxx BBBB BBBB xxxx xxxx rrrr rrrr*/
    unsigned int B_ = (unsigned int) b << 16;
    //unsigned int A_ = 0x00FFFFFF;


    /* R_ = 0000 0000 0000 0000 0000 0000 RRRR RRRR*/
    R_ &= 0x000000FF;

    /* G_ = 0000 0000 0000 0000 GGGG GGGG 0000 0000*/
    G_ = (G_ & 0x0000FF00);

    /* B_ = 0000 0000 BBBB BBBB 0000 0000 0000 0000*/
    B_ = (B_ & 0x00FF0000);


    /* result = 0000 0000 BBBB BBBB GGGG GGGG RRRR RRRR*/
    result = ((R_|G_|B_));

    return result;
}

int __device__ abs_(int a){
    if (a < 0)
        return (-1 * a);
}

__device__ int diff(int w,int h, int pos, int width, int height, char* pixel_data){
    int result;
    unsigned int   YUV1;
    unsigned int   YUV2;

    /* Pixels colors in RGB to be converted */
    char* pixel_src, *pixel_dst;

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

    pixel_src = &(pixel_data[PIXEL(w, h, width, 3)]);

    // __DEBUG__
//    printf("w: %d, h: %d, pos: %d\n", w, h, pos);
//    printf("pixel_src[0]: %d\n", (unsigned char) pixel_src[0]);
//    printf("pixel_src[1]: %d\n", (unsigned char) pixel_src[1]);
//    printf("pixel_src[2]: %d\n", (unsigned char) pixel_src[2]);

    pixel_src_YUV = DATAtoINT(pixel_src[0], pixel_src[1], pixel_src[2]);

    switch (pos){
    case 0:
        n_w = (w-1); n_h = (h+1);
        break;
    case 1:
        n_w = (w); n_h = (h+1);
        break;
    case 2:
        n_w = (w+1); n_h = (h+1);
        break;
    case 3:
        n_w = (w-1); n_h = (h);
        break;
    case 4:
        n_w = (w+1); n_h = (h);
        break;
    case 5:
        n_w = (w-1); n_h = (h-1);
        break;
    case 6:
        n_w = (w); n_h = (h-1);
        break;
    case 7:
        n_w = (w+1); n_h = (h-1);
        break;
    }


    //cuPrintf("pos: %d, n_w: %d, n_h: %d\n", pos, n_w, n_h);


    //index = n_h*img->getWidth() + n_w;

    /* Check if index is inside image boundaries */
    //if ((index > 0) && (index < ((img->getWidth())*(img->getHeight())-1)))
    if (!((n_w < 0) || (n_h < 0) ||
            (n_w >= width) ||
            (n_h >= height) ))
    {
        pixel_dst = &(pixel_data[PIXEL(n_w, n_h, width, 3)]);

        pixel_dst_YUV = DATAtoINT(pixel_dst[0], pixel_dst[1], pixel_dst[2]);

        if ((w == 1) && (h==1)){
            //cuPrintf("pos: %d, pixel_dst[0]: %d, pixel_dst[1]: %d, pixel_dst[2]: %d\n",
            //         pos, (unsigned char) pixel_dst[0], (unsigned char) pixel_dst[1], (unsigned char) pixel_dst[2]);
        }


        /* Mask against RGB_MASK to discard the alpha channel */
        YUV1 = RGBtoYUV(pixel_src_YUV);
        YUV2 = RGBtoYUV(pixel_dst_YUV);

        if ((w == 1) && (h==1)){
//            cuPrintf("pos: %d, YUV_src: %d, YUV_dest: %d, pixel_dst_YUV[0]: %d   , pixel_dst_YUV[1]: %d   , pixel_dst_YUV[2]: %d\n",
//                     pos,
//                     (YUV1 & Ymask),
//                     (YUV2 & Ymask),
//                     ( ( YUV1 & Ymask ) - ( YUV2 & Ymask ) ),
//                     abs_( ( YUV1 & Umask ) - ( YUV2 & Umask ) ),
//                     abs_( ( YUV1 & Vmask ) - ( YUV2 & Vmask ) ));
        }

        result = ( ( fabsf((YUV1 & Ymask) - (YUV2 & Ymask)) > trY ) ||
                   ( fabsf((YUV1 & Umask) - (YUV2 & Umask)) > trU ) ||
                   ( fabsf((YUV1 & Vmask) - (YUV2 & Vmask)) > trV ) );

        /* Print function data */

        //std::cout << "index src - x: " << w << " y:  " << h << std::endl;
        //std::cout << "index dst - x: " << n_w << " y:  " << n_h << std::endl;
        //std::cout << "pos: " << pos << " - ";
        //std::cout << "results: " << result << std::endl;

        //if (result != 0) {cout << result << endl;}
        return result;
    } else {return 1;}
}

__device__ bool checkValence2Edge(char* graph, int index_1, int index_2, int edge_1, int edge_2){
    int k_n;     // last conected edge
    int sum_1 = 0;
    int sum_2 = 0; // soma de arestas conectadas além da 2
    for (int k = (edge_1 + 1); k < (edge_1 + 8); k++)
    {
        if (CHECK_BIT(graph[index_1],k%8))
        {
            sum_1++;
            k_n = k;
        }
    }
    for (int k = (edge_2 + 1); k < (edge_2 + 8); k++)
    {
        if (CHECK_BIT(graph[index_2],k%8))
        {
            sum_2++;
            k_n = k;
        }
    }
    //cout << "sum_1: " << sum_1 << endl;
    //cout << "sum_2: " << sum_2 << endl;
    if ((sum_1 == 1) && (sum_2 == 1)) return true;
    else return false;
}

/* Varre o nó para saber se existe algum outro bit ativo
   Retorna true se apenas edge_1 está ativo             */
__device__ bool checkValence2Vertex(char* graph, int index_1, int edge_1){
    int k_n;     // last conected edge
    int sum = 0; // soma de arestas conectadas além da 2
    for (int k = (edge_1 + 1); k < (edge_1 + 8); k++)
    {
        if (CHECK_BIT(graph[index_1],k%8))
        {
            sum++;
            k_n = k;
        }
    }
    //cout << sum << endl;
    if (sum == 0) return true;
    else return false;
}

/* Calculate the size of a valence-2 path starting prom index */
__device__ int calcVal2PathSize(char* graph, int index, int edge, int result, int width)
{
    int k_n; // Outra aresta quando o segmento é de valência 2
    int sum = 0;
    //switch (side){
    //    case 0: {
            // a partir de edge + 1 (edge já é conexo)
             for (int k = (edge + 1); k < (edge + 7); k++)
             {
                 if (CHECK_BIT(graph[index],k%8))
                 {
                     sum++;
                     k_n = k;
                 }
             }
             // Compare to a big number to not enter in loop
             if (result > 30) return result;
             if (sum == 1)
             {
                 result++;
                 calcVal2PathSize(graph, calc_index(index, k_n%8, width), conected_edge(k_n%8), result, width);
             } else if (sum == 0) { return result;}
             return result;
        //}
    //}
}

__device__ void processHeuristics(char* graph, int j, int i, int width, int height){
    int seg_size = 0;
    int seg_size2 = 0;

    int i1 = (i*width + j);
    int i2 = ((i+1)*width + j);
    int i3 = (i*width + j+1);
    int i4 = ((i+1)*width + j+1);

    // Both edges are
    if ((checkValence2Edge(graph, i1, i4, 2, 5)) && (checkValence2Edge(graph, i3, i2, 0, 7)))
    {

    } else {
        /* Just i1-i4 edge is valence 2 */
        /*  i2  /i4
               /
            i1/  i3  */
        if (checkValence2Edge(graph, i1, i4, 2, 5)){
            /* Remove i2-i3 edge */
            SET_BIT(graph[i2],7,0);
            SET_BIT(graph[i3],0,0);
        } else
            /* Just i2-i3 edge is valence 2 */
            /*  i2\  i4
                   \
                i1  \i3  */
            if(checkValence2Edge(graph, i3, i2, 0, 7)){
                /* Remove i1-i4 edge */
                SET_BIT(graph[i1],2,0);
                SET_BIT(graph[i4],5,0);
            } else
                if( ( (checkValence2Vertex(graph, i1, 2)) || (checkValence2Vertex(graph, i4, 5)) ) &&
                        (!(checkValence2Vertex(graph, i3, 0))) && (!(checkValence2Vertex(graph, i2, 7))) ){
                    SET_BIT(graph[i2],7,0);
                    SET_BIT(graph[i3],0,0);
                } else
                    if( (checkValence2Vertex(graph, i3, 0)) || (checkValence2Vertex(graph, i2, 7)) &&
                            (!(checkValence2Vertex(graph, i1, 2))) && (!(checkValence2Vertex(graph, i4, 5))) ){
                        SET_BIT(graph[i1],2,0);
                        SET_BIT(graph[i4],5,0);
                    } else {

            // Calcula tamanho partindo da aresta 2 de i1 e partindo da aresta 5 de i4. Depois soma

            //usleep(5000 * 1000);
            seg_size = calcVal2PathSize(graph, i1,2, 0, width);

            seg_size = seg_size + calcVal2PathSize(graph,i4, 5, 0, width);
            //cout << "i1 seg_size total: " << seg_size << endl;


            // Calcula tamanho partindo da aresta 0 de i3 e partindo de i2 da aresta 0. Depois soma

            //usleep(5000 * 1000);
            seg_size2 = calcVal2PathSize(graph,i3,0, 0, width);

            seg_size2 = seg_size2 + calcVal2PathSize(graph,i2, 7, 0, width);
            //cout << "  i3 seg_size total: " << seg_size2 << endl;

            // compara tamanho de cada curva e retira aresta da menor
            if (seg_size2 < seg_size)
            {
                //cout << "seg_size maior retira aresta 7 e 0" << endl;
                SET_BIT(graph[i2],7,0);
                SET_BIT(graph[i3],0,0);
            } else
            {
                //cout << "seg_size2 maior retira aresta 2 e 5" << endl;
                SET_BIT(graph[i1],2,0);
                SET_BIT(graph[i4],5,0);
            }
        }
    }
}


/* Change edges according to heuristics */
__device__ void crossCheck(char* graph, int width, int height){

    for(int i = 0 ; i < height ; i++ ) {
        for(int j = 0 ; j < width ; j++ ) {

            /*    i2 --- i4
                  |      |
                  i1 --- i3    */

            int i1 = (i*width + j);
            int i2 = ((i+1)*width + j);
            int i3 = (i*width + j+1);
            int i4 = ((i+1)*width + j+1);

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

            if ( (CHECK_BIT(graph[i1],1)) && (CHECK_BIT(graph[i1],4)) &&
                 (CHECK_BIT(graph[i2],6)) && (CHECK_BIT(graph[i2],4)) &&
                 (CHECK_BIT(graph[i3],3)) && (CHECK_BIT(graph[i3],1)) &&
                 (CHECK_BIT(graph[i4],6)) && (CHECK_BIT(graph[i4],3)) )
            {
                //cvCircle( graph_img, cvPoint(n_j+half_sg,n_i+half_sg), 3, CV_RGB( 0,  0, 0 ), CV_FILLED, 8, 0 );
                //remove arestas cruzadas
                SET_BIT(graph[i1],2,0);
                SET_BIT(graph[i2],7,0);
                SET_BIT(graph[i3],0,0);
                SET_BIT(graph[i4],5,0);
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

            if ( (CHECK_BIT(graph[i1],2)) &&
                 (CHECK_BIT(graph[i2],7)) &&
                 (CHECK_BIT(graph[i3],0)) &&
                 (CHECK_BIT(graph[i4],5)) )
            {
                processHeuristics(graph, j, i, width, height);
            }
        }
    }
}
