import std.stdio,
       std.datetime,
       std.algorithm.searching;

import main,
       debugUtils,
       messenger,
       operator,
       channels,
       peers;

struct elevator_t
{
public:
	bool[int] upQueue;
	bool[int] downQueue;
	bool[int] internalQueue;
	state_t currentState;
	int currentFloor;
	long lastTimestamp;
	ubyte ID;
}

private elevator_t[ubyte] aliveElevators;
private elevator_t[ubyte] inactiveElevators;

void reviveElevator(ubyte id)
{
    aliveElevators[id] = inactiveElevators[id];
    inactiveElevators.remove(id);
    debug writeln("keeper: elevator [", id, "] REVIVED");
}

void createElevator(ubyte id)
{
    aliveElevators[id] = elevator_t();
    debug writeln("keeper: new elevator [", id, "] ALLOCATED");
}

void retireElevator(ubyte id)
{
    inactiveElevators[id] = aliveElevators[id];
    aliveElevators.remove(id);
    debug writeln("keeper: elevator [", id, "] RETIRED");
}

ubyte findMatch(int orderFloor, button_type_t orderDirection)
{
	if (orderDirection == button_type_t.INTERNAL)
    {
		return getMyID();
    }

	elevator_t[ubyte] candidates = aliveElevators.dup;
	debug writeln("number of candidtes:", candidates.keys.length);

	// check for going in same direction?
	foreach (id; candidates.byKey)
	{
		if (cast(button_type_t)candidates[id].currentState != orderDirection && candidates.length > 1)
		{
			candidates.remove(id);
			debug writeln("removing candidate: ", id);
			debug writeln("remaining candidates: ", candidates);
		}
	}

	// check for being below/above?
	// check for smallest distance
	debug writeln("number of candidtes:", candidates.keys.length);
	return aliveElevators[candidates.keys[0]].ID;
}

void addToList(ubyte targetID, button_type_t orderDirection, int orderFloor)
{
	// TODO: check that targetID is in aliveElevators?
	if (targetID !in inactiveElevators)
	{
		// Do what? Error handling?
        debug writelnYellow("keeper: trying to add to inactive's list");
	}
	if (targetID !in aliveElevators)
		aliveElevators[targetID] = elevator_t();
	switch (orderDirection)
	{
	case button_type_t.DOWN:
	{
		if (orderFloor !in aliveElevators[targetID].upQueue)
			aliveElevators[targetID].downQueue[orderFloor] = true;
		break;
	}

	case button_type_t.UP:
	{
		if (orderFloor !in aliveElevators[targetID].downQueue)
			aliveElevators[targetID].upQueue[orderFloor] = true;
		break;
	}

	case button_type_t.INTERNAL:
	{
		if (orderFloor !in aliveElevators[targetID].internalQueue)
			aliveElevators[targetID].internalQueue[orderFloor] = true;
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
	if (targetID in aliveElevators)
	{
		switch (orderDirection)
		{
		case button_type_t.DOWN:
		{
			if (orderFloor in aliveElevators[targetID].downQueue)
				aliveElevators[targetID].downQueue.remove(orderFloor);
			break;
		}

		case button_type_t.UP:
		{
			if (orderFloor in aliveElevators[targetID].upQueue)
				aliveElevators[targetID].upQueue.remove(orderFloor);
			break;
		}

		case button_type_t.INTERNAL:
		{
			if (orderFloor in aliveElevators[targetID].internalQueue)
				aliveElevators[targetID].internalQueue.remove(orderFloor);
			break;
		}
		default:
		{
			break;
		}
		}
	}
}

void updateHeartbeat(ubyte targetID, state_t currentState, int currentFloor, long timestamp)
{
	aliveElevators[targetID].currentState   = currentState;
	aliveElevators[targetID].currentFloor   = currentFloor;
	aliveElevators[targetID].lastTimestamp  = timestamp;
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

	foreach (elevator; aliveElevators.byValue)
	{
		if (getMyID() < elevator.ID)
			highestID = elevator.ID;

	}
	return highestID;
}

void keeperOfSetsThread(
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t toElevatorChn,
	ref shared NonBlockingChannel!message_t watchdogFeedChn,
	ref shared NonBlockingChannel!PeerList peerListChn
	)
{
	debug
	{
		writelnGreen("    [x] keeperOfSetsThread");
	}

	message_t receivedFromNetwork;

	while (true)
	{
		if (toElevatorChn.extract(receivedFromNetwork))
		{
			debug writeln("keeperOfSets: from toElevChn: ");
			debug writeln(receivedFromNetwork);

			switch (receivedFromNetwork.header)
			{
			case message_header_t.delegateOrder:
			{
				if (receivedFromNetwork.targetID == getMyID())
				{
					addToList(getMyID(),
						  receivedFromNetwork.orderDirection,
						  receivedFromNetwork.orderFloor);
					// send confirm to network
					// set lights on
				}
				break;
			}

			case message_header_t.confirmOrder:
			{
				addToList(
					receivedFromNetwork.senderID,
					receivedFromNetwork.orderDirection,
					receivedFromNetwork.orderFloor);
				// set lights on
				break;
			}

			case message_header_t.expediteOrder:
			{
				removeFromList(
					receivedFromNetwork.senderID,
					receivedFromNetwork.orderDirection,
					receivedFromNetwork.orderFloor);
				// set lights off
				break;
			}

			case message_header_t.syncRequest:
			{
				if (getMyID() == highestID())
					sendSyncInfo(receivedFromNetwork.senderID);
				break;
			}

			case message_header_t.syncInfo:
			{
				if (getMyID() == receivedFromNetwork.targetID)
					//TODO: Skulle ikke mottagning av syncinfo være i init i main før threads blir startet?
					syncMySet(receivedFromNetwork.syncInternalList);
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

		PeerList extractedPeerList = PeerList();
		if (peerListChn.extract(extractedPeerList))
		{
            foreach(id; extractedPeerList)
            {
                if (id in inactiveElevators)
                {
                    reviveElevator(id);
                }
                else if (id !in aliveElevators)
                {
                    createElevator(id);
                }
            }
            foreach(id; aliveElevators.byKey)
            {
                if (!canFind(extractedPeerList.peers, id))
                {
                    retireElevator(id);
                }
            }
            debug writeln("keeper: alive ", aliveElevators.keys);
            debug writeln("keeper: inactive ", inactiveElevators.keys);
        }

	}
}
