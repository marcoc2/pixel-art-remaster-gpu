# pixel-art-remaster-gpu
## Real Time Pixel Art Remasterization on GPUs with CUDA

This is my master's degree work and was presented on the XXVI Conference on Graphics, Patterns and Images (SIBGRAPI).
The following image is taken from this publication:

![Article figure](images/paper_figure.png?raw=true "Article figure")

## Article Abstract

_Several methods have been proposed to overcome the pixel art scaling problem through the years. In this article we describe a novel approach to be applied through a massively parallel architecture that can address this issue in real time. To achieve this we design a local and context independent algorithm that enables an efficient parallel implementation on the GPU, delivering full frames output at response time for the user interaction. Our main goal is to apply the method on full frames of old games, which were based on pixel art graphics until the half of the 1990's, and keep the output frame rate good enough for playing._

## Technologies

* **Language**: C++
* **GPU Computing**: CUDA
* **Rendering**: OpenGL + GLUT/FreeGLUT
* **Image Processing**: OpenCV (for image loading and handling)
* **Build System**: qmake (Qt) / Makefile

## Algorithm Overview

The algorithm performs real-time pixel art remasterization through the following pipeline:

1. **Graph Construction**: Analyzes pixel similarity to create a connectivity graph
2. **Cross Checking**: Resolves ambiguous connections (trivial and heuristic passes)
3. **Voronoi Diagram**: Creates diagrams for each pixel cell based on graph topology
4. **Subdivision** (optional): Smooths edges by subdividing based on color similarity
5. **Triangulation**: Converts diagrams into triangle meshes for GPU rendering

All stages run as CUDA kernels on the GPU, enabling real-time processing.

## Requirements

### Hardware
- NVIDIA GPU with CUDA support (compute capability 3.0 or higher)

### Software
- **CUDA Toolkit**: Version 8.0 or higher (tested with 12.8)
- **OpenCV**: Version 3.0 or higher (tested with 4.x)
- **OpenGL**: OpenGL 2.0 or higher
- **GLUT/FreeGLUT**: For window management
- **GLEW**: OpenGL Extension Wrangler
- **Qt5**: For build system (qmake)
- **GCC/G++**: C++ compiler

### Ubuntu/Debian Installation
```bash
sudo apt-get update
sudo apt-get install nvidia-cuda-toolkit
sudo apt-get install libopencv-dev
sudo apt-get install freeglut3-dev
sudo apt-get install libglew-dev
sudo apt-get install qt5-qmake qtbase5-dev
```

## Building

### Using Make (recommended)
```bash
make clean
make
```

The executable will be created at `../bin/depixel_gpu`

### Using Qt Creator
1. Open `depixel_gpu.pro` in Qt Creator
2. Configure the project paths if needed
3. Build the project

### Build Configuration
Edit the `Makefile` or `.pro` file if you need to adjust:
- CUDA installation path (default: `/usr/local/cuda`)
- OpenCV include path (default: `/usr/include/opencv4`)
- Library paths

## Usage

### Basic Usage
```bash
../bin/depixel_gpu <image_path>
```

### Example
```bash
../bin/depixel_gpu images/paper_figure.png
```

If no image path is provided, a default test image will be loaded.

### Keyboard Controls
- **ESC**: Exit application
- **o**: Switch to VERTEX_RENDER mode (CPU-based rendering)
- **p**: Switch to VBO_RENDER mode (GPU-accelerated rendering)
- **q**: Switch to QUAD mode (original pixel art view)
- **a**: Toggle antialiasing on/off
- **s**: Toggle edge subdivision on/off
- **d/D**: Cycle through debug draw modes

### Mouse Controls
- **Left button + drag**: Rotate view
- **Right button + drag**: Pan view
- **Middle button + drag**: Zoom in/out
- **Scroll wheel up**: Zoom in
- **Scroll wheel down**: Zoom out

## Rendering Modes

### VBO_RENDER (Default)
- **Performance**: Fastest
- **Requirements**: OpenGL-CUDA interoperability
- **Description**: CUDA writes directly to OpenGL Vertex Buffer Objects
- **Status**: May not work on modern CUDA (12.x) due to deprecated APIs

### VERTEX_RENDER (Fallback)
- **Performance**: Good
- **Requirements**: None (always available)
- **Description**: CUDA processes geometry, CPU renders with traditional OpenGL
- **Status**: Automatically enabled when VBO mode fails

