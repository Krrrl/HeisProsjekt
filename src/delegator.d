import std.stdio,
       std.datetime,
       core.time;

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
        ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn)
{
	/* Construct prevState for all buttons */
	bool[main.nrOfFloors][main.nrOfButtons] buttonPrevMatrix = false;
    message_t newOrder;

	/* Check button states and register new presses as orders */
    while (true)
    {
        foreach (floor; 0..main.nrOfFloors)
        {
            foreach (buttonType; button_types_t())
            {
                bool buttonState        = cast(bool)(elev_get_button_signal(cast(elev_button_type_t)(buttonType), floor));
                bool prevButtonState    = buttonPrevMatrix[cast(int)(buttonType)][floor];

                if (buttonState && !prevButtonState)
                {
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
		message_t newOrder;
		message_t confirmationReceived;
		bool waitingForConfirmation = false;
		int timeoutCounter;
		
		/* Delegate new orders */
		if(!waitingForConfirmation)
		{
			if(ordersToBeDelegatedChn.extract(newOrder))
			{
				createDelegateOrder(newOrder);
				toNetworkChn.insert(newOrder);
				waitingForConfirmation = true;
				MonoTime timeOfSending = MonoTime.currTime;
				timeoutCounter = 0;

                /* Wait for confirm for a number of retries */
				while(timeoutCounter < timeoutCounterThreshold)
				{
                    /* Break condition for outer loop */
					if(!waitingForConfirmation)
					{
						break;
					}

                    /* Check for confirmations untill timeout or a confirmation is received  */
					while((MonoTime.currTime - timeOfSending) < confirmationTimeoutThreshold)
					{
						if(orderConfirmationsReceivedChn.extract(confirmationReceived))
						{
							if(confirmationReceived.targetID == messenger.getMyID())
							{
								debug writelnRed("Delegator speaking: received the appropriet confirmation within the timeoutThreshold, wooho!");
								waitingForConfirmation = false;
								break;
							}
						}
					}
                    
                    /* If timed out, increase timeoutcounter */
					if((MonoTime.currTime - timeOfSending) > confirmationTimeoutThreshold)
					{
						timeoutCounter++;
                        debug writelnRed("Delegator speaking: timeout, counter is now:");
                        debug writeln(timeoutCounter);
						toNetworkChn.insert(newOrder);
						timeOfSending = MonoTime.currTime;
					}
				}

                /* Throw back any unconfirmed order to be delegated again */
				if(waitingForConfirmation)
				{
                    debug writelnRed("Delegator speaking: Back of the line with you!");
                    ordersToBeDelegatedChn.insert(newOrder);
                    waitingForConfirmation = false;
				}
			}
		}		
	}
}
