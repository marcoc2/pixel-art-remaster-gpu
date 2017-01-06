#include "Image.h"

// Constructors/Destructors
//

Image::Image()
{
}


Image::~Image()
{
}


//
// Methods
//

/** Reverses a image upside down */
void Image::reverses()
{
    IplImage* aux;
    aux = cvCreateImage( cvSize( img->width, img->height ), IPL_DEPTH_8U, 3 );
    cvCopy( img, aux, 0 );
    for( int i = 0; i < height; i++ )
    {
        for( int j = 0; j < width; j++ )
        {
            img->imageData[ i * widthStep + j * n_channels +
                            2 ] = aux->imageData[ ( ( aux->height - 1 ) - i ) * widthStep + j * n_channels + 2 ];
            img->imageData[ i * widthStep + j * n_channels +
                            1 ] = aux->imageData[ ( ( aux->height - 1 ) - i ) * widthStep + j * n_channels + 1 ];
            img->imageData[ i * widthStep + j *
                            n_channels ] = aux->imageData[ ( ( aux->height - 1 ) - i ) * widthStep + j * n_channels ];
        }
    }
}


/** Loads an image from file */
void Image::loadImage( const char* path, int colorness )
{
    img = cvLoadImage( path, colorness );
    width = img->width;
    height = img->height;
    widthStep = img->widthStep;
    n_channels = img->nChannels;
}


/** Creates header and allocates data for the image */
void Image::createImage( int width, int height, int depth, int n_channels )
{
    img = cvCreateImage( cvSize( width, height ), depth, n_channels );
    this->width = img->width;
    this->height = img->height;
    this->widthStep = img->widthStep;
    this->n_channels = img->nChannels;
}


/** Create a file for the image */
void Image::saveImage( const char* file_name )
{
    int p[ 3 ];
    p[ 0 ] = CV_IMWRITE_PNG_COMPRESSION;
    p[ 1 ] = 100;
    p[ 2 ] = 0;
    cvSaveImage( file_name, img, p );
}


/** Copy image src to image dst */
void Image::copy( Image* dst )
{
    cvCopy( img, dst->getImg(), 0 );
}


/** Resize image */
void Image::resizeImage( Image* dst )
{
    //cv::resize(img, dst->getImg,cvSize(width*scale, height*scale) , 0, 0, interpolation);
    cvResize( img, dst->getImg(), CV_INTER_CUBIC );
}


/** Sets every element of array to given value */
void Image::setAllPixels( int c1, int c2, int c3 )
{
    cvSet( img, CV_RGB( c1, c2, c3 ), 0 );
}


/* Access a specific pixel data */
char* Image::accessPixel( int x, int y )
{
    char* pixel = new char[ 3 ];

    pixel[ 0 ] = img->imageData[ y * widthStep + x * n_channels + 0 ];
    pixel[ 1 ] = img->imageData[ y * widthStep + x * n_channels + 1 ];
    pixel[ 2 ] = img->imageData[ y * widthStep + x * n_channels + 2 ];

    return pixel;
}


//
// Accessor methods
//

/**
   * Set the value of width
   * @param new_var the new value of width
   */
void Image::setWidth( int value )
{
    width = value;
}


/**
   * Get the value of width
   * @return the value of width
   */
int Image::getWidth()
{
    return width;
}


/**
   * Set the value of height
   * @param new_var the new value of height
   */
void Image::setHeight( int new_var )
{
    height = new_var;
}


/**
   * Get the value of height
   * @return the value of height
   */
int Image::getHeight()
{
    return height;
}


/**
   * Set the value of widthStep
   * @param new_var the new value of widthStep
   */
void Image::setWidthStep( int new_var )
{
    widthStep = new_var;
}


/**
   * Get the value of height
   * @return the value of height
   */
int Image::getWidthStep()
{
    return widthStep;
}


/**
   * Set the value of image_data
   * @param new_var the new value of n_colors
   */
void Image::setImageData( char* new_var )
{
    img->imageData = new_var;
}


/**
   * Get the value of image_data
   * @return the value of n_colors
   */

char* Image::getImageData()
{
    return img->imageData;
}


/**
   * Set the value of src
   * @param new_var the new value of img
   */
void Image::setImg( IplImage* new_var )
{
    img = new_var;
}


/**
   * Get the value of image_data
   * @return the value of img
   */

IplImage* Image::getImg()
{
    return img;
}


/**
   * Get the value of image_data
   * @return the value of src
   */

int Image::getNchannels()
{
    return n_channels;
}


