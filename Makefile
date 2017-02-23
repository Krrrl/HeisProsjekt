# Which C compiler to use
CC = gcc
# C compiler flags
CFLAGS = -std=gnu11 -g -Wall -Wextra

# Which D compiler to use
DD = dmd
# D compiler flags
DFLAGS = -debug -odbuild 
# Linker flags
LDFLAGS = -Lcomedi
COMEDILIB = /usr/lib/libcomedi.a # TODO: check if this works on all computers

# TOP is set to the same path as the makefile
TOP := $(dir $(lastword $(MAKEFILE_LIST)))

# Directories
D_SRC_DIR = ${TOP}src/
CLIB_DIR = ${TOP}driver/
NET_DIR = $(TOP)Network-D/net/
SIM_DIR = $(TOP)simulator/server/

# Source files
D_SRC = $(wildcard $(D_SRC_DIR)*.d)
CLIB_SRC = $(wildcard $(CLIB_DIR)*.c)
CHANNELS_SRC = $(TOP)channels/channels.d
NET_SRC = $(wildcard $(NET_DIR)*.d) $(NET_DIR)d-json/jsonx.d
SIM_SRC = $(wildcard $(SIM_DIR)*.d)
ALL_SRC_FILES = $(D_SRC) $(CHANNELS_SRC) $(NET_SRC)

# Object files
CLIB_OBJ = $(CLIB_SRC:.c=.o)
CLIB_FILES = $(CLIB_SRC:.c=)

TARGET = best_elevator
SIM_TARGET = sim_server

# Make rules begin here

# I tried to explain some syntax for rules here:
# ruleNamE: [any dependencies (optional!)]
# 	after rule and dependencies the lines must be indented (with TAB, spaces are not accepted)
# 	every indented line is a command that is executed when the rule is run
# 	to run a specific rule: $ make ruleName
#	dependencies can be other rules, then those dependant rules are run before this one
#	dependencies can be also be variables like CLIB_OBJ below, then the rule corresponing to the variable is run
#	when dependencies are variables/'lists of files', make scans the files and checks if they have been changed. it will only run the rule corresponing to the dependency if they have changed.
#	running: $ make , without any argument either starts the 'all' rule or starts at the top rule

build: $(CLIB_OBJ) $(D_SRC) $(SIM_TARGET)
	$(DD) $(DFLAGS) $(ALL_SRC_FILES) $(CLIB_OBJ) $(COMEDILIB) -of$(TARGET) 

$(CLIB_OBJ): $(CLIB_SRC)
	@echo "Compiling elevator driver object files... "
	for file in $(CLIB_FILES); do \
		$(CC) $(CFLAGS) -c $$file.c -o $$file.o ; \
	done

$(SIM_TARGET):
	$(DD) $(DFLAGS) $(SIM_SRC) -of$(SIM_TARGET)

clean:
	rm -r ./build
	rm $(CLIB_OBJ) $(TARGET) $(SIM_TARGET)

test:
	@echo "TOP =" $(TOP)
	@echo "C objects =" $(CLIB_OBJ)
	@echo "All src =" $(ALL_SRC_FILES)
