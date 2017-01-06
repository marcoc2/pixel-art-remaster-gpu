/* Functions to Extract Connected Components */


/**
 * @brief isInternalNode                Test if is a internal node
 *                                      This is a pattern of a internal node:
 *                                                 |
 *                                               __N__
 *                                                 |
 *                                      It is 0101 1010 bit order which is "90" unsigned int
 * @param value                         Node links as char value
 * @return                              TRUE if is internal node
 *                                      FALSE if is not
 */
__device__ bool isInternalNode( char value )
{
    if( ( unsigned int ) value == 90 )
    {
        return true;
    }
    else
    {
        return false;
    }
}


/**
 * @brief isIslandNode                  Test if is a island node
 *                                      A island node has no links
 *                                      It is 0000 0000 bit order which is "0" unsigned int
 * @param value                         Nodes link as char value
 * @return                              TRUE if is island node
 *                                      FALSE if is not
 */
__device__ bool isIslandNode( char value )
{
    if( ( unsigned int ) value == 0 )
    {
        return true;
    }
    else
    {
        return false;
    }
}


/**
 * @brief getRealLinkIndex           Maps to real bit order for the graph links
 *                                  0 - 7 in clockwise order
 *
 *                                       Input               Output
 *
 *                                  +----+----+----+     +----+----+----+
 *                                  |    |    |    |     |    |    |    |
 *                                  | 0  | 1  | 2  |     | 0  | 1  | 2  |
 *                                  +----+----+----+     +----+----+----+
 *                                  |    |    |    |     |    |    |    |
 *                                  | 7  | x  | 3  |     | 3  | x  | 4  |
 *                                  +----+----+----+     +----+----+----+
 *                                  |    |    |    |     |    |    |    |
 *                                  | 6  | 5  | 4  |     | 5  | 6  | 7  |
 *                                  +----+----+----+     +----+----+----+
 *
 * @param index                     Node index
 * @return                          Edge index in real bit order
 */
__device__ int getRealLinkIndex( int index )
{
    switch( index )
    {
        case 0:
            return 0;

        case 1:
            return 1;

        case 2:
            return 2;

        case 3:
            return 4;

        case 4:
            return 7;

        case 5:
            return 6;

        case 6:
            return 5;

        case 7:
            return 3;
    }

    return -1;
}


/**
 * @brief getFirstLink                  Get first active link (bit)
 * @param value                         Node links as char value
 * @return                              First active link (bit)
 */
__device__ int getFirstLink( char value )
{
    for( int e = 0; e < 8; e++ )
    {
        if( ( bool ) CHECK_BIT( value, getRealLinkIndex( e ) ) )
        {
            return getRealLinkIndex( e );
        }
    }
    /* Case not found */
    return -1;
}


__device__ bool find_int( int* list, int p, int size )
{
    for( int i = 0; i < size; i++ )
    {
        if( list[ i ] == p )
        {
            return true;
        }
    }
    return false;
}


/**
 * @brief getClockLinkIndex         Maps to clockwise bit order for the graph links
 *                                   0 - 7 in clockwise order
 *
 *                                          Input                Output
 *
 *                                      +----+----+----+     +----+----+----+
 *                                      |    |    |    |     |    |    |    |
 *                                      | 0  | 1  | 2  |     | 0  | 1  | 2  |
 *                                      +----+----+----+     +----+----+----+
 *                                      |    |    |    |     |    |    |    |
 *                                      | 3  | x  | 4  |     | 7  | x  | 3  |
 *                                      +----+----+----+     +----+----+----+
 *                                      |    |    |    |     |    |    |    |
 *                                      | 5  | 6  | 7  |     | 6  | 5  | 4  |
 *                                      +----+----+----+     +----+----+----+
 *
 * @param index                     Node index
 * @return                          Edge index in clockwise order
 */
__device__ int getClockLinkIndex( int index )
{
    switch( index )
    {
        case 0:
            return 0;

        case 1:
            return 1;

        case 2:
            return 2;

        case 4:
            return 3;

        case 7:
            return 4;

        case 6:
            return 5;

        case 5:
            return 6;

        case 3:
            return 7;
    }

    return -1;
}


