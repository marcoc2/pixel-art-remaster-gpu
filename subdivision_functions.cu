/* Functions considering counter clockwise order for cells points */

__device__ inline int mod( int i, int n )
{
    return ( n + ( i % n ) ) % n;
}


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
    return 0;
}


template< typename T >
__device__ T getQ_i( int i, T* diagram, int edge_count, char node )
{
    /* Nodes exception:
    36  -> diagonal "/"
    129 -> diagonal "\"
    These non border edges nodes are adjacent to TWO cells   */

    T P;
    int p_index = i % edge_count;
    if( p_index < 0 )
    {
        p_index = p_index + edge_count;
    }
    P.x = diagram[ p_index ].x;
    P.y = diagram[ p_index ].y;

    T P_next;
    P_next.x = diagram[ ( i + 1 ) % edge_count ].x;
    P_next.y = diagram[ ( i + 1 ) % edge_count ].y;

    T Qi;

    float lenght = sqrt( ( ( P_next.x - P.x ) * ( P_next.x - P.x ) + ( P_next.y - P.y ) * ( P_next.y - P.y ) ) );

    //if ( ( (unsigned int) (unsigned char) node != 36) && ((unsigned int) (unsigned char)node != 129) &&
    //     ( (unsigned int) (unsigned char) node != 46)  && ( (unsigned int) (unsigned char) node != 116))
    if( lenght <= 1.0 )
    {
        Qi.x = P.x / 2.0 + ( P.x + P_next.x ) / 4.0;

        Qi.y = P.y / 2.0 + ( P.y + P_next.y ) / 4.0;
    }
    else
    {
        Qi.x = ( 7.0 * P.x ) / 8.0 + ( P_next.x ) / 8.0;

        Qi.y = ( 7.0 * P.y ) / 8.0 + ( P_next.y ) / 8.0;
    }

    return Qi;
}


template< typename T >
__device__ T getR_i( int i, T* diagram, int edge_count, char node )
{
    T P;
    int p_index = i % edge_count;
    if( p_index < 0 )
    {
        p_index = p_index + edge_count;
    }
    P.x = diagram[ p_index ].x;
    P.y = diagram[ p_index ].y;

    T P_next;
    P_next.x = diagram[ ( i + 1 ) % edge_count ].x;
    P_next.y = diagram[ ( i + 1 ) % edge_count ].y;

    T Ri;

    float lenght = sqrt( ( ( P_next.x - P.x ) * ( P_next.x - P.x ) + ( P_next.y - P.y ) * ( P_next.y - P.y ) ) );

    //if ( ( (unsigned int) (unsigned char) node != 36) && ((unsigned int) (unsigned char)node != 129) &&
    //     ( (unsigned int) (unsigned char) node != 46)  && ( (unsigned int) (unsigned char) node != 116))
    if( lenght <= 1.0 )
    {
        Ri.x = P_next.x / 2.0 + ( P.x + P_next.x ) / 4.0;

        Ri.y = P_next.y / 2.0 + ( P.y + P_next.y ) / 4.0;
    }
    else
    {
        Ri.x = ( 1.0 * P.x ) / 8.0 + ( 7.0 * P_next.x ) / 8.0;

        Ri.y = ( 1.0 * P.y ) / 8.0 + ( 7.0 * P_next.y ) / 8.0;
    }

    return Ri;
}


template< typename T >
__device__ T getR_i_from_linked_cell( T* diagram, T p, int link_index, int* edge_count_v, int edge_count,
                                      int node_index, int width, char node )
{
    int linked_cell_index = c_neighbor_index( node_index, link_index, width );
    T* linked_cell = &diagram[ linked_cell_index * CELL_SIZE ];
    int linked_edge_count = edge_count_v[ linked_cell_index ];

    int op_index = getPointIndex( getOppositePoint( p, link_index ), linked_cell, linked_edge_count );

    /* Get Ri point for the previous edge */
    return getOppositePointCoord( getR_i( op_index - 1, linked_cell, linked_edge_count, node ), link_index );
    //return getR_i( op_index - 1, linked_cell, linked_cell.size());
}


