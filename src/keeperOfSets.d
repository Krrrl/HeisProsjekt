import std.stdio,
       std.datetime;

import main,
       messenger,
       operator,
       channels;

class ext_elevator_t{
	public:
	bool[int] upQueue;
	bool[int] downQueue;
	bool[int] internalQueue;
	state_t currentState;
	int currentFloor;
	long lastTimestamp;
	ubyte ID;
}
	


ubyte findMatch(int orderFloor, button_type_t orderDirection)
{
	if(orderDirection == button_type_t.INTERNAL)
		{
			return getMyID();
		}
	return 0;
}

private ext_elevator_t[ubyte] aliveElevators;
private ext_elevator_t[ubyte] inactiveElevators;


void addToList(ubyte targetID, button_type_t orderDirection, int orderFloor)
{
	switch(orderDirection)
	{
		case button_type_t.DOWN:
		{
			if(orderFloor !in aliveElevators[targetID].upQueue)
			{
                aliveElevators[targetID].downQueue[orderFloor] = true;
			}	
			break;
		}

		case button_type_t.UP:
		{
			if(orderFloor !in aliveElevators[targetID].downQueue)
			{
                aliveElevators[targetID].upQueue[orderFloor] = true;
			}	
			break;
		}

		case button_type_t.INTERNAL:
		{
			if(orderFloor !in aliveElevators[targetID].internalQueue)
			{
                aliveElevators[targetID].internalQueue[orderFloor] = true;
			}	
			break;
		}
        default:
        {
            break;
        }
	}
}

void removeFromList(ubyte targetID, button_type_t orderDirection, int orderFloor)
{
	switch(orderDirection)
	{
		case button_type_t.DOWN:
		{
			if(orderFloor in aliveElevators[targetID].downQueue)
			{	
				aliveElevators[targetID].downQueue.remove(orderFloor);
			}
			break;
		}

		case button_type_t.UP:
		{
			if(orderFloor in aliveElevators[targetID].upQueue)
			{
				aliveElevators[targetID].upQueue.remove(orderFloor);
			}	
			break;
		}

		case button_type_t.INTERNAL:
		{
			if(orderFloor in aliveElevators[targetID].internalQueue)
			{
				aliveElevators[targetID].internalQueue.remove(orderFloor);
			}
			break;
		}
        default:
        {
            break;
        }
	}
}

void updateHeartbeat(ubyte targetID, state_t currentState, int currentFloor, long timestamp)
{
	aliveElevators[targetID].currentState = currentState;
	aliveElevators[targetID].currentFloor = currentFloor;
	aliveElevators[targetID].lastTimestamp = timestamp;
}

void sendSyncInfo(ubyte targetID)
{

}

void syncMySet(shared bool[int] internalSet)
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
			switch(receivedFromNetwork.header)
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
                default:
                {
                    break;
                }
			}
		}	
	}
}
