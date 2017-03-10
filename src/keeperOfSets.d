import std.stdio,
       std.datetime,
       std.conv,
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

shared elevator_t[ubyte] aliveElevators;
shared elevator_t[ubyte] inactiveElevators;

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

	elevator_t[ubyte] candidates = (cast(elevator_t[ubyte])aliveElevators).dup;
    elevator_t[ubyte] entrants = candidates.dup;

	debug writelnYellow("keeper: Candidates at start of matching: ");
    debug writeln(candidates.keys);

    // TODO: What do we want to prioritise? What to filter on?

	// check for going in same direction?
	foreach (entrant; entrants)
	{
        // TODO: I feel like this logic doesn't make sense. If there is only one elevator going up and we have an up order - but it is above the order, then it might not be the best match; a elevator going down but soon turning around could be faster.
		if (cast(button_type_t)entrant.currentState != orderDirection)
		{
			entrants.remove(entrant.ID);
			debug writeln("removing candidate: ", id);
		}
	}

    // If no entrant elevators survived, replenish them all
    if (entrants.length == 0)
    {
        entrants = candidates.dup;
    }
    // Else, update the current candidates
    else
    {
        candidates = entrants.dup;
    }

	// check for being below/above?
        // TODO: More filters?

	// check for smallest distance ?? 


	debug writelnYellow("keeper: Candidates at end of match: ");
    debug writeln(candidates.keys);
	//return aliveElevators[candidates.keys[0]].ID;
    return getMyID(); // TODO: actually return a matched id
}

void addToList(ubyte targetID, button_type_t orderDirection, int orderFloor)
{
	// TODO: check that targetID is in aliveElevators?
	if (targetID in inactiveElevators)
	{
		// Do what? Error handling?
        debug writelnYellow("keeper: tried to add to inactive's list");
        return;
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

        
        // Update lists of elevators
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
            debug writeln("keeper: inactive ", inactiveElevators.keys);
        }

	}
}