template< typename T >
__device__ T getQ_i_from_linked_cell( T* diagram, T p, int link_index, int* edge_count_v, int edge_count,
                                      int node_index, int width, char node )
{
    int linked_cell_index = c_neighbor_index( node_index, link_index, width );
    T* linked_cell = &diagram[ linked_cell_index * CELL_SIZE ];
    int linked_edge_count = edge_count_v[ linked_cell_index ];

    int op_index = getPointIndex( getOppositePoint( p, link_index ), linked_cell, linked_edge_count );

    /* Get Qi point for the current edge */
    return getOppositePointCoord( getQ_i( op_index, linked_cell, linked_edge_count, node ), link_index );
    //return getQ_i( op_index, linked_cell, linked_cell.size());
}


__device__ bool isColorEqual( char* c1, char* c2 )
{
    if( ( c1[ 0 ] == c2[ 0 ] ) && ( c1[ 1 ] == c2[ 1 ] ) && ( c1[ 2 ] == c2[ 2 ] ) )
    {
        return true;
    }
    else
    {
        return false;
    }
}


template< typename T >
__device__ bool checkTJunction( char* image_data, int width, int img_widthstep, int height, int i, int j, T p )
{
    /*     Colors
      +----+----+----+
      |    |    |    |
      | c0 | c1 | c2 |
      +----+----+----+
      |    |    |    |
      | c3 | c  | c4 |
      +----+----+----+
      |    |    |    |
      | c5 | c6 | c7 |
      +----+----+----+   */

    int index = j * img_widthstep + i * 3;

    if( ( ( index - img_widthstep - 1 ) < 0 ) || ( ( index + width + 1 ) > ( ( height * img_widthstep ) - 1 ) ) )
    {
        return true;
    }

    char* c0, * c1, * c2, * c3, * c4, * c5, * c6, * c7;

    //c = &image_data[index];
    c0 = &image_data[ index + img_widthstep - 3 ];
    c1 = &image_data[ index + img_widthstep ];
    c2 = &image_data[ index + img_widthstep + 3 ];
    c3 = &image_data[ index - 3 ];
    c4 = &image_data[ index + 3 ];
    c5 = &image_data[ index - img_widthstep - 3 ];
    c6 = &image_data[ index - img_widthstep ];
    c7 = &image_data[ index - img_widthstep + 3 ];


    if( ( p.x == 0.0 ) && ( p.y == 0.0 ) )
    {
        if( !isColorEqual( c3, c5 ) ||
            !isColorEqual( c5, c6 ) )
        {
            return true;
        }
    }

    if( ( p.x == 1.0 ) && ( p.y == 0.0 ) )
    {
        if( !isColorEqual( c4, c7 ) ||
            !isColorEqual( c7, c6 ) )
        {
            return true;
        }
    }

    if( ( p.x == 1.0 ) && ( p.y == 1.0 ) )
    {
        if( !isColorEqual( c1, c2 ) ||
            !isColorEqual( c2, c4 ) )
        {
            return true;
        }
    }

    if( ( p.x == 0.0 ) && ( p.y == 1.0 ) )
    {
        if( !isColorEqual( c0, c1 ) ||
            !isColorEqual( c1, c3 ) )
        {
            return true;
        }
    }

    return false;
}


