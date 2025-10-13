#!/bin/bash
BUILD=..

make -C ${BUILD} all > /dev/null

# Load three RELs with cross-relocations; nuke all VMAs from common libraries and
# the process heap VMA, before passing control to _start

${BUILD}/elvenrel msg_a.o msg_b.o test_order.o --quiet --filter /lib/aarch64-linux-gnu --filter [heap]
${BUILD}/elvenrel msg_b.o msg_a.o test_order.o --quiet --filter /lib/aarch64-linux-gnu --filter [heap]
