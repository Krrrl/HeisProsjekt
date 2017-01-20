# TOP is set to the same path as the makefile
TOP := $(dir $(lastword $(MAKEFILE_LIST)))

SRC_DIR = ./src/
#OBJS = test.o

make:
	gdc ${TOP}src/test.d

clean:
	rm *.out
