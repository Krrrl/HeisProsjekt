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
	newOrder.currentFloor   = getPreviousValidFloor();
	newOrder.timestamp      = Clock.currTime().toUnixTime();
	newOrder.targetID       = findMatch(newOrder.orderFloor, newOrder.orderDirection);
}

const private Duration confirmationTimeoutThreshold = dur!"msecs"(200);
const private int timeoutCounterThreshold = 5;

/*
 * @brief Thread responsible for delegating orders that haven't been delegated yet
 *
 * @param toElevatorChn: channel directed to this elevator
 * @param locallyPlacedOrdersChn: channel with
 */

void buttonCheckerThread(
        ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn
        )
{
	/* Construct prevState for all buttons */
	bool[main.nrOfFloors][main.nrOfButtons] buttonPrevMatrix = false;

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
}

void delegatorThread(
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn,
	ref shared NonBlockingChannel!message_t orderConfirmationsReceivedChn
	)
{
	debug writelnGreen("    [x] delegatorThread");

	while (true)
	{

		/* Delegate new orders */
		message_t newOrder;
		message_t confirmationReceived;
		bool currentlySending = false;
		int timeoutCounter;
		
		if(!currentlySending)
		{
			if(ordersToBeDelegatedChn.extract(newOrder))
			{
				createDelegateOrder(newOrder);
				toNetworkChn.insert(newOrder);
				currentlySending = true;
				auto timeOfSending = Clock.currTime().fracSecs();
				timeoutCounter = 0;

				while(timeoutCounter < timeoutCounterThreshold)
				{
					if(!currentlySending)
					{
						break;
					}

					while((Clock.currTime().fracSecs() - timeOfSending) < confirmationTimeoutThreshold)
					{
						if(orderConfirmationsReceivedChn.extract(confirmationReceived))
						{
							if(confirmationReceived.targetID == messenger.getMyID())
							{
								debug writelnYellow("Delegator speaking: received the appropriet confirmation within the timeoutThreshold, wooho!");
								currentlySending = false;
								break;
							}
						}
					}
					if((Clock.currTime().fracSecs() - timeOfSending) > confirmationTimeoutThreshold)
					{
						timeoutCounter++;
						toNetworkChn.insert(newOrder);
						timeOfSending = Clock.currTime().fracSecs();
					}
				}

				if(currentlySending)
				{
				debug writelnYellow("Delegator: Back of the line with you!");
				ordersToBeDelegatedChn.insert(newOrder);
				currentlySending = false;
				}
			}
		}		
	}
}
