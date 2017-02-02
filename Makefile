# TOP is set to the same path as the makefile
TOP := $(dir $(lastword $(MAKEFILE_LIST)))

SRC_DIR = ${TOP}src

make:
	dmd ${SRC_DIR}/main.d ${SRC_DIR}/messenger.d ${SRC_DIR}/keeperOfSets.d

clean:
	rm *.out
