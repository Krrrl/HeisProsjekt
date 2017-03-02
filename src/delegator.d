import std.stdio;

import channels,
       keeperOfSets,
       messenger;

/*
 * @brief Thread responsible for delegating orders that haven't been delegated yet
 *
 * @param toElevatorChn: channel directed to this elevator
 * @param locallyPlacedOrdersChn: channel with
 */
void delegatorThread(
    ref shared NonBlockingChannel!message_t toElevatorChn,
    ubyte elevatorID
    )
{

	// Construct prevState for all buttons
	bool[main.nrOfFloors][3] buttonPrevMatrix = false;
	shared static message_t testOrder = {
		type : message_header_t.delegateOrder,
		senderID : "1",
		targetID : "2",
        orderFloor : 2,
        orderDir : direction_t.DOWN,
		currentState : state_t.GOING_UP,
		currentFloor : 1,
		timestamp : 0
	};

	while (true)
	{
        /* Check button states and produce orders */
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

		if (locallyPlacedOrdersChn.extract(localOrderInstance))
		{
             //int bestElevator = findClosestElevator(localOrderInstance); // keeper of sets has information, how to get it?
            // message_t = 

		}
	}
}


