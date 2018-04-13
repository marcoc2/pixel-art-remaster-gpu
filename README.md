# pixel-art-remaster-gpu
## Real Time Pixel Art Remasterization on GPUs with CUDA

This is my master's degree work and was presented on the XXVI Conference on Graphics, Patterns and Images (SIBGRAPI).
The following image is taken from this publication:

![A article](images/paper_figure.png?raw=true "Article figure")

## Article abstract

_Several methods have been proposed to overcome the pixel art scaling problem through the years. In this article we describe a novel approach to be applied through a massively parallel architecture that can address this issue in real time. To achieve this we design a local and context independent algorithm that enables an efficient parallel implementation on the GPU, delivering full frames output at response time for the user interaction. Our main goal is to apply the method on full frames of old games, which were based on pixel art graphics until the half of the 1990's, and keep the output frame rate good enough for playing._

## Code

* **Overall**: C++
* **GPU**: CUDA
* **Rendering**: OpenGL
* **Image**: OpenCV (only image opening and handling)

## Building
Open .pro file on QtCreator, edit lib paths and compile.
