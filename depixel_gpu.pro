TEMPLATE = app
CONFIG += console
CONFIG -= qt

SOURCES += \
    main.cpp \
    Image.cpp \
    simpleVBO.cpp \
    callbacks.cpp \
    kernel.cu \
    graph_functions.cu \
    diagram_functions.cu \
    triangulate_functions.cu \
    point.cu \
    cc_functions.cu \
    subdivision_functions.cu

HEADERS += \
    Image.h

SOURCES -= \
    kernel.cu \
    graph_functions.cu \
    diagram_functions.cu \
    triangulate_functions.cu \
    cc_functions.cu \
    subdivision_functions.cu \
    point.cu

unix: CONFIG += link_pkgconfig
unix: PKGCONFIG += opencv

# Cuda sources
CUDA_SOURCES += \
    kernel.cu

# Project dir and outputs
PROJECT_DIR = $$system(pwd)
OBJECTS_DIR = $$PROJECT_DIR/Obj
DESTDIR = ./

# Path to cuda toolkit install
CUDA_DIR = /usr/local/cuda-7.5
# Path to cuda SDK install
CUDA_SDK = $$CUDA_DIR/samples
# GPU architecture
CUDA_ARCH = sm_20

# nvcc flags (ptxas option verbose is always useful)
NVCCFLAGS = --compiler-options -fno-strict-aliasing -use_fast_math

# include paths
INCLUDEPATH += $$CUDA_DIR/include
INCLUDEPATH += $$CUDA_SDK/common/inc/
# lib dirs
QMAKE_LIBDIR += $$CUDA_DIR/lib64
QMAKE_LIBDIR += $$CUDA_SDK/lib
QMAKE_LIBDIR += $$CUDA_SDK/common/lib

# libs - note than i'm using a x_86_64 machine
#LIBS += -lcudart

unix:!macx: LIBS += -L$$PWD/../../v3o2/dependencies/ext/freeglut/lib/Linux64e6/ -lglut

INCLUDEPATH += $$PWD/../../v3o2/dependencies/ext/freeglut/include
DEPENDPATH += $$PWD/../../v3o2/dependencies/ext/freeglut/include

unix:!macx: LIBS += -L$$PWD/../../v3o2/dependencies/ext/glew/lib/Linux64e6/ -lGLEW

INCLUDEPATH += $$PWD/../../v3o2/dependencies/ext/glew/include
DEPENDPATH += $$PWD/../../v3o2/dependencies/ext/glew/include

unix: LIBS += -L$$PWD/../../../../usr/local/cuda-7.5/lib64/ -lcudart

# join the includes in a line
CUDA_INC = $$join(INCLUDEPATH,' -I','-I',' ')

# Prepare the extra compiler configuration (taken from the nvidia forum - i'm not an expert in this part)
cuda.input = CUDA_SOURCES
cuda.output = ${OBJECTS_DIR}${QMAKE_FILE_BASE}_cuda.o

# For Debug, use this line
#cuda.commands = $$CUDA_DIR/bin/nvcc -m64 -g -G -arch=$$CUDA_ARCH -c $$NVCCFLAGS $$CUDA_INC $$LIBS  ${QMAKE_FILE_NAME} -o ${QMAKE_FILE_OUT}
cuda.commands = $$CUDA_DIR/bin/nvcc -m64 -arch=$$CUDA_ARCH -c $$NVCCFLAGS $$CUDA_INC $$LIBS  ${QMAKE_FILE_NAME} -o ${QMAKE_FILE_OUT}

cuda.dependency_type = TYPE_C
# For Debug, use this line
#cuda.depend_command = $$CUDA_DIR/bin/nvcc -g -G -M $$CUDA_INC $$NVCCFLAGS   ${QMAKE_FILE_NAME}
cuda.depend_command = $$CUDA_DIR/bin/nvcc -M $$CUDA_INC $$NVCCFLAGS  ${QMAKE_FILE_NAME}
# Tell Qt that we want add more stuff to the Makefile
QMAKE_EXTRA_COMPILERS += cuda

OTHER_FILES += \
    diagram_functions.bkp \
    triangulate_functions.bkp \
    kernel_backups.cuda \
    cc_kernel_call.bkp \
    vbo_img_kernel.bkp \
    notes.txt \
    subdivision_functions.bkp
