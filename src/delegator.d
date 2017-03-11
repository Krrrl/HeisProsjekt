import std.stdio,
       std.datetime;

import main,
       debugUtils,
       channels,
       keeperOfSets,
       messenger,
       iolib,
       operator;

void createDelegateOrder(ref message_t newOrder)
{
	newOrder.senderID       = messenger.getMyID();
	newOrder.currentState   = getCurrentState();
	newOrder.currentFloor   = getCurrentFloor();
	newOrder.timestamp      = Clock.currTime().stdTime;
	newOrder.targetID       = findMatch(newOrder.orderFloor, newOrder.orderDirection);
}
/*
 * @brief Thread responsible for delegating orders that haven't been delegated yet
 *
 * @param toElevatorChn: channel directed to this elevator
 * @param locallyPlacedOrdersChn: channel with
 */
void delegatorThread(
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn,
	)
{
	debug writelnGreen("    [x] delegatorThread");
	/* Construct prevState for all buttons */
	bool[main.nrOfFloors][main.nrOfButtons] buttonPrevMatrix = false;

	while (true)
	{
		/* Check button states and register new presses */
		// TODO: Should this be in a seperate thread? We don't want to miss any button presses dues to processing new orders
		foreach (floor; 0..main.nrOfFloors)
		{
			foreach (buttonType; button_types_t())
			{
				bool buttonState        = cast(bool)(elev_get_button_signal(cast(elev_button_type_t)(buttonType), floor));
				bool prevButtonState    = buttonPrevMatrix[cast(int)(buttonType)][floor];

				if (buttonState && !prevButtonState)
				{
					message_t newOrder;
					newOrder.orderFloor     = floor;
					newOrder.orderDirection = buttonType;
					ordersToBeDelegatedChn.insert(newOrder);

					buttonPrevMatrix[cast(int)(buttonType)][floor] = true;
				}
				else if (!buttonState && prevButtonState)
					buttonPrevMatrix[cast(int)(buttonType)][floor] = false;
			}
		}

		/* Delegate new orders */
		message_t newOrder;
		if (ordersToBeDelegatedChn.extract(newOrder))
		{
			createDelegateOrder(newOrder);

			toNetworkChn.insert(newOrder);

			// TODO: Wait and check for confirm. Poll keeper for confirm? Po
		}
	}
}
