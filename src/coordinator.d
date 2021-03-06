import std.stdio,
       std.datetime,
       std.conv,
       std.algorithm.searching,
       std.random,
       std.math,
       std.datetime;

import main,
       debugUtils,
       routor,
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
	debug writeln("coordinator: elevator [", id, "] REVIVED");
}

void createElevator(ubyte id)
{
	aliveElevators[id] = elevator_t();
	debug writeln("coordinator: new elevator [", id, "] ALLOCATED");
}

void retireElevator(ubyte id, ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn)
{
	deadElevators[id] = aliveElevators[id];
	aliveElevators.remove(id);
	debug writeln("coordinator: elevator [", id, "] RETIRED");


	message_t reDelegationOrder;
	foreach(int floor; deadElevators[id].upQueue)
	{
		reDelegationOrder.orderFloor = floor;
		reDelegationOrder.orderDirection = button_type_t.UP;
		ordersToBeDelegatedChn.insert(reDelegationOrder);
		removeFromList(id, floor);
	}
	foreach(int floor; deadElevators[id].downQueue)
	{
		reDelegationOrder.orderFloor = floor;
		reDelegationOrder.orderDirection = button_type_t.DOWN;
		ordersToBeDelegatedChn.insert(reDelegationOrder);
		removeFromList(id, floor);
	}
}

void addBestElevatorWithState(state_t wantedState, int wantedFloor, ref elevator_t[ubyte] candidates, ref elevator_t[ubyte] entrants)
{
	foreach(ubyte id, elevator; candidates)
	{
		if(elevator.currentState == wantedState)
		{
			entrants[id] = candidates[id];
		}
	}

	if(entrants.length > 1)
	{
		keepNearestElevator(entrants, wantedFloor);
	}
}

void keepNearestElevator(elevator_t[ubyte] entrants, int floor)
{
	int smallestDistance = main.nrOfFloors;
	ubyte nearestElevatorId = entrants.keys[0]; 
	foreach(ubyte id, elevator; entrants) 
	{ 
		int distance = abs(elevator.currentFloor - floor); 
		if(distance <= smallestDistance) 
		{ 
			smallestDistance = distance; 
			nearestElevatorId = id; 
		} 
	} 
	foreach(ubyte id, elevator; entrants) 
	{ 
		if(id != nearestElevatorId) 
		{ 
			entrants.remove(id); 
		} 
	} 
}

void keepFurtherestElevator(elevator_t[ubyte] entrants, int floor)
{
	int longestDistance = 0;
	ubyte furtherestElevatorId = entrants.keys[0];
	foreach(ubyte id, elevator; entrants) 
	{ 
		int distance = abs(elevator.currentFloor - floor); 
		if(distance >= longestDistance) 
		{ 
			longestDistance = distance; 
			furtherestElevatorId = id; 
		} 
	} 
	foreach(ubyte id, elevator; entrants) 
	{ 
		if(id != furtherestElevatorId) 
		{ 
			entrants.remove(id); 
		} 
	} 
}

/* returns most suitable elevator for an order */
ubyte findMatch(int orderFloor, button_type_t orderDirection)
{
	if (orderDirection == button_type_t.INTERNAL)
	{
		return routor.getMyID();
	}

	elevator_t[ubyte] candidates = (cast(elevator_t[ubyte])aliveElevators).dup;
	elevator_t[ubyte] entrants;

	if(orderDirection == button_type_t.DOWN)
	{
		foreach(int priority; 0 .. 5)
		{
			if(entrants.length == 1)
			{
                debug writeln(priority - 1);
				return entrants.keys[0];
			}

			switch(priority)
			{
				case 0:
				{
					foreach(ubyte id, elevator; candidates)
					{
						if(((elevator.currentFloor > orderFloor) && (elevator.currentState == state_t.GOING_DOWN)) 
							|| ((elevator.currentFloor == orderFloor) && (elevator.prevState ==
                                    state_t.GOING_DOWN)))
						{
							entrants[id] = candidates[id];
						}
					}

					if(entrants.length > 1)
					{
						keepNearestElevator(entrants, orderFloor);
					}
					break;					
				}
				case 1:
				{
					addBestElevatorWithState(state_t.IDLE, orderFloor, candidates, entrants);
					break;
				}
				case 2:
				{
					addBestElevatorWithState(state_t.GOING_UP, orderFloor, candidates, entrants);
					break;
				}
				case 3:
				{
					foreach(ubyte id, elevator; candidates)
					{
						if(((elevator.currentFloor <= orderFloor) && (elevator.currentState == state_t.GOING_DOWN)))
						{
							entrants[id] = candidates[id];
						}
					}
					if(entrants.length > 1)
					{
						keepFurtherestElevator(entrants, orderFloor);
					}
					break;
				}
				default:
				{
					break;
				}
			}
		}
	}	

	if(orderDirection == button_type_t.UP)
	{
		foreach(int priority; 0 .. 5)
		{
			if(entrants.length == 1)
			{
                debug writeln(priority - 1);
				return entrants.keys[0];
			}

			switch(priority)
			{
				case 0:
				{
					foreach(ubyte id, elevator; candidates)
					{
						if(((elevator.currentFloor < orderFloor) && (elevator.currentState == state_t.GOING_UP)) 
							|| ((elevator.currentFloor == orderFloor) && (elevator.prevState ==
                                    state_t.GOING_UP)))
						{
							entrants[id] = candidates[id];
						}
					}

					if(entrants.length > 1)
					{
						keepNearestElevator(entrants, orderFloor);
					}
					break;					
				}
				case 1:
				{
					addBestElevatorWithState(state_t.IDLE, orderFloor, candidates, entrants);
					break;
				}
				case 2:
				{
					addBestElevatorWithState(state_t.GOING_DOWN, orderFloor, candidates, entrants);
					break;
				}
				case 3:
				{
					foreach(ubyte id, elevator; candidates)
					{
						if(((elevator.currentFloor >= orderFloor) && (elevator.currentState == state_t.GOING_UP)))
						{
							entrants[id] = candidates[id];
						}
					}
					if(entrants.length > 1)
					{
						keepFurtherestElevator(entrants, orderFloor);
					}
					break;
				}
				default:
				{
					break;
				}
			}
		}
	}
    debug writelnRed("Found NO suitable elevator for order-> choosing myself");
	return routor.getMyID();
}