### QUAD Mode
- **Performance**: Slowest
- **Description**: Renders original pixel art as quads (no processing)
- **Usage**: For comparison with processed output

## Compatibility Notes

### Modern CUDA Support
This codebase was originally developed for CUDA 3.x (circa 2016). It has been updated for compatibility with modern CUDA versions (12.x):

**What was updated:**
- Removed deprecated `rendercheck_gl.h` and `helper_cuda_gl.h` headers
- Updated deprecated CUDA APIs:
  - `cudaThreadSynchronize()` → `cudaDeviceSynchronize()`
  - `cudaThreadExit()` → `cudaDeviceReset()`
  - `cudaGLSetGLDevice()` → `cudaSetDevice()`
- Added OpenCV legacy C API headers for IplImage compatibility
- Updated OpenCV constants (CV_LOAD_IMAGE_COLOR → cv::IMREAD_COLOR, etc.)
- Implemented fallback rendering when OpenGL-CUDA interop is unavailable

**Known Limitations:**
- OpenGL-CUDA interoperability (`cudaGLRegisterBufferObject`) is deprecated and may fail on CUDA 12.x
- When GL interop fails, the application automatically switches to VERTEX_RENDER mode
- VERTEX_RENDER mode is slightly slower but fully functional

### OpenCV 4.x Support
Updated to work with modern OpenCV while maintaining compatibility with legacy IplImage-based code:
- Image loading uses modern `cv::imread()` and `cv::Mat`
- Images are converted to IplImage format for internal processing
- Image saving uses modern `cv::imwrite()`

## Troubleshooting

### "CUDA-capable device(s) is/are busy or unavailable"
- Make sure no other CUDA application is using the GPU
- Check that NVIDIA drivers are properly installed: `nvidia-smi`
- Verify CUDA installation: `nvcc --version`

### "failed to open display"
- Ensure X11 is running (for GUI applications)
- Set DISPLAY variable: `export DISPLAY=:0`
- For SSH: enable X11 forwarding with `ssh -X`

### "cudaGLRegisterBufferObject failed: unknown error"
- This is expected on CUDA 12.x and is handled automatically
- The application will fall back to VERTEX_RENDER mode
- No action needed - this is normal behavior

### Black/Empty Window
- Try switching render modes with 'o', 'p', or 'q' keys
- Check console output for CUDA kernel errors
- Verify image loaded correctly (check console for dimensions)

### Compilation Errors
- Ensure all dependencies are installed
- Check CUDA toolkit version compatibility
- Verify OpenCV and GLUT development packages are installed
- Update library paths in Makefile if needed

## Project Structure

```
pixel-art-remaster-gpu/
├── main.cpp              # Entry point, OpenGL initialization
├── callbacks.cpp         # GLUT callbacks (keyboard, mouse, display)
├── simpleVBO.cpp         # VBO management, CUDA-OpenGL interop
├── Image.h/cpp           # Image wrapper class (OpenCV bridge)
├── kernel.cu             # Main CUDA kernel launcher
├── graph_functions.cu    # Graph construction kernels
├── diagram_functions.cu  # Voronoi diagram kernels
├── triangulate_functions.cu  # Triangulation kernels
├── subdivision_functions.cu  # Edge subdivision kernels
├── point.cu              # Point structure definition
├── Makefile              # Build configuration
├── depixel_gpu.pro       # Qt project file
└── images/               # Test images
```

## Performance

The algorithm is designed for real-time processing:
- Typical performance: 30-60 FPS for 1024×768 images on modern GPUs
- Performance depends on:
  - Image resolution (complexity grows with pixel count)
  - GPU compute capability
  - Rendering mode (VBO_RENDER faster than VERTEX_RENDER)
  - Subdivision enabled/disabled (subdivision adds overhead)

## Citation

If you use this work in your research, please cite the original paper:

```bibtex
@inproceedings{silva2013pixel,
  title={Real Time Pixel Art Remasterization on GPUs},
  author={Silva, Marco and Teixeira, Lucas and Cavalcanti-Junior, Francisco and Vidal, Creto},
  booktitle={2013 XXVI Conference on Graphics, Patterns and Images},
  pages={2--9},
  year={2013},
  organization={IEEE}
}
```

## License

See LICENSE.txt for details.

## Acknowledgments

Original implementation developed as part of master's degree research at Universidade Federal do Ceará (UFC).

Modernization updates (2025) for compatibility with CUDA 12.x, OpenCV 4.x, and current development environments.
