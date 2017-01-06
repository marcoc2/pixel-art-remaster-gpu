/* BACKUP TO CHANGE CODE TO VBO FLOAT 2 INSTEAD OF ARRAY OF POINTS(FLOAT, FLOAT) */

/** Check bit value */
//#define CHECK_BIT(var,pos) ((var) & (1<<(pos)))


//struct __align(8)__ Point
//{
//  float x;
//  float y;
//   Point(float x, float y){
//       this->x = x;
//       this->y = y;
//   }
//}

typedef int coord2_t;

/* A utility function to swap two elements */
__device__ void swap_int ( int* a, int* b )
{
    int t = *a;
    *a = *b;
    *b = t;
}

/* A utility function to swap two points */
template <typename T>
__device__ void swap ( T* a, T* b )
{
    T t = *a;
    *a = *b;
    *b = t;
}

template <typename T>
__device__ void sort_y(T* P, int start, int end)
{
//    Point P_[10];
//    for (int i = 0; i < 10; i++ )
//        P_[i] = P[i];

    float minor = 99.0f;
    int tie = 0;
    int tie_index[CELL_SIZE];

//    while (sorted < size_P)
//    {
        for (int i = start; i <= end; i++) {
            if (P[i].y < minor)
            {
                minor = P[i].y;
                tie = 0;
                tie_index[tie] = i;
            } else {
                if (P[i].y == minor)
                {
                    tie++;
                    tie_index[tie] = i;
                }
            }
        }

        /* Order ties in X by Y. Works when we only have 2 ties */
        if (tie > 0)
        {
            for (int i = 0; i <= tie; i++)
            {
                swap<T>(&P[i + start], &P[tie_index[i]]);
            }
        } else {
            swap(&P[start], &P[tie_index[0]]);
        }

//    }

//    for (int i = 0; i < 10; i++ )
//        P_[i] = P[i];

}

template <typename T>
__device__ void sort(T* P, int size_P)
{
    //Point P[10];
//    for (int i = 0; i < 10; i++ )
//        P[i] = P_[i];

    float minor = 99.0f;
    //float minor_y = 99.0f;
    int tie = 0;
    int tie_index[CELL_SIZE];
    int sorted = 0;

    while (sorted < size_P)
    {
        for (int i = sorted; i < size_P; i++) {
            if (P[i].x < minor)
            {
                minor = P[i].x;
                tie = 0;
                tie_index[tie] = i;
            } else {
                if (P[i].x == minor)
                {
                    tie++;
                    tie_index[tie] = i;
                }
            }
        }

        /* Order ties in X by Y. Works when we only have 2 ties */
        if (tie > 0)
        {
            for (int i = 0; i <= tie; i++)
            {
                swap(&P[i + sorted], &P[tie_index[i]]);
            }
            sort_y<T>(P, sorted, sorted + tie);
        } else {
            swap(&P[sorted], &P[tie_index[0]]);
        }

        sorted += tie + 1;
        minor = 99.0f;
        //minor_y = 99.0f;
    }

}

/* Sort Lexographically */
template <typename T>
__device__ void invert(T* P, int size_P, int offset)
{

    for (int i = 0 ; i < size_P/2; i++)
    {
        swap(&P[ offset + i ], &P[ (offset + size_P - 1) - i ]);
    }
}


/* This function is same in both iterative and recursive */
template <typename T>
__device__ int partition (T* arr, int l, int h)
{
    int x = arr[h].x;
    int i = (l - 1);

    for (int j = l; j <= h- 1; j++)
    {
        if (arr[j].x <= x)
        {
            i++;
            swap (&arr[i], &arr[j]);
        }
    }
    swap (&arr[i + 1], &arr[h]);
    return (i + 1);
}

