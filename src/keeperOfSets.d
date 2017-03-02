import std.stdio;

import messenger,
       channels;

class{
	public:
	string upQueue[main.nrOfFloors];
	string downQueue[main.nrOfFloors];
	string internalOrders[main.nrOfFloors];
	state_t currentState;
	int currentFloor;
	int lastTimestamp;
	ubyte ID;
	
	string[] getQueue(direction_t);
}ext_elevator_t;


ubyte findMatch(int orderFloor, direction_t orderDirection)
{
	if(orderDirection == "INTERNAL")
		{
			return messenger.myID;
		}

}




private int upQueue[main.nrOfFloors];
private int downQueue[main.nrOfFloors];
private int internalQueue[main.nrOfFloors];
public state_t currentState;
public int currentFloor;

private ext_elevator_t[ubyte] aliveElevators;
private ext_elevator_t[ubyte] inactiveElevators;


message_t confirmOrderToNetwork(string orderDeclaration, messenger.myID)
{
		
	
}
	
message_t expediteOrderToNetwork(string orderDeclaration, messenger.myID)
{
	
	
}
	
	
string nextInQueue(direction_t)
{
	
			
}

void addToList(ubyte targetID, direction_t orderDirection, int orderFloor)
{
	switch(orderDirection)
	{
		case "DOWN"
		{
			if(orderFloor (not in) aliveElevators[targetID].downQueue)
			{
				aliveElevators[targetID].downQueue.append(orderFloor);
			}
			break;
		}

		case "UP"
		{
			if(orderFloor (not in) aliveElevators[targetID].upQueue)
			{
				aliveElevators[targetID].upQueue.append(orderFloor);
			}
			break;
		}

		case "INTERNAL"
		{
			if(orderFloor (not in) aliveElevators[targetID].internalQueue)
			{
				aliveElevators[targetID].internalQueue.append(orderFloor);
			}
			break;
		}
	}
}

void removeFromList(ubyte targetID, direction_t orderDirection, int orderFloor)
{
	switch(orderDirection)
	{
		case "DOWN"
		{
			if(orderFloor in aliveElevators[targetID].downQueue)
			{	
				aliveElevators[targetID].downQueue.append(orderFloor);
			}
			break;
		}

		case "UP"
		{
			if(orderFloor in aliveElevators[targetID].upQueue)
			{
				aliveElevators[targetID].upQueue.append(orderFloor);
			}	
			break;
		}

		case "INTERNAL"
		{
			if(orderFloor in aliveElevators[targetID].internalQueue)
			{
				aliveElevators[targetID].internalQueue.append(orderFloor);
			}
			break;
		}
	}
}

void updateHeartbeat(targetID, state_t currentState, int currentFloor, int timestamp)
{
	aliveElevators[targetID]->currentState = currentState;
	aliveElevators[targetID]->currentFloor = currentFloor;
	aliveElevators[targetID]->lastTimestamp = timestamp;
}

void sendSyncInfo(targetID)
{

}

ubyte highestID()
{
	ubyte highestID = messenger.myID;
	foreach(elevator; aliveElevators)
	{
		if(messenger.myID < elevator.ID)
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

	//Generate your own sets


	//Generate sets for all other elevators
	foreach(int elev; 0..main.nrOfElevators - 1)
	{
		
	}
		
	while(true)
	{
		if(toElevatorChn.extract(receivedFromNetwork))
		{
			debug{writeln("Received from toElevChn: ", receivedFromNetwork)};
			switch(receivedFromNetwork.message_header_t)
			{
				case delegateOrder
				{
					if(receivedFromNetwork.targetID == messenger.myID)
					{
						addToList(messenger.myID, receivedFromNetwork.orderDirection, receivedFromNetwork.orderFloor);
					}
					break;
				}

				case confirmOrder
				{
					addToList(receivedFromNetwork.senderID, orderDirection, orderFloor);
					break;
				}

				case expediteOrder
				{
					removeFromList(receivedFromNetwork.senderID, orderDirection, orderFloor);
					break;
				}

				case syncRequest
				{
					if(messenger.myID == highestID())
					{
						//sendSyncInfo(receivedFromNetwork.senderID);
					}
					break;
				}

				case syncInfo
				{
					if(messenger.myID == receivedFromNetwork.targetID)
					{
						//syncMySet();
					}
					break;
				}

				case heartbeat
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
	
	

	
	message_t receivedFromNetwork;
	string localOrderInstance;

	while (true)
	{
		if (toElevatorChn.extract(receivedFromNetwork))
		{
            debug {
                writeln("keeperOfSets: received ");
                //printOrder(receivedFromNetwork);
            }
/*
			switch (receivedFromNetwork.type)
			{
                case order_header_t.delegateOrder:
                {
                    //if .targetIDessenger.myID
                    //add to my own set
                    //post orderConfirmation to toNetworkChn
                }
                case order_header_t.confirmOrder:
                {
                    //update sender's order set
                    //set light in
                }
                case order_header_t.expediteOrder:
                {
                    //remove order from sender's order set
                    //remove light
                    //
                }
                case order_header_t.syncRequest:
                {
                    //if myIP is the highest of my peers
                    // post syncInfo(.senderID) to toNetworkChn
                }
                case order_header_t.heartBeat:
                {
                    //update senders state set
                    //let watchdog know?
                }
                default:
                    //discard message
			}
            */
		}
		//orders from IO
		//Delegate, then post to toNetwork
		if (locallyPlacedOrdersChn.extract(localOrderInstance))
		{
			//message_t = delegateOrder(localOrderInstance);

		}
	}
	//lage egne liste
	//lage liste for de andre heisan
}
