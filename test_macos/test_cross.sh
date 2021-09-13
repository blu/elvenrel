#!/bin/bash
BUILD=..

make -C ${BUILD} all

# Load two RELs with cross-relocations

${BUILD}/elvenrel test_cross_0.o test_cross_1.o
