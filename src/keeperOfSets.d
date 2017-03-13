import std.stdio,
       std.datetime,
       std.conv,
       std.algorithm.searching,
       std.random,
       std.math,
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
	state_t prevState;
	int currentFloor;
	long lastTimestamp;
	ubyte ID;
}

struct orderList_t
{
	immutable(int)[] upQueue;
	immutable(int)[] downQueue;
	immutable(int)[] internalQueue;
}

shared elevator_t[ubyte] aliveElevators;
shared elevator_t[ubyte] deadElevators;

void reviveElevator(ubyte id)
{
	aliveElevators[id] = deadElevators[id];
	deadElevators.remove(id);
	debug writeln("keeper: elevator [", id, "] REVIVED");
}

void createElevator(ubyte id)
{
	aliveElevators[id] = elevator_t();
	debug writeln("keeper: new elevator [", id, "] ALLOCATED");
}

void retireElevator(ubyte id)
{
	deadElevators[id] = aliveElevators[id];
	aliveElevators.remove(id);
	debug writeln("keeper: elevator [", id, "] RETIRED");
}

//findMatch finner best egna elevator for en ordre ved å se på tilstand + floor,
//i tilfellet det e flere mulige for oppdraget velge den den nærmeste.

ubyte findMatch(int orderFloor, button_type_t orderDirection)
{
/*	if (orderDirection == button_type_t.INTERNAL)
	{
		return messenger.getMyID();
	}

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

	// check for smallest distance ??    -Nei, imo: too optimized.


	debug writelnYellow("keeper: Candidates at end of match: ");
	debug writeln(candidates.keys);

	return choice(candidates.keys); // TODO: actually return a matched id
	*/

	if (orderDirection == button_type_t.INTERNAL)
	{
		debug writeln("giving myself the internal order for floor: ", orderFloor);
		return messenger.getMyID();
	}

	elevator_t[ubyte] candidates = (cast(elevator_t[ubyte])aliveElevators).dup;
	elevator_t[ubyte] entrants;

	if(orderDirection == button_type_t.DOWN)
	{
		foreach(elevator; candidates)
		{
			if((elevator.currentFloor > orderFloor) 
				&& ((elevator.currentState == state_t.GOING_DOWN) 
					|| (elevator.prevState == state_t.GOING_DOWN)))

			{
				entrants[elevator.ID] = candidates[elevator.ID];
			}
			//only one eligabe entrant
			if(entrants.length == 1)
			{
				debug writeln("the only candidate GOING_DOWN and currently ABOVE is elev.ID: ", entrants.keys);
				return entrants.keys;
			}
			//multiple eligable entrants
			if(entrants.length > 1)
			{
				int nearestFloor;
				ubyte nearestElevator;
				foreach(elevator; entrants)
				{
					if(abs(elevator.currentFloor - orderFloor) <= nearestFloor)
					{
						nearestElevator = elevator.ID;
					}
				}
				debug writeln("the closest going-down candidate is elev.ID: ", nearestElevator);
				return nearestElevator;
			}

			if(entrants.length == 0)
			{
				debug writeln("there was no one going-down eligable, choosing an IDLE instead");
				foreach(elevator; candidates)
				{
					if(elevator.currentState == state_t.IDLE)
					{
						entrants[elevator.ID] = candidates[elevator.ID];
					}
				}
				
				if(entrants.length == 1)
				{
					return entrants.keys;
				}

				if(entrants.length > 1)
				{
				int nearestFloor;
				ubyte nearestElevator;
				foreach(elevator; entrants)
				{
					if(abs(elevator.currentFloor - orderFloor) <= nearestFloor)
					{
						nearestElevator = elevator.ID;
					}
				}
				debug writeln("the closest IDLE elevator is elev.ID: ", nearestElevator);
				return nearestElevator;
				}
			}
			if(entrants.length == 0)
			{
				debug writeln("no one IDLE available, resorting to GOING UP elevators.");
				foreach(elevator; entrants)
				{
					if(elevator.currentState == state_t.UP)
					{
						entrants[elevator.ID] = candidates[elevator.ID];
					}
				}
				
				if(entrants.length == 1)
				{
					return entrants.keys;
				}

				if(entrants.length > 1)
				{
				int nearestFloor;
				ubyte nearestElevator;
				foreach(elevator; entrants)
				{
					if(abs(elevator.currentFloor - orderFloor) <= nearestFloor)
					{
						nearestElevator = elevator.ID;
					}
				}
				debug writeln("the closest IDLE elevator is elev.ID: ", nearestElevator);
				return nearestElevator;
				}
			}
		}
    }

	if(orderDirection == button_type_t.UP)
	{
		foreach(elevator; candidates)
		{
			if((elevator.currentFloor < orderFloor) 
				&& ((elevator.currentState == state_t.GOING_UP) 
					|| (elevator.prevState == state_t.GOING_UP)))

			{
				entrants[elevator.ID] = candidates[elevator.ID];
			}
			//only one eligabe entrant
			if(entrants.length == 1)
			{
				debug writeln("the only candidate GOING_UP and currently BELOW is elev.ID: ", entrants.keys);
				return entrants.keys;
			}
			//multiple eligable entrants
			if(entrants.length > 1)
			{
				int nearestFloor;
				ubyte nearestElevator;
				foreach(elevator; entrants)
				{
					if(abs(orderFloor - elevator.currentFloor) <= nearestFloor)
					{
						nearestElevator = elevator.ID;
					}
				}
				debug writeln("the closest GOING_UP candidate is elev.ID: ", nearestElevator);
				return nearestElevator;
			}
			//no eligable entrant after primary search, finding best suited IDLE instead.
			if(entrants.length == 0)
			{
				foreach(elevator; candidates)
				{
					if(elevator.currentState == state_t.IDLE)
					{
						entrants[elevator.ID] = candidates[elevator.ID];
					}
				}
				
				if(entrants.length == 1)
				{
					return entrants.keys;
				}

				if(entrants.length > 1)
				{
				int nearestFloor;
				ubyte nearestElevator;
				foreach(elevator; entrants)
				{
					if(abs(elevator.currentFloor - orderFloor) <= nearestFloor)
					{
						nearestElevator = elevator.ID;
					}
				}
				return nearestElevator;
				}
			}
			if(entrants.length == 0)
			{
				debug writeln("no one IDLE available, resorting to GOING UP elevators.");
				foreach(elevator; entrants)
				{
					if(elevator.currentState == state_t.DOWN)
					{
						entrants[elevator.ID] = candidates[elevator.ID];
					}
				}
				
				if(entrants.length == 1)
				{
					return entrants.keys;
				}

				if(entrants.length > 1)
				{
				int nearestFloor;
				ubyte nearestElevator;
				foreach(elevator; entrants)
				{
					if(abs(elevator.currentFloor - orderFloor) <= nearestFloor)
					{
						nearestElevator = elevator.ID;
					}
				}
				debug writeln("the closest IDLE elevator is elev.ID: ", nearestElevator);
				return nearestElevator;
				}
			}
		}
	}
}