/* A[] --> Array to be sorted, l  --> Starting index, h  --> Ending index */
template <typename T>
__device__ void quickSortIterative (T* arr, int l, int h)
{
    // Create an auxiliary stack
    int stack[ CELL_SIZE ];

    // initialize top of stack
    int top = -1;

    // push initial values of l and h to stack
    stack[ ++top ] = l;
    stack[ ++top ] = h;

    // Keep popping from stack while is not empty
    while ( top >= 0 )
    {
        // Pop h and l
        h = stack[ top-- ];
        l = stack[ top-- ];

        // Set pivot element at its correct position in sorted array
        int p = partition( arr, l, h );

        // If there are elements on left side of pivot, then push left
        // side to stack
        if ( p-1 > l )
        {
            stack[ ++top ] = l;
            stack[ ++top ] = p - 1;
        }

        // If there are elements on right side of pivot, then push right
        // side to stack
        if ( p+1 < h )
        {
            stack[ ++top ] = p + 1;
            stack[ ++top ] = h;
        }
    }
}

template <typename T>
__device__ T multiply(T p, int a)
{
    T result;
    result.x = p.x * float(a);
    result.y = p.y * float(a);

    return result;
}

/**
 * @brief cross                     Implementation of Andrew's monotone chain 2D convex hull algorithm.
 *                                  2D cross product of OA and OB vectors, i.e. z-component of their 3D cross product.
 *                                  Returns a positive value, if OAB makes a counter-clockwise turn,
 *                                  negative for clockwise turn, and zero if the points are collinear.
 * @link                            http://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain#C.2B.2B
 * @param O                         Point O
 * @param A                         Point A
 * @param B                         Point B
 * @return                          Cross product value for OA and OB
 */
template <typename T>
__device__ int cross(const T &O, const T &A, const T &B)
{
    //int b = (A.x - O.x) * (int)(B.y - O.y) - (A.y - O.y) * (int)(B.x - O.x);
    return (A.x - O.x) * (int)(B.y - O.y) - (A.y - O.y) * (int)(B.x - O.x);
}

/**
 * @brief convex_hull               Returns a list of points on the convex hull in counter-clockwise order.
 *                                  Note: the last point in the returned list is the same as the first one.
 * @param P                         List of points
 * @return                          Points in the convex hull of P
 */
template <typename T>
__device__ int convex_hull(T* P_, int size_P, int i_, int j_, int cell_index)
{
    //int count = 0;
    const int magnify = 100;
    int n = size_P;
    int k = 0;
    T H[CELL_SIZE];
    //H.resize(20);

    /* Sort points lexicographically */

    T P[CELL_SIZE];
    for (int i=0; i < CELL_SIZE; i++)
        P[i] = P_[cell_index + i];



//    if ( (i_ == 1) && (j_ == 1) )
//    {
//        for (int i = 0; i < CELL_SIZE; i++)
//            printf("Original P( %2.2f, %2.2f )\n", P_[cell_index + i].x, P_[cell_index + i].y);
//    }

    sort<T>(P, size_P);

//    if ( (i_ == 1) && (j_ == 1) )
//    {
//        for (int i = 0; i < size_P; i++)
//            printf("Sorted P( %2.2f, %2.2f )\n", P[i].x, P[i].y);
//    }

    /* Build lower hull */
    for (int i = 0; i < n; i++) {
        int teste = cross(multiply(H[k-2], magnify), multiply(H[k-1], magnify), multiply(P[i], magnify));
        //if ( (i_ == 1) && (j_ == 1) )
            //printf("teste: %d\n", teste);
        while (k >= 2 && cross(multiply(H[k-2], magnify), multiply(H[k-1], magnify), multiply(P[i], magnify)) <= 0)
            k--;
        H[k++] = P[i];

    }

//    if ( (i_ == 1) && (j_ == 1) )
//    {
//        for (int i = 0; i < size_P; i++)
//            printf("Lower Hull P( %2.2f, %2.2f )\n", H[i].x, H[i].y);
//    }

    /* Build upper hull */
    for (int i = n-2, t = k+1; i >= 0; i--) {
        while (k >= t && cross(multiply(H[k-2], magnify), multiply(H[k-1], magnify), multiply(P[i], magnify)) <= 0)
            k--;
        H[k++] = P[i];

    }

//    if ( (i_ == 1) && (j_ == 1) )
//    {
//        for (int i = 0; i < CELL_SIZE; i++)
//            printf("Feixo P( %2.2f, %2.2f )\n", H[i].x, H[i].y);
//    }

    for (int i = 0; i < CELL_SIZE; i++)
    {
        P_[cell_index + i] = H[i];
//        if ( ( (H[i].x == 0) && (H[i].y == 0) ) && (i != 0) )
//            break;
//        count++;
    }

//    if ( (i_ == 1) && (j_ == 1) )
//    {
//        for (int i = 0; i < CELL_SIZE; i++)
//            printf("Feixo P( %2.2f, %2.2f )\n", H[i].x, H[i].y);
//    }

    return --k;
}


