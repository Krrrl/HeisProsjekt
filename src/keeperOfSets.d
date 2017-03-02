import std.stdio;

import main,
       messenger,
       operator,
       channels;

class ext_elevator_t{
	public:
	int[int] upQueue;
	int[int] downQueue;
	int[int] internalOrders;
	state_t currentState;
	int currentFloor;
	int lastTimestamp;
	ubyte ID;
}
	


ubyte findMatch(int orderFloor, direction_t orderDirection)
{
	if(orderDirection == direction_t.INTERNAL)
		{
			return getMyID();
		}
	return 0;
}

private ext_elevator_t[ubyte] aliveElevators;
private ext_elevator_t[ubyte] inactiveElevators;


void addToList(ubyte targetID, direction_t orderDirection, int orderFloor)
{
	switch(orderDirection)
	{
		case direction_t.DOWN:
		{
			if(orderFloor !in aliveElevators[targetID].downQueue)
			{
				aliveElevators[targetID].downQueue ~= orderFloor;
			}
			break;
		}

		case direction_t.UP:
		{
			if(orderFloor !in aliveElevators[targetID].upQueue)
			{
				aliveElevators[targetID].upQueue ~= orderFloor;
			}
			break;
		}

		case direction_t.INTERNAL:
		{
			if(orderFloor !in aliveElevators[targetID].internalQueue)
			{
				aliveElevators[targetID].internalQueue ~= orderFloor;
			}
			break;
		}
	}
}

void removeFromList(ubyte targetID, direction_t orderDirection, int orderFloor)
{
	switch(orderDirection)
	{
		case direction_t.DOWN:
		{
			if(orderFloor in aliveElevators[targetID].downQueue)
			{	
				aliveElevators[targetID].downQueue.remove(orderFloor);
			}
			break;
		}

		case direction_t.UP:
		{
			if(orderFloor in aliveElevators[targetID].upQueue)
			{
				aliveElevators[targetID].upQueue.remove(orderFloor);
			}	
			break;
		}

		case direction_t.INTERNAL:
		{
			if(orderFloor in aliveElevators[targetID].internalQueue)
			{
				aliveElevators[targetID].internalQueue.remove(orderFloor);
			}
			break;
		}
	}
}

void updateHeartbeat(ubyte targetID, state_t currentState, int currentFloor, int timestamp)
{
	aliveElevators[targetID].currentState = currentState;
	aliveElevators[targetID].currentFloor = currentFloor;
	aliveElevators[targetID].lastTimestamp = timestamp;
}

void sendSyncInfo(ubyte targetID)
{

}

void syncMySet(int[] internalSet)
{

}

ubyte highestID()
{
	ubyte highestID = getMyID();
	foreach(elevator; aliveElevators)
	{
		if(getMyID() < elevator.ID)
		{
			highestID = elevator.ID;
		}

	}
	return highestID;
}

void keeperOfSetsThread(
		shared NonBlockingChannel!message_t toNetworkChn,
		shared NonBlockingChannel!message_t toElevatorChn,
		shared NonBlockingChannel!message_t watchdogFeedChn)
{
	debug
	{
		writeln("    [x] keeperOfSetsThread");
	}

	ext_elevator_t localElevator;
	aliveElevators[getMyID()] = localElevator;

	message_t receivedFromNetwork;

	while (true)
	{
		if(toElevatorChn.extract(receivedFromNetwork))
		{
			debug{writeln("Received from toElevChn: ", receivedFromNetwork);}
			switch(receivedFromNetwork.message_header_t)
			{
				case message_header_t.delegateOrder:
				{
					if(receivedFromNetwork.targetID == getMyID())
					{
						addToList(getMyID(), 
								receivedFromNetwork.orderDirection, 
								receivedFromNetwork.orderFloor);
					}
					break;
				}

				case message_header_t.confirmOrder:
				{
					addToList(
							receivedFromNetwork.senderID,
							receivedFromNetwork.orderDirection, 
							receivedFromNetwork.orderFloor);
					break;
				}

				case message_header_t.expediteOrder:
				{
					removeFromList(
								receivedFromNetwork.senderID, 
								receivedFromNetwork.orderDirection, 
								receivedFromNetwork.orderFloor);
					break;
				}

				case message_header_t.syncRequest:
				{
					if(getMyID() == highestID())
					{
						sendSyncInfo(receivedFromNetwork.senderID);
					}
					break;
				}

				case message_header_t.syncInfo:
				{
					if(getMyID() == receivedFromNetwork.targetID)
					{
						syncMySet(receivedFromNetwork.syncInternalList);
					}
					break;
				}

				case message_header_t.heartbeat:
				{
					updateHeartbeat(receivedFromNetwork.senderID,
									receivedFromNetwork.currentState,
									receivedFromNetwork.currentFloor,
									receivedFromNetwork.timestamp);
					break;
				}
			}
		}	
	}
}
