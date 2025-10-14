#
# Project configuration
#
TEMPLATE = app
CONFIG += console
CONFIG -= qt
DESTDIR = ../bin

#
# Source and header files
#
SOURCES += main.cpp Image.cpp simpleVBO.cpp callbacks.cpp
HEADERS += Image.h

#
# Library dependencies using pkg-config
#
CONFIG += link_pkgconfig
PKGCONFIG += opencv4 gl glu glut glew

#
# CUDA configuration
#
CUDA_SOURCES = kernel.cu
CUDA_DIR = /usr/local/cuda
NVCCFLAGS = -m64 --compiler-options -fno-strict-aliasing
INCLUDEPATH += $$CUDA_DIR/include
LIBS += -L$$CUDA_DIR/lib64 -lcudart

#
# Custom compiler definition for CUDA files (.cu)
#
cuda.input = CUDA_SOURCES
cuda.output = Obj/${QMAKE_FILE_BASE}.o
cuda.commands = nvcc $$NVCCFLAGS -c ${QMAKE_FILE_NAME} -o ${QMAKE_FILE_OUT}
cuda.dependency_type = TYPE_C
cuda.variable_out = OBJECTS
QMAKE_EXTRA_COMPILERS += cuda

#
# Directory for object files
#
OBJECTS_DIR = Obj
