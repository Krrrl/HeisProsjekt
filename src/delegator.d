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
	ref shared NonBlockingChannel!string locallyPlacedOrdersChn)
{
	string localOrderInstance;

	while (true)
	{
		if (locallyPlacedOrdersChn.extract(localOrderInstance))
		{
             //int bestElevator = findClosestElevator(localOrderInstance); // keeper of sets has information, how to get it?
            // message_t = 

		}
	}
}


