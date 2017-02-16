# Which C compiler to use
CC = gcc
# C compiler flags
CFLAGS = -std=gnu11 -g -Wall -Wextra

# Which D compiler to use
DD = dmd
# Linker flags
LDFLAGS = -lcomedi -lm

# TOP is set to the same path as the makefile
TOP := $(dir $(lastword $(MAKEFILE_LIST)))

# Directories
D_SRC_DIR = ${TOP}src/
CLIB_DIR = ${TOP}driver/
NET_DIR = $(TOP)Network-D/net/

# Source files
D_SRC = $(wildcard $(D_SRC_DIR)*.d)
CLIB_SRC = $(wildcard $(CLIB_DIR)*.c)
CHANNELS_SRC = $(TOP)channels/channels.d
NET_SRC = $(wildcard $(NET_DIR)*.d) $(NET_DIR)d-json/jsonx.d
ALL_SRC_FILES = $(D_SRC) $(CHANNELS_SRC) $(NET_SRC)

# Object files
CLIB_OBJ = $(CLIB_SRC:.c=.o)
CLIB_FILES = $(CLIB_SRC:.c=)

TARGET = best_elevator

# Make rules begin here

make: cDriver $(D_SRC)
	$(DD) $(ALL_SRC_FILES) $(CLIB_OBJ) #-offilename $(TARGET)

cDriver: $(CLIB_SRC)
	@echo "Compiling elevator driver object files... "
	for file in $(CLIB_FILES); do \
		$(CC) $(CFLAGS) -c $$file.c -o $$file.o ; \
	done

clean:
	rm $(CLIB_OBJ) $(TARGET)

test:
	@echo "TOP =" $(TOP)
	@echo "C objects =" $(CLIB_OBJ)
	@echo "All src =" $(ALL_SRC_FILES)