void addToList(ubyte targetID, button_type_t orderDirection, int orderFloor)
{
	// TODO: check that targetID is in aliveElevators?
	if (targetID in deadElevators)
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

orderList_t getElevatorsOrders(ubyte id)
{
	orderList_t orders;

	if (id in aliveElevators)
	{
		orders = orderList_t(
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
	if(currentState != aliveElevators[targetID].currentState)
	{
		aliveElevators[targetID].prevState = aliveElevators[targetID].currentState;
	}
	aliveElevators[targetID].currentState   = currentState;
	aliveElevators[targetID].currentFloor   = currentFloor;
	aliveElevators[targetID].lastTimestamp  = timestamp;
}

message_t createSyncInfo(ubyte targetID)
{
	message_t newSyncMessage;

	newSyncMessage.header   = message_header_t.syncInfo;
	newSyncMessage.senderID = getMyID();
	newSyncMessage.targetID = targetID;

	int[main.nrOfFloors] internalOrders;
	debug writeln("internalOrders So far: ", internalOrders);
	if (targetID in deadElevators)
    {
		debug writelnRed("syncer was in dead");
	    reviveElevator(targetID);
    }
	if (targetID !in aliveElevators)
    {
		debug writelnRed("syncer wasn't in dead");
	    createElevator(targetID);
    }
	debug writelnPurple("i don't know anymore");
	debug writeln(aliveElevators[targetID].internalQueue.keys);
	foreach (floor; aliveElevators[targetID].internalQueue.keys)
    {
		debug writeln("setting floor ", floor);
		internalOrders[floor] = 1;
    }
	newSyncMessage.syncInfo = internalOrders.dup;

	return newSyncMessage;
}

void syncMySet(shared int[main.nrOfFloors] internalOrders)
{
	debug writeln("keeper: syncing my sets with ", internalOrders);
	if (messenger.getMyID() in deadElevators)
		reviveElevator(messenger.getMyID());
	else if (messenger.getMyID() !in aliveElevators)
		createElevator(messenger.getMyID());
	foreach (int floor, order; internalOrders)
	{
		if (order)
		{
			addToList(messenger.getMyID(), button_type_t.INTERNAL, floor);
			elev_set_button_lamp(elev_button_type_t.BUTTON_COMMAND, floor, 1);
		}
	}
}

ubyte highestID()
{
	ubyte highestID = messenger.getMyID();

	foreach (elevator; aliveElevators)
	{
		if (messenger.getMyID() < elevator.ID)
			highestID = elevator.ID;

	}
	return highestID;
}

void keeperOfSetsThread(
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t watchdogFeedChn,

	ref shared NonBlockingChannel!message_t watchdogAlertChn,

	ref shared NonBlockingChannel!orderList_t operatorsOrdersChn,
	ref shared NonBlockingChannel!PeerList peerListChn
	)
{
	debug writelnGreen("    [x] keeperOfSetsThread");

	message_t receivedFromNetwork;
	message_t watchdogAlert;

	while (true)
	{
		if (ordersToThisElevatorChn.extract(receivedFromNetwork))
		{
			switch (receivedFromNetwork.header)
			{
				case message_header_t.delegateOrder:
				{
					if (receivedFromNetwork.targetID == messenger.getMyID())
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
					if (receivedFromNetwork.senderID == messenger.getMyID())
						operatorsOrdersChn.insert(getElevatorsOrders(messenger.getMyID()));

					/* Set light if order is local-internal or external */
					if (receivedFromNetwork.targetID == messenger.getMyID() || receivedFromNetwork.orderDirection != button_type_t.INTERNAL)
					{
						elev_set_button_lamp(
							cast(elev_button_type_t)receivedFromNetwork.orderDirection,
							receivedFromNetwork.orderFloor,
							1);
					}

					watchdogFeedChn.insert(receivedFromNetwork);

					break;
				}

				case message_header_t.expediteOrder:
				{
					/* Remove from elevators lists */
					removeFromList(
						receivedFromNetwork.senderID,
						receivedFromNetwork.orderFloor);

					/* Update operators orders */
					operatorsOrdersChn.insert(getElevatorsOrders(messenger.getMyID()));

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
					if (receivedFromNetwork.senderID == messenger.getMyID())
					{
						elev_set_button_lamp(
							elev_button_type_t.BUTTON_COMMAND,
							receivedFromNetwork.orderFloor,
							0);
					}

					watchdogFeedChn.insert(receivedFromNetwork);

					break;
				}

				case message_header_t.syncRequest:
				{
					debug writeln("keeper: received sync request");
					if (messenger.getMyID() == highestID())
					{
						message_t syncInfo = createSyncInfo(receivedFromNetwork.senderID);
						debug writeln("keeper: sync message crote");
						toNetworkChn.insert(syncInfo);
					}
					break;
				}

				case message_header_t.syncInfo:
				{
					if (messenger.getMyID() == receivedFromNetwork.targetID)
					{
						syncMySet(receivedFromNetwork.syncInfo);
						operatorsOrdersChn.insert(getElevatorsOrders(messenger.getMyID()));
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

		//check if the watchdog has picked up any timeouts
		if(watchdogAlertChn.extract(watchdogAlert))
		{
			message_t reDistOrder;
			if(watchdogAlert.targetID in aliveElevators)
			{
				reDistOrder.header = message_header_t.delegateOrder;
				reDistOrder.senderID = messenger.getMyID();
				reDistOrder.targetID = watchdogAlert.targetID;
				reDistOrder.orderFloor = watchdogAlert.orderFloor;
				reDistOrder.timestamp = Clock.currTime().toUnixTime();
				
				if(aliveElevators[watchdogAlert.targetID].downQueue)
				{
					reDistOrder.orderDirection = DOWN;
					toNetworkChn.insert(reDistOrder);

				}
				if(aliveElevators[watchdogAlert.targetID].upQueue)
				{
					reDistOrder.orderDirection = UP;
					toNetworkChn.insert(reDistOrder);

				}
				if(aliveElevators[watchdogAlert.targetID].internalQueue)
				{
					reDistOrder.orderDirection = INTERNAL;
					toNetworkChn.insert(reDistOrder);

				}
			}
		}


		/* Update lists of alive and inactive elevators */
		PeerList extractedPeerList = PeerList();
		if (peerListChn.extract(extractedPeerList))
		{
			foreach (id; extractedPeerList)
			{
				if (id in deadElevators)
					reviveElevator(id);
				else if (id !in aliveElevators)
					createElevator(id);
			}
			foreach (id; aliveElevators.byKey)
				if (!canFind(extractedPeerList.peers, id))
					retireElevator(id);

			debug writeln("keeper: alive ", aliveElevators.keys);
			debug writeln("keeper: inactive ", deadElevators.keys);
		}
	}
}
