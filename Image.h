#pragma once

#ifdef _CH_
#pragma package <opencv>
#endif

#ifndef IMAGE_H
#define IMAGE_H

#include <string>
#include <cv.h>
#include <highgui.h>

/** Check bit value */
#define CHECK_BIT(var,pos) ((var) & (1<<(pos)))

/**
  * class Image
  *
  */

class Image
{
public:

    // Constructors/Destructors
    //


    /**
   * Empty Constructor
   */
    Image ( );

    /**
   * Empty Destructor
   */
    virtual ~Image ( );


private:

    IplImage* img;
    char* image_data;
    int width;
    int height;
    int widthStep;
    int n_channels;

public:

    /* Methods */

    /** Reverses a image upside down */
    void reverses();

    /** Loads an image from file */
    void loadImage(const char* path, int colorness);

    /** Creates header and allocates data for the image */
    void createImage(int width, int height, int depth, int n_channels );

    /** Create a file for the image */
    void saveImage(const char* file_name);

    /** Copies one array to another */
    void copy(Image* dst);

    /** Resize image */
    void resizeImage(Image* dst);

    /** Sets every element of array to given value */
    void setAllPixels(int c1, int c2, int c3);

    /* Access a specific pixel data */
    char* accessPixel(int x, int y);


    /* Accessor methods */


    /**
   * Set the value of width
   * @param new_var the new value of width
   */
    void setWidth ( int value );

    /**
   * Get the value of width
   * @return the value of width
   */
    int getWidth ( );

    /**
   * Set the value of height
   * @param new_var the new value of height
   */
    void setHeight ( int new_var );

    /**
   * Get the value of height
   * @return the value of height
   */
    int getHeight ( );

    /**
   * Set the value of widthStep
   * @param new_var the new value of widthStep
   */
    void setWidthStep ( int new_var );

    /**
   * Get the value of height
   * @return the value of height
   */
    int getWidthStep ( );

    /**
   * Set the value of image_data
   * @param new_var the new value of n_colors
   */
    void setImageData ( char* new_var );

    /**
   * Get the value of image_data
   * @return the value of n_colors
   */


    char* getImageData ( );

    /**
     * Set the value of src
     * @param new_var the new value of img
     */
    void setImg ( IplImage* new_var );

    /**
     * Get the value of image_data
     * @return the value of img
     */

    IplImage* getImg ( );

    /**
     * Get the value of image_data
     * @return the value of img
     */

    int getNchannels ( );

};

#endif // IMAGE_H