template <typename T>
__device__ int createCellFromPattern(char node, char nodeLeft, char nodeRight, T* cell, int cell_index, int i_, int j_)
{
    /* Clockwise order: 0, 1, 2, 4, 7, 6, 5, 3 */

    int i = 0;

    /* RTK Verify if this is giving clockwise points or convex_hull */

    if ((bool) CHECK_BIT(node, 0)) {
        if ( ((bool) CHECK_BIT(node, 1)) && (!(bool) CHECK_BIT(node, 3)) )
        {
            cell[cell_index + i].x = -0.25f;
            cell[cell_index + i].y = 0.75f;
            i++;
        } else if ( ((bool) CHECK_BIT(node, 3)) && (!(bool) CHECK_BIT(node, 1)) ) {
            cell[cell_index + i].x = 0.25f;
            cell[cell_index + i].y = 1.25f;
            i++;
        } else {
            cell[cell_index + i].x = -0.25f;
            cell[cell_index + i].y = 0.75f;
            i++;
            cell[cell_index + i].x = 0.25f;
            cell[cell_index + i].y = 1.25f;
            i++;
        }
    } else {
        /* Check neighbor edge */
        if ((bool)CHECK_BIT(nodeLeft, 2))
        {
            cell[cell_index + i].x = 0.25f;
            cell[cell_index + i].y = 0.75f;
            i++;
        }
        else
        {
            cell[cell_index + i].x = 0.0f;
            cell[cell_index + i].y = 1.0f;
            i++;
        }
    }


    if ((bool) CHECK_BIT(node, 1)) {
        cell[cell_index + i].x = 0.0f;
        cell[cell_index + i].y = 1.0f;
        i++;
        cell[cell_index + i].x = 1.0f;
        cell[cell_index + i].y = 1.0f;
        i++;
    } else {
        cell[cell_index + i].x = 0.5f;
        cell[cell_index + i].y = 0.75f;
        i++;
    }

    if ((bool) CHECK_BIT(node, 2)) {
        if ( ((bool) CHECK_BIT(node, 1)) && (!(bool) CHECK_BIT(node, 4)) )
        {
            cell[cell_index + i].x = 1.25f;
            cell[cell_index + i].y = 0.75f;
            i++;
        } else if ( ((bool) CHECK_BIT(node, 4)) && (!(bool) CHECK_BIT(node, 1)) ) {
            cell[cell_index + i].x = 0.75f;
            cell[cell_index + i].y = 1.25f;
            i++;
        } else {
            cell[cell_index + i].x = 0.75f;
            cell[cell_index + i].y = 1.25f;
            i++;
            cell[cell_index + i].x = 1.25f;
            cell[cell_index + i].y = 0.75f;
            i++;
        }
    } else {
        /* Check neighbor edge */
        if ((bool)CHECK_BIT(nodeRight, 0))
        {
            cell[cell_index + i].x = 0.75f;
            cell[cell_index + i].y = 0.75f;
            i++;
        }
        else
        {
            cell[cell_index + i].x = 1.0f;
            cell[cell_index + i].y = 1.0f;
            i++;
        }
    }


    if ((bool) CHECK_BIT(node, 4)) {
        cell[cell_index + i].x = 1.0f;
        cell[cell_index + i].y = 1.0f;
        i++;
        cell[cell_index + i].x = 1.0f;
        cell[cell_index + i].y = 0.0f;
        i++;
    } else {
        cell[cell_index + i].x = 0.75f;
        cell[cell_index + i].y = 0.75f;
        i++;
    }

    if ((bool) CHECK_BIT(node, 7)) {
        if ( ((bool) CHECK_BIT(node, 4)) && (!(bool) CHECK_BIT(node, 6)) )
        {
            cell[cell_index + i].x = 0.75f;
            cell[cell_index + i].y = -0.25f;
            i++;
        } else if ( ((bool) CHECK_BIT(node, 6)) && (!(bool) CHECK_BIT(node, 4)) ) {
            cell[cell_index + i].x = 1.25f;
            cell[cell_index + i].y = 0.25f;
            i++;
        } else {
            cell[cell_index + i].x = 1.25f;
            cell[cell_index + i].y = 0.25f;
            i++;
            cell[cell_index + i].x = 0.75f;
            cell[cell_index + i].y = -0.25f;
            i++;
        }
    } else {
        /* Check neighbor edge */
        if ((bool)CHECK_BIT(nodeRight, 5))
        {
            cell[cell_index + i].x = 0.75f;
            cell[cell_index + i].y = 0.25f;
            i++;
        }
        else
        {
            cell[cell_index + i].x = 1.0f;
            cell[cell_index + i].y = 0.0f;
            i++;
        }
    }


    if ((bool) CHECK_BIT(node, 6)) {
        cell[cell_index + i].x = 1.0f;
        cell[cell_index + i].y = 0.0f;
        i++;
        cell[cell_index + i].x = 0.0f;
        cell[cell_index + i].y = 0.0f;
        i++;
    } else {
        cell[cell_index + i].x = 0.25f;
        cell[cell_index + i].y = 0.75f;
        i++;
    }

    if ((bool) CHECK_BIT(node, 5)) {
        if ( ((bool) CHECK_BIT(node, 3)) && (!(bool) CHECK_BIT(node, 6)) )
        {
            cell[cell_index + i].x = 0.25f;
            cell[cell_index + i].y = -0.25f;
            i++;
        } else if ( ((bool) CHECK_BIT(node, 6)) && (!(bool) CHECK_BIT(node, 3)) ) {
            cell[cell_index + i].x = -0.25f;
            cell[cell_index + i].y = 0.25f;
            i++;
        } else {
            cell[cell_index + i].x = 0.25f;
            cell[cell_index + i].y = -0.25f;
            i++;
            cell[cell_index + i].x = -0.25f;
            cell[cell_index + i].y = 0.25f;
            i++;
        }
    } else {
        /* Check neighbor edge */
        if ((bool)CHECK_BIT(nodeLeft, 7))
        {
            cell[cell_index + i].x = 0.25f;
            cell[cell_index + i].y = 0.25f;
            i++;
        }
        else
        {
            cell[cell_index + i].x = 0.0f;
            cell[cell_index + i].y = 0.0f;
            i++;
        }
    }


    if ((bool) CHECK_BIT(node, 3)) {
        cell[cell_index + i].x = 0.0f;
        cell[cell_index + i].y = 0.0f;
        i++;
        cell[cell_index + i].x = 0.0f;
        cell[cell_index + i].y = 1.0f;
        i++;
    } else {
        cell[cell_index + i].x = 0.25f;
        cell[cell_index + i].y = 0.5f;
        i++;
    }

    return convex_hull<T>(cell, i, i_, j_, cell_index);

//    if ( (i_ == 1) && (j_ == 1) )
//    {
//        printf("cell_index: %d :\n", cell_index);
//        for (int j = cell_index; j < cell_index + i; j++)
//            printf("Final cell( %2.2f, %2.2f )\n", cell[j].x, cell[j].y);
//    }

//    int edge_count = 1;

//    while ( (cell[0].x != cell[edge_count].x) || (cell[0].y != cell[edge_count].y) )
//        edge_count++;

    //return 4;
}

