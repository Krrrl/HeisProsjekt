import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency;

import udp_bcast,
       peers;

import channels,
       main,
       keeperOfSets,
       messenger,
       watchdog,
       iolib;


enum state_t
{
	INIT = 0,
	IDLE,
	GOING_DOWN,
	GOING_UP,
	FLOORSTOP
}

private shared state_t _currentState;
private shared int _currentFloor;

state_t getCurrentState()
{
	return _currentState;
}

int getCurrentFloor()
{
	return _currentFloor;
}

/*
 * @brief   Thread responsible for operating the lift and carrying out orders delegated to this elevator
 * @details Implemented with a state machine
 *
 * param toElevatorChn: channel directed to this elevator
 * param toNetworkChn: channel directed to external network
 */
void operatorThread(
	ref shared NonBlockingChannel!message_t toElevatorChn,
	ref shared NonBlockingChannel!message_t toNetworkChn
	)
{
	debug writeln("    [x] operatorThread");

	while (true)
	{

		// Check lift sensors
	}
}