void addToList(ubyte targetID, button_type_t orderDirection, int orderFloor)
{
	if (targetID in deadElevators)
	{
		return;
	}
	if (targetID !in aliveElevators)
		aliveElevators[targetID] = elevator_t();
	switch (orderDirection)
	{
		case button_type_t.DOWN:
		{
			if (orderFloor !in aliveElevators[targetID].downQueue)
			{
				aliveElevators[targetID].downQueue[orderFloor] = true;
			}
			break;
		}
		case button_type_t.UP:
		{
			if (orderFloor !in aliveElevators[targetID].upQueue)
			{
				aliveElevators[targetID].upQueue[orderFloor] = true;
			}
			break;
		}
		case button_type_t.INTERNAL:
		{
			if (orderFloor !in aliveElevators[targetID].internalQueue)
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
		debug writelnYellow("coordinator: attempted to get dead-elevators orders");
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

	if (targetID in deadElevators)
    {
	    reviveElevator(targetID);
    }
	if (targetID !in aliveElevators)
    {
	    createElevator(targetID);
    }

	debug writeln(aliveElevators[targetID].internalQueue.keys);
	foreach (floor; aliveElevators[targetID].internalQueue.keys)
    {
		internalOrders[floor] = 1;
    }
	newSyncMessage.syncInfo = internalOrders.dup;

	return newSyncMessage;
}

void syncMySet(shared int[main.nrOfFloors] internalOrders)
{
	debug writelnRed("coordinator: syncing my sets with ");
    debug writeln(internalOrders);
	if (routor.getMyID() in deadElevators)
		reviveElevator(routor.getMyID());
	else if (routor.getMyID() !in aliveElevators)
		createElevator(routor.getMyID());
	foreach (int floor, order; internalOrders)
	{
		if (order)
		{
			addToList(routor.getMyID(), button_type_t.INTERNAL, floor);
			elev_set_button_lamp(elev_button_type_t.BUTTON_COMMAND, floor, 1);
		}
	}
}

ubyte highestEligableID(ubyte senderID)
{
	ubyte tempID = 0;
	elevator_t[ubyte] eligableElevators = (cast(elevator_t[ubyte])aliveElevators).dup;

	/* Remove senderID from eligable elevators */
	eligableElevators.remove(senderID);

	foreach (id; eligableElevators.keys)
	{
        debug writeln(id);
		if (id > tempID)
		{
			tempID = id;
		}
	}
	return tempID;
}


/* Thread responsible for coordinating the elevators modules and behaviour */
void coordinatorThread(
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn,
	ref shared NonBlockingChannel!message_t watchdogFeedChn,
	ref shared NonBlockingChannel!message_t watchdogAlertChn,
	ref shared NonBlockingChannel!orderList_t operatorsOrdersChn,
	ref shared NonBlockingChannel!PeerList peerListChn
	)
{
	debug writelnGreen("    [x] coordinatorThread");

	message_t receivedFromNetwork;
	message_t watchdogAlert;

	while (true)
	{
        /* Check for incoming orders */
		if (ordersToThisElevatorChn.extract(receivedFromNetwork))
		{
			switch (receivedFromNetwork.header)
			{
                /* Confirm any delegations */
				case message_header_t.delegateOrder:
				{
					if (receivedFromNetwork.targetID == routor.getMyID())
					{
						message_t confirmingOrder;
						confirmingOrder.header          = message_header_t.confirmOrder;
						confirmingOrder.senderID        = routor.getMyID();
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

                /* Triggers for confirmations */
				case message_header_t.confirmOrder:
				{
					/* Add to sender's lists */
					addToList(
						receivedFromNetwork.senderID,
						receivedFromNetwork.orderDirection,
						receivedFromNetwork.orderFloor);

					/* Update operators orders */
                    if (receivedFromNetwork.senderID == routor.getMyID())
                    {
                        operatorsOrdersChn.insert(getElevatorsOrders(routor.getMyID()));
                    }

					/* Set light if order is local-internal or external */
					if (receivedFromNetwork.targetID == routor.getMyID() || receivedFromNetwork.orderDirection != button_type_t.INTERNAL)
					{
						elev_set_button_lamp(
							cast(elev_button_type_t)receivedFromNetwork.orderDirection,
							receivedFromNetwork.orderFloor,
							1);
					}

                    /* Notify watchdog */
					watchdogFeedChn.insert(receivedFromNetwork);

					break;
				}

                /* Triggers for expeditions */
				case message_header_t.expediteOrder:
				{
					/* Remove from elevators lists */
					removeFromList(
						receivedFromNetwork.senderID,
						receivedFromNetwork.orderFloor);

					/* Update operators orders */
					operatorsOrdersChn.insert(getElevatorsOrders(routor.getMyID()));

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
					if (receivedFromNetwork.senderID == routor.getMyID())
					{
						elev_set_button_lamp(
							elev_button_type_t.BUTTON_COMMAND,
							receivedFromNetwork.orderFloor,
							0);
					}

                    /* Notify watchdog*/
					watchdogFeedChn.insert(receivedFromNetwork);

					break;
				}

                /* Give revived elevators their old internal orders */
				case message_header_t.syncRequest:
				{
					debug writeln("coordinator: received sync request");
                    debug writeln(highestEligableID(receivedFromNetwork.senderID));
					if ((routor.getMyID() == highestEligableID(receivedFromNetwork.senderID)))
					{
						message_t syncInfo = createSyncInfo(receivedFromNetwork.senderID);
						toNetworkChn.insert(syncInfo);
					}
					break;
				}

                /* Add any old internal orders */
				case message_header_t.syncInfo:
				{
					if (routor.getMyID() == receivedFromNetwork.targetID)
					{
						syncMySet(receivedFromNetwork.syncInfo);
						operatorsOrdersChn.insert(getElevatorsOrders(routor.getMyID()));
					}
					break;
				}

                /* Refresh states of elevators */
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

		/* Check if the watchdog has picked up any timeouts */
		if(watchdogAlertChn.extract(watchdogAlert))
		{
			message_t reDistOrder;
			if(watchdogAlert.targetID in aliveElevators)
			{
                int alertedFloor = watchdogAlert.orderFloor;

				reDistOrder.header = message_header_t.delegateOrder;
				reDistOrder.senderID = routor.getMyID();
				reDistOrder.targetID = watchdogAlert.targetID;
				reDistOrder.orderFloor = alertedFloor;
				reDistOrder.timestamp = Clock.currTime().toUnixTime();
				
                if (alertedFloor in aliveElevators[watchdogAlert.targetID].downQueue)
                {
                    if(aliveElevators[watchdogAlert.targetID].downQueue[alertedFloor])
                    {
                        reDistOrder.orderDirection = button_type_t.DOWN;
                        ordersToBeDelegatedChn.insert(reDistOrder);
                    }
                }
                if (alertedFloor in aliveElevators[watchdogAlert.targetID].upQueue)
                {
                    if(aliveElevators[watchdogAlert.targetID].upQueue[alertedFloor])
                    {
                        reDistOrder.orderDirection = button_type_t.UP;
                        ordersToBeDelegatedChn.insert(reDistOrder);
                    }
                }
                if (alertedFloor in aliveElevators[watchdogAlert.targetID].internalQueue)
                {
                    if(aliveElevators[watchdogAlert.targetID].internalQueue[alertedFloor])
                    {
                        reDistOrder.orderDirection = button_type_t.INTERNAL;
                        toNetworkChn.insert(reDistOrder);
                    }
                }
			}
		}

		/* Update lists of alive and dead elevators */
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
            {
				if (!canFind(extractedPeerList.peers, id))
                {
					retireElevator(id, ordersToBeDelegatedChn);
                }
            }
			debug writeln("coordinator: alive ", aliveElevators.keys);
			debug writeln("coordinator: inactive ", deadElevators.keys);
		}
	}
}