template< typename T >
__device__ bool isLinkedEdge( T* cell, char node, int index, int edge_count, int i_, int j_, int* link_index,
                              int& li_index )
{
    /* Try the eight possible links of the node */

    /* Edge Slope */

    float slope = ( cell[ mod( index + 1, edge_count ) ].y - cell[ index ].y ) /
                  ( cell[ mod( index + 1, edge_count ) ].x - cell[ index ].x );

    float mid_y = ( cell[ index ].y + cell[ mod( index + 1, edge_count ) ].y ) / 2.0;

    /*      UP
      +----+----+----+
      |    | |  |    |
      | 0  | |  | 2  |
      +----+----+----+
      |    | |  |    |
      | 3  | |  | 4  |
      +----+----+----+
      |    |    |    |
      | 5  | 6  | 7  |
      +----+----+----+   */

    if( ( cell[ index ].y == cell[ mod( index + 1, edge_count ) ].y ) &&
        ( cell[ index ].y > 0.5 ) &&
        ( CHECK_BIT( node, 1 ) ) )
    {
        link_index[ li_index++ ] = 1;
        return true;
    }


    /*      Right
      +----+----+----+
      |    |    |    |
      | 0  | 1  | 2  |
      +----+----+----+
      |    |    |    |
      | 3  |  --|----|
      +----+----+----+
      |    |    |    |
      | 5  | 6  | 7  |
      +----+----+----+   */

    if( ( cell[ index ].x == cell[ mod( index + 1, edge_count ) ].x ) &&
        ( cell[ index ].x > 0.5 ) &&
        ( CHECK_BIT( node, 4 ) ) )
    {
        link_index[ li_index++ ] = 4;
        return true;
    }

    /*      Down
      +----+----+----+
      |    |    |    |
      | 0  | 1  | 2  |
      +----+----+----+
      |    | |  |    |
      | 3  | |  | 4  |
      +----+----+----+
      |    | |  |    |
      | 5  | |  | 7  |
      +----+----+----+   */

    if( ( cell[ index ].y == cell[ mod( index + 1, edge_count ) ].y ) &&
        ( cell[ index ].y < 0.5 ) &&
        ( CHECK_BIT( node, 6 ) ) )
    {
        link_index[ li_index++ ] = 6;
        return true;
    }

    /*      Left
      +----+----+----+
      |    |    |    |
      | 0  | 1  | 2  |
      +----+----+----+
      |    |    |    |
      |----|--  | 4  |
      +----+----+----+
      |    |    |    |
      | 5  | 6  | 7  |
      +----+----+----+   */

    if( ( cell[ index ].x == cell[ mod( index + 1, edge_count ) ].x ) &&
        ( cell[ index ].x < 0.5 ) &&
        ( CHECK_BIT( node, 3 ) ) )
    {
        link_index[ li_index++ ] = 3;
        return true;
    }

    /*    Up-Left
      +----+----+----+
      | \  |    |    |
      |  \ | 1  | 2  |
      +----+----+----+
      |    |\   |    |
      | 3  |    | 4  |
      +----+----+----+
      |    |    |    |
      | 5  | 6  | 7  |
      +----+----+----+   */

    if( ( slope == 1 ) &&
        ( mid_y > 0.5 ) &&
        ( CHECK_BIT( node, 0 ) ) )
    {
        link_index[ li_index++ ] = 0;
        return true;
    }


    /*    Up-Right
      +----+----+----+
      |    |    | /  |
      | 0  | 1  |/   |
      +----+----+----+
      |    |  / |    |
      | 3  |    | 4  |
      +----+----+----+
      |    |    |    |
      | 5  | 6  | 7  |
      +----+----+----+   */

    if( ( slope == -1 ) &&
        ( mid_y > 0.5 ) &&
        ( CHECK_BIT( node, 2 ) ) )
    {
        link_index[ li_index++ ] = 2;
        return true;
    }


    /*    Down-Right
      +----+----+----+
      |    |    |    |
      | 0  | 1  | 2  |
      +----+----+----+
      |    |    |    |
      | 3  |  \ | 4  |
      +----+----+----+
      |    |    |\   |
      | 5  | 6  | \  |
      +----+----+----+   */

    if( ( slope == 1 ) &&
        ( mid_y < 0.5 ) &&
        ( CHECK_BIT( node, 7 ) ) )
    {
        link_index[ li_index++ ] = 7;
        return true;
    }


    /*    Down-Right
      +----+----+----+
      |    |    |    |
      | 0  | 1  | 2  |
      +----+----+----+
      |    |    |    |
      | 3  |/   | 4  |
      +----+----+----+
      |   /|    |    |
      |  / | 6  | 7  |
      +----+----+----+   */

    if( ( slope == -1 ) &&
        ( mid_y < 0.5 ) &&
        ( CHECK_BIT( node, 5 ) ) )
    {
        link_index[ li_index++ ] = 5;
        return true;
    }

    link_index[ li_index++ ] = -1;
    return false;
}


