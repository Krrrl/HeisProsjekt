/*  Declare external C enums and functions from elev.h lib
    dmd will be happy as long as they are declared correctly
*/

enum elev_motor_direction_t { 
    DIRN_DOWN = -1,
    DIRN_STOP = 0,
    DIRN_UP = 1
}

enum elev_button_type_t { 
    BUTTON_CALL_UP = 0,
    BUTTON_CALL_DOWN = 1,
    BUTTON_COMMAND = 2
}


extern (C) void elev_init();

extern (C) void elev_set_motor_direction(elev_motor_direction_t dirn);
extern (C) void elev_set_button_lamp(elev_button_type_t button, int floor, int value);
extern (C) void elev_set_floor_indicator(int floor);
extern (C) void elev_set_door_open_lamp(int value);
extern (C) void elev_set_stop_lamp(int value);

extern (C) int elev_get_button_signal(elev_button_type_t button, int floor);
extern (C) int elev_get_floor_sensor_signal();
extern (C) int elev_get_stop_signal();
extern (C) int elev_get_obstruction_signal();