/**
 * @brief isValence1                    Verify if node is valence 1
 * @param value                         Node links as char value (RTK pass entire Graph::Node)
 * @return                              TRUE if node is valence 1
 *                                      FALSE if is not
 */
__device__ bool isValence1( char value )
{
    int count = 0;
    for( int e = 0; e < 8; e++ )
    {
        if( ( bool ) CHECK_BIT( value, e ) )
        {
            count++;
        }
    }

    return ( count == 1 );
}


/**
 * @brief c_neighbor_index          Return neighbor node index according to the connected edge
 * @param index                     Node index
 * @param edge                      Edge index (0-7)
 * @param width                     Image width
 * @return                          Neighbor node index according to the connected edge
 */
__device__ int c_neighbor_index( int index, int edge, int width )
{
    //int result;
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
    //return result;
}


/**
 * @brief connected_edge            Return edge index for the neighbor connected edge
 * @param edge                      Edge index
 * @return                          Edge index for the neighbor connected edge
 */
__device__ int connected_edge( int edge )
{
    return ( 8 - 1 ) - edge;
}


/**
 * @brief nextEdgeCounterClockwise          Return the counter clockwise edge starting from edge
 * @param index                             Node index
 * @param edge                              Edge index (0 - 7)
 * @return                                  First counter clockwise edge index
 */
__device__ int nextEdgeCounterClockwise( char* graph, int index, int edge )
{
    if( isValence1( graph[ index ] ) )
    {
        /* Only one edge so the number dont change */
        //edge = connected_edge(edge);
        return edge;
    }
    else
    {
        edge = getClockLinkIndex( edge );
        for( int e = ( edge + 8 - 1 ); e >= ( edge + 8 - 7 ); e-- )
        {
            /* If bit is active (a link) and it is not *edge
               then it is the oposite link cause its valence 2 */
            if( ( bool ) CHECK_BIT( graph[ index ], getRealLinkIndex( e % 8 ) ) )
            {
                edge = getRealLinkIndex( e % 8 );
                break;
            }
        }
    }
    return edge;
}


/**
 * @brief nextNodeClockwise             Return index and oposite edge for linked node
 *                                      walking clockwise, starting from the linked edge
 *                                      of the next edge
 * @param[in,out] index                 Node index
 * @param[in,out] edge                  Edge index
 */
__device__ void nextNodeClockwise( char* graph, int* index, int* edge, int width )
{
    *index = c_neighbor_index( *index, *edge, width );

    if( isValence1( graph[ *index ] ) )
    {
        /* Only one edge so the number dont change */
        *edge = connected_edge( *edge );
    }
    else
    {
        *edge = getClockLinkIndex( connected_edge( *edge ) );
        for( int e = ( *edge + 1 ); e <= ( *edge + 7 ); e++ )
        {
            /* If bit is active (a link) and it is not *edge
               then it is the oposite link cause its valence 2 */
            if( ( bool ) CHECK_BIT( graph[ *index ], getRealLinkIndex( e % 8 ) ) )
            {
                *edge = getRealLinkIndex( e % 8 );
                break;
            }
        }
    }
}


__device__ void debugInfo( bool internal, bool listed, bool discarded )
{
    if( internal )
    {
        printf( "-Internal node found\n" );
    }
    if( listed )
    {
        printf( "-Listed node found\n" );
    }
    if( discarded )
    {
        printf( "-Discarded node found\n" );
    }
}


/**
 * @brief extractBorderPoints       Walk throught the borders of the graph's conected components.
 *                                  Extracts the cell's points during this process to be te input of the spline generation
 * @param graph                     Similarity graph generated for the image
 * @param colorList                 List of splines color
 * @return                          List of splines
 */