template< typename T >
__device__ T getOppositePoint( T p, int edge )
{
    T result;
    switch( edge )
    {
        case 0:
            result.x = p.x + 1;
            result.y = p.y - 1;
            break;

        case 1:
            result.x = p.x;
            result.y = p.y - 1;
            break;

        case 2:
            result.x = p.x - 1;
            result.y = p.y - 1;
            break;

        case 3:
            result.x = p.x + 1;
            result.y = p.y;
            break;

        case 4:
            result.x = p.x - 1;
            result.y = p.y;
            break;

        case 5:
            result.x = p.x + 1;
            result.y = p.y + 1;
            break;

        case 6:
            result.x = p.x;
            result.y = p.y + 1;
            break;

        case 7:
            result.x = p.x - 1;
            result.y = p.y + 1;
            break;
    }
    return result;
}


template< typename T >
__device__ T getOppositePointCoord( T p, int edge )
{
    T result;
    switch( edge )
    {
        case 0:
            result.x = p.x - 1;
            result.y = p.y + 1;
            break;

        case 1:
            result.x = p.x;
            result.y = p.y + 1;
            break;

        case 2:
            result.x = p.x + 1;
            result.y = p.y + 1;
            break;

        case 3:
            result.x = p.x - 1;
            result.y = p.y;
            break;

        case 4:
            result.x = p.x + 1;
            result.y = p.y;
            break;

        case 5:
            result.x = p.x - 1;
            result.y = p.y - 1;
            break;

        case 6:
            result.x = p.x;
            result.y = p.y - 1;
            break;

        case 7:
            result.x = p.x + 1;
            result.y = p.y - 1;
            break;
    }
    return result;
}


template< typename T >
__device__ int getPointIndex( T p, T* cell, int edge_count )
{
    for( int i = 0; i < edge_count; i++ )
    {
        if( ( p.x == cell[ i ].x ) && ( p.y == cell[ i ].y ) )
        {
            return i;
        }
    }
    return 0;
}


template< typename T >
__device__ void checkEdges( bool* edge_status, T* cell, char node, int edge_count, int i_, int j_, int* link_index )
{
    int li_index = 0;

    /* Loop through each edge */
    for( int i = 0; i < edge_count; i++ )
    {
        edge_status[ i ] = isLinkedEdge( cell, node, i, edge_count, i_, j_, link_index, li_index );
    }
}


template< typename T >
__device__ T midPoint( T p1, T p2 )
{
    T result;
    result.x = ( ( p1.x + p2.x ) / 2.0 );
    result.y = ( ( p1.y + p2.y ) / 2.0 );
    return result;
}


