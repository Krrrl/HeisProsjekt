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

/*
 * @brief   Thread responsible for operating the lift and carrying out orders delegated to this elevator
 * @details Implemented with a state machine
 *
 * param toElevatorChn: channel directed to this elevator
 * param toNetworkChn: channel directed to external network
 */
void operatorThread(
	ref shared NonBlockingChannel!order_t toElevatorChn,
	ref shared NonBlockingChannel!order_t toNetworkChn
	)
{
	debug writeln("    [x] operatorThread");

	shared static order_t testOrder = {
		type : order_header_t.delegateOrder,
		senderID : "1",
		targetID : "2",
		orderDeclaration : "goUp",
		currentState : state_t.GOING_UP,
		currentFloor : 1,
		timestamp : 0
	};

    Thread.sleep(seconds(1));

	// Construct prevState for all buttons
	bool[main.nrOfFloors][3] buttonPrevMatrix = false;

	while (true)
	{
        writeln("true?");
		// Check panels
		foreach (floor; 0..main.nrOfFloors)
		{
            writeln(floor);
			foreach (buttonType; elevButtonTypes())
			{
                bool buttonState = cast(bool)(elev_get_button_signal(buttonType, floor));
                bool prevButtonState = buttonPrevMatrix[cast(int)(buttonType)][floor];
                debug writeln(buttonState);

				if (buttonState && !prevButtonState)
                {
					debug writeln("buttontype:", buttonType, "pressed on floor ", floor);

                    buttonPrevMatrix[cast(int)(buttonType)][floor] = true;
                }
                else if (!buttonState && prevButtonState)
                {
                    buttonPrevMatrix[cast(int)(buttonType)][floor] = false;
                }
			}
		}


		// Check lift sensors
	}
}




