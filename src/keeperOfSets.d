import std.stdio,
       std.datetime,
       std.conv,
       std.algorithm.searching,
       std.random,
       std.datetime;

import main,
       debugUtils,
       messenger,
       operator,
       channels,
       peers,
       iolib;

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

struct OrderList
{
	immutable(int)[] upQueue;
	immutable(int)[] downQueue;
	immutable(int)[] internalQueue;
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
		return getMyID();

	elevator_t[ubyte] candidates    = (cast(elevator_t[ubyte])aliveElevators).dup;
	elevator_t[ubyte] entrants      = candidates.dup;

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
		entrants = candidates.dup;
	// Else, update the current candidates
	else
		candidates = entrants.dup;

	// check for being below/above?
	// TODO: More filters?

	// check for smallest distance ??


	debug writelnYellow("keeper: Candidates at end of match: ");
	debug writeln(candidates.keys);

	return choice(candidates.keys); // TODO: actually return a matched id
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
		if (orderFloor !in aliveElevators[targetID].downQueue)
			aliveElevators[targetID].downQueue[orderFloor] = true;
		break;
	}

	case button_type_t.UP:
	{
		if (orderFloor !in aliveElevators[targetID].upQueue)
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

void removeFromList(ubyte targetID, int orderFloor)
{
	/* Remove up and down orders at orderFloor for all elevators */
	foreach (elevator; aliveElevators)
	{
		if (orderFloor in elevator.downQueue)
			elevator.downQueue.remove(orderFloor);
		if (orderFloor in elevator.upQueue)
			elevator.upQueue.remove(orderFloor);
	}
	/* Remove internal order only from the specific elevator */
	if (targetID in aliveElevators)
		if (orderFloor in aliveElevators[targetID].internalQueue)
			aliveElevators[targetID].internalQueue.remove(orderFloor);

}

OrderList getElevatorsOrders(ubyte id)
{
	OrderList orders;

	if (id in aliveElevators)
	{
		orders = OrderList(
			aliveElevators[id].upQueue.keys,
			aliveElevators[id].downQueue.keys,
			aliveElevators[id].internalQueue.keys);
	}
	else
	{
		debug writelnYellow("keeper: attempt to get nonalive elevators orders");
	}
	return orders;
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
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t watchdogFeedChn,
	ref shared NonBlockingChannel!OrderList operatorsOrdersChn,
	ref shared NonBlockingChannel!PeerList peerListChn
	)
{
	debug writelnGreen("    [x] keeperOfSetsThread");

	message_t receivedFromNetwork;

	while (true)
	{
		if (ordersToThisElevatorChn.extract(receivedFromNetwork))
		{
			switch (receivedFromNetwork.header)
			{
			case message_header_t.delegateOrder:
			{
				if (receivedFromNetwork.targetID == getMyID())
				{
					/* Confirm order */
					message_t confirmingOrder;
					confirmingOrder.header          = message_header_t.confirmOrder;
					confirmingOrder.senderID        = messenger.getMyID();
					// TODO: [REMOVE THIS COMMENT ?] Setting targetID to the delegators sender ID, so that the delegator knows that it was its order we now confirm
					confirmingOrder.targetID        = receivedFromNetwork.senderID;
					confirmingOrder.orderFloor      = receivedFromNetwork.orderFloor;
					confirmingOrder.orderDirection  = receivedFromNetwork.orderDirection;
					confirmingOrder.currentState    = getCurrentState();
					confirmingOrder.currentFloor    = getPreviousValidFloor();
					confirmingOrder.timestamp       = Clock.currTime().toUnixTime();
					toNetworkChn.insert(confirmingOrder);
				}
				break;
			}

			case message_header_t.confirmOrder:
			{
				/* Add to senders lists */
				addToList(
					receivedFromNetwork.senderID,
					receivedFromNetwork.orderDirection,
					receivedFromNetwork.orderFloor);

				/* Update operators orders if the new order is ours */
				if (receivedFromNetwork.senderID == getMyID())
					operatorsOrdersChn.insert(getElevatorsOrders(getMyID()));

				/* Set light if order is local-internal or external */
				if (receivedFromNetwork.targetID == getMyID() || receivedFromNetwork.orderDirection != button_type_t.INTERNAL)
				{
					elev_set_button_lamp(
						cast(elev_button_type_t)receivedFromNetwork.orderDirection,
						receivedFromNetwork.orderFloor,
						1);
				}
				break;
			}

			case message_header_t.expediteOrder:
			{
				/* Remove from elevators lists */
				removeFromList(
					receivedFromNetwork.senderID,
					receivedFromNetwork.orderFloor);

				/* Update operators orders */
				operatorsOrdersChn.insert(getElevatorsOrders(getMyID()));

				/* Clear external lights */
				elev_set_button_lamp(
					elev_button_type_t.BUTTON_CALL_UP,
					receivedFromNetwork.orderFloor,
					0);
				elev_set_button_lamp(
					elev_button_type_t.BUTTON_CALL_DOWN,
					receivedFromNetwork.orderFloor,
					0);

				/* Clear internal light if we are the expeditor */
				if (receivedFromNetwork.senderID == getMyID())
				{
					elev_set_button_lamp(
						elev_button_type_t.BUTTON_COMMAND,
						receivedFromNetwork.orderFloor,
						0);
				}
				break;
			}

			case message_header_t.syncRequest:
			{
				if (getMyID() == highestID())
					// TODO: Can't we just have all of the elevators send it?
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

		/* Update lists of alive and inactive elevators */
		PeerList extractedPeerList = PeerList();
		if (peerListChn.extract(extractedPeerList))
		{
			foreach (id; extractedPeerList)
			{
				if (id in inactiveElevators)
					reviveElevator(id);
				else if (id !in aliveElevators)
					createElevator(id);
			}
			foreach (id; aliveElevators.byKey)
				if (!canFind(extractedPeerList.peers, id))
					retireElevator(id);

			debug writeln("keeper: alive ", aliveElevators.keys);
			debug writeln("keeper: inactive ", inactiveElevators.keys);
		}

	}
}