template< typename T >
__device__ void extractBorderPoints( char* graph, int width, int height, T* diagram, int* edge_count, int* CClist,
                                     int* CCsizes )
{
    /* List of border nodes for each connected components  */
    //int** CClist = (int**)malloc( ( (width+height)/2 )*sizeof(int*));
    int CCList_index = 0;

    /* List of already processed nodes */
    int* listed = ( int* )malloc( width * height * sizeof( int ) );
    int listed_index = 0;

    /* List of nodes that is not an output nor need to be recomputed  */
    int* discarded = ( int* )malloc( width * height * sizeof( int ) );
    int discarded_index = 0;

    /* List of CCs size for each entry on CClist */
    //int* CCsizes = (int*)malloc( ( (width+height)/2 )*sizeof(int));
    int CCsizes_index = 0;

    /* List of spline control points */
//    T** splineList;
//    int spline_index = 0;

    int* currentListed = ( int* )malloc( width * height * sizeof( int ) );
    int current_index = 0;

    /* First node index of a connected component */
    int firstNodeCC;

    int index;
    int cell_index;
    char node;

    /* How much nodes in the current connected component
       Used to traceback when computation hits a non valid node */
    int numCCNodes;

    /* Index of current connected component */
    int cc_index = 0;

    bool it;
    bool it_discarded;


    /* Loop throught nodes */
    for( int i = 0; i < height; i++ )
    {
        for( int j = 0; j < width; j++ )
        {
            index = i * width + j;
            node = graph[ index ];
            //cell_index = index * CELL_SIZE;

            /* *DO NOT* process if node is internal node */
            if( isInternalNode( node ) )
            {
                continue;
            }

            it = find_int( listed, index, listed_index );

            /* Test if it is already stored for some connected component */
            if( !it )
            {
                firstNodeCC = index;
                /* Node is flagged as processed */
                listed[ listed_index++ ] = index;

                int edge = getFirstLink( node );

                /* Walking throught the border must end the loop on this edge for the firstNodeCC */
                int edgeOfArrival = nextEdgeCounterClockwise( graph, index, edge );

                numCCNodes = 1;

                /* Listed only for this loop */
                //currentListed

                currentListed[ current_index++ ] = index;

                int z = 0;
                /* While the current index is not the first index (while the loop is not completed) */
                while( ( c_neighbor_index( index, edge,
                                           width ) != firstNodeCC ) || ( connected_edge( edge ) != edgeOfArrival ) )
                {
                    printf( "index: %d, node: %d, edge: %d\n", index, node, edge );
                    nextNodeClockwise( graph, &index, &edge, width );
                    node = graph[ index ];

                    it = find_int( listed, index, listed_index );
                    it_discarded = find_int( discarded, index, discarded_index );

                    /* The second line test if the loop ends in the arrival edge for the first node */
                    if( isInternalNode( node ) || it || it_discarded )
                    {
                        printf( "--ZEROU--\n" );
                        debugInfo( isInternalNode( node ), it, it_discarded );
                        while( numCCNodes > 0 )
                        {
                            //printf("firstNodeCC: %d\n", firstNodeCC);
                            discarded[ discarded_index++ ] = currentListed[ current_index - 1 ];
                            //printf("numCCNodes: %d\n", numCCNodes);
                            numCCNodes--;
                        }
                        current_index = 0;
                        break;
                    }
                    currentListed[ current_index++ ] = index;
                    numCCNodes++;
                }
                printf( "Fim da CC de %d nós\n", numCCNodes );
                /* If numCCNodes > 0 then a connected component was processed
                   so put the node's indexes on the list of nodes for each connected components (CClist) */
                if( numCCNodes > 0 )
                {
                    int CCindexes_index = 0;
                    while( numCCNodes > 0 )
                    {
                        CClist[ CCList_index++ ] = currentListed[ current_index - numCCNodes ];
                        CCindexes_index++;
                        if( ( current_index - numCCNodes ) > 0 )
                        {
                            listed[ listed_index++ ] = currentListed[ current_index - numCCNodes ];
                        }
                        numCCNodes--;
                    }

                    CCsizes[ CCsizes_index++ ] = CCindexes_index;
                    CCindexes_index = 0;
                    cc_index++;
                    //*numCC = cc_index;
                }
            }
        }
    }

    int total = 0;
    for( int j = 0; j < cc_index; j++ )
    {
        printf( "CC - %d:\n", j );
        for( int i = 0; i < CCsizes[ j ]; i++ )
        {
            printf( "%d, ", CClist[ i + total ] );
        }
        printf( "\n" );
        total += CCsizes[ j ];
    }

    free( listed );
    free( discarded );
    //free(CClist);
//    free(CCindexes);
    free( currentListed );
//    return splineList;
}