template< typename T >
__device__ int subdivision( char* image_data, T* cell, T* diagram, int* edge_count_v, int node_index,
                            int width, int img_widthstep, int height, int i_, int j_, char node, bool* edge_status,
                            int* link_index )
{
    //T d_copy[CELL_SIZE];
//    bool edge_status[CELL_SIZE/2];
//    int link_index[CELL_SIZE/2];

    int edge_index = 0;
    int edge_count = edge_count_v[ node_index ];

    checkEdges( edge_status, &diagram[ ( node_index * CELL_SIZE ) ], node, edge_count, i_, j_, link_index );

    T Qi, R_previous;

    for( int i = 0; i < edge_count; i++ )
    {
        /* Two adjacent edges that are border */
        if( !edge_status[ i ] && !edge_status[ mod( i - 1, edge_count ) ] )
        {
            if( checkTJunction( image_data, width, img_widthstep, height, i_, j_,
                                diagram[ ( node_index * CELL_SIZE ) + i ] ) )
            {
                cell[ edge_index ].x = diagram[ ( node_index * CELL_SIZE ) + i ].x;
                cell[ edge_index++ ].y = diagram[ ( node_index * CELL_SIZE ) + i ].y;
            }
            else
            {
                Qi = getQ_i( i, &diagram[ ( node_index * CELL_SIZE ) ], edge_count, node );

                R_previous = getR_i( i - 1, &diagram[ ( node_index * CELL_SIZE ) ], edge_count, node );

                cell[ edge_index ].x = R_previous.x;
                cell[ edge_index++ ].y = R_previous.y;

                cell[ edge_index ].x = Qi.x;
                cell[ edge_index++ ].y = Qi.y;
            }
        }
        else
        /* Current edge is internal and the following is border
           In this case we have to take the Ri from the previous edge of the adjacent cell */
        if( !edge_status[ i ] && edge_status[ mod( i - 1, edge_count ) ] )
        {
            Qi = getQ_i( i, &diagram[ ( node_index * CELL_SIZE ) ], edge_count, node );

            T R_adjacent =
                getR_i_from_linked_cell( diagram, diagram[ ( node_index * CELL_SIZE ) + i ],
                                         link_index[ mod( i - 1,
                                                          edge_count ) ], edge_count_v, edge_count, node_index, width,
                                         node );

            R_adjacent = midPoint( Qi, R_adjacent );

            cell[ edge_index ].x = R_adjacent.x;
            cell[ edge_index++ ].y = R_adjacent.y;

            cell[ edge_index ].x = Qi.x;
            cell[ edge_index++ ].y = Qi.y;
        }
        else
        /* Current edge is border and the following is internal
           In this case we have to take the Qi from the next edge of the adjacent cell */
        if( edge_status[ i ] && !edge_status[ mod( i - 1, edge_count ) ] )
        {
            T Q_adjacent = getQ_i_from_linked_cell( diagram, diagram[ ( node_index * CELL_SIZE ) + i ], link_index[ i ],
                                                    edge_count_v, edge_count, node_index, width, node );

//                    if ( (i_ == 3) && (j_ == 5) )
//                        printf("Q_adjacent for i=%d, j=%d = P( %2.2f, %2.2f )\n", i_, j_, Q_adjacent.x, Q_adjacent.y);

            T Ri = getR_i( i - 1, &diagram[ ( node_index * CELL_SIZE ) ], edge_count, node );

            Q_adjacent = midPoint( Ri, Q_adjacent );

            cell[ edge_index ].x = Ri.x;
            cell[ edge_index++ ].y = Ri.y;

            cell[ edge_index ].x = Q_adjacent.x;
            cell[ edge_index++ ].y = Q_adjacent.y;
        }
        else
        /* Two adjacent internal edges. Nothing to do */
        {
            cell[ edge_index ].x = diagram[ ( node_index * CELL_SIZE ) + i ].x;
            cell[ edge_index++ ].y = diagram[ ( node_index * CELL_SIZE ) + i ].y;
        }
    }

//    if ( (i_ == 3) && (j_ == 5) )
//    {
//        for(int i = 0; i < (edge_index); i++)
//        {
//            printf(" subdividion  P( %2.2f, %2.2f )\n", cell[i].x, cell[i].y);
//        }
//    }

    //free(d_copy);
    //free(edge_status);
    //free(link_index);

    return edge_index;
    //return edge_count_v[node_index];
    //return edge_count * 2;
}


