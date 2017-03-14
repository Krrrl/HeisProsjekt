import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency,
       std.datetime,
       std.algorithm.searching,
       std.algorithm.sorting,
       std.algorithm.mutation;

import udp_bcast,
       peers;

import main,
       channels,
       debugUtils,
       keeperOfSets,
       messenger,
       watchdog,
       iolib;

enum state_t
{
	GOING_UP        = 0,    // casts to button_type_t UP
	GOING_DOWN      = 1,    // casts to button_type_t DOWN
	FLOORSTOP       = 2,
	INIT,
	IDLE
}

const int stopDuration                  = 3;

private int currentFloor                = 0;
private shared int previousValidFloor   = -1;
private shared state_t currentState     = state_t.INIT;
private state_t previousDirection       = state_t.INIT;
private long timeAtFloorStop            = 0;

private int[][button_type_t] ordersForThisElevator;

state_t getCurrentState()
{
	return currentState;
}

void stopAtFloor()
{
	elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
	elev_set_door_open_lamp(1);
	timeAtFloorStop = Clock.currTime.toUnixTime();
}

int getPreviousValidFloor()
{
	return previousValidFloor;
}

void updateOrdersForThisElevator(orderList_t orders)
{
	debug write("operator: my orders ...  ");
	ordersForThisElevator[button_type_t.UP]         = orders.upQueue.dup;
	ordersForThisElevator[button_type_t.DOWN]       = orders.downQueue.dup;
	ordersForThisElevator[button_type_t.INTERNAL]   = orders.internalQueue.dup;
	debug writeln(ordersForThisElevator);
}

message_t createExpediteOrder(int floor)
{
	message_t newExpediteOrder;

	newExpediteOrder.header         = message_header_t.expediteOrder;
	newExpediteOrder.senderID       = getMyID();
	newExpediteOrder.orderFloor     = floor;
	newExpediteOrder.currentState   = currentState;
	newExpediteOrder.currentFloor   = previousValidFloor;
	newExpediteOrder.timestamp      = Clock.currTime().toUnixTime();

	return newExpediteOrder;
}

ulong findElementPosition(ref int[] arr, int value)
{
    foreach(i; 0..arr.length)
    {
        if (arr[i] == value)
        {
            return i;
        }
    }
    return 0;
}

void removeFromThisElevatorsOrders(int floor)
{
    debug writeln("operator: removing from own lists");
    foreach(button; button_types_t())
    {
        if (canFind(ordersForThisElevator[button].dup, floor))
        {
            debug writeln("here be removing");
            debug writeln(ordersForThisElevator[button]);
            debug writeln(findElementPosition(ordersForThisElevator[button], floor));
            ordersForThisElevator[button] = remove(ordersForThisElevator[button],
                    findElementPosition(ordersForThisElevator[button], floor));
            debug writeln(ordersForThisElevator[button]);
            debug writeln("here be removed");
        }
    }
}

bool shouldStopToExpediteOnFloor(int floor)
{
	int[] allOrders = ordersForThisElevator[button_type_t.UP] ~
			  ordersForThisElevator[button_type_t.DOWN] ~
			  ordersForThisElevator[button_type_t.INTERNAL];

	/* Don't tell to expedite if there are no orders */
	if (!cast(bool)allOrders.length)
    {
		return false;
    }

	if (ordersForThisElevator[button_type_t.INTERNAL].length)
    {
		if (canFind(ordersForThisElevator[button_type_t.INTERNAL], floor))
        {
            removeFromThisElevatorsOrders(floor);
			return true;
        }
    }

	switch (currentState)
	{
		case (state_t.GOING_UP):
		{
	        /* Check if */
			if (ordersForThisElevator[button_type_t.UP].length)
            {
				if (canFind(ordersForThisElevator[button_type_t.UP], floor))
                {
                    removeFromThisElevatorsOrders(floor);
					return true;
                }
            }
			if (ordersForThisElevator[button_type_t.DOWN].length)
			{
				int highestDownOrder    = sort(ordersForThisElevator[button_type_t.DOWN].dup)[$ - 1];
				int[] nonDownOrders     = ordersForThisElevator[button_type_t.UP].dup ~ ordersForThisElevator[button_type_t.INTERNAL].dup;

				int highestNonDownOrder;
				if (nonDownOrders.length)
				{
					sort(nonDownOrders);
					highestNonDownOrder = nonDownOrders[$ - 1];
				}
				else
                {
					highestNonDownOrder = 0;
                }
				if (highestDownOrder == floor && highestDownOrder > highestNonDownOrder)
                {
                    removeFromThisElevatorsOrders(floor);
					return true;
                }
			}
			return false;
		}
		case (state_t.GOING_DOWN):
		{
			if (ordersForThisElevator[button_type_t.DOWN].length)
            {
				if (canFind(ordersForThisElevator[button_type_t.DOWN], floor))
                {
                    removeFromThisElevatorsOrders(floor);
					return true;
                }
            }
			if (ordersForThisElevator[button_type_t.UP].length)
			{
				int lowestUpOrder       = sort(ordersForThisElevator[button_type_t.UP].dup)[0];
				int[] nonUpOrders       = ordersForThisElevator[button_type_t.DOWN].dup ~ ordersForThisElevator[button_type_t.INTERNAL].dup;

				int lowestNonUpOrder;
				if (nonUpOrders.length)
				{
					sort(nonUpOrders);
					lowestNonUpOrder = nonUpOrders[0];
				}
				else
                {
					lowestNonUpOrder = main.nrOfFloors;
                }
				if (lowestUpOrder == floor && lowestUpOrder <= lowestNonUpOrder)
                {
                    removeFromThisElevatorsOrders(floor);
					return true;
                }
			}
			return false;
		}
		case (state_t.FLOORSTOP):
		{
			//TODO:
			return false;
		}
		default:
		{
			return false;
		}
	}
}

elev_motor_direction_t getDirectionToNextOrder(int floor)
{
	int[] allOrders = ordersForThisElevator[button_type_t.UP] ~ordersForThisElevator[button_type_t.DOWN] ~ordersForThisElevator[button_type_t.INTERNAL];

	if (allOrders.length)
	{
		/* Sort all orders in ascending order */
		sort(allOrders);
		switch (previousDirection)
		{
		default:
		case (state_t.GOING_UP):
		{
			if (allOrders.dup[$ - 1] > floor)
            {
				return elev_motor_direction_t.DIRN_UP;
            }
			if (allOrders.dup[0] < floor)
            {
				return elev_motor_direction_t.DIRN_DOWN;
            }
			break;
		}
		case (state_t.GOING_DOWN):
		{
			if (allOrders[0] < floor)
            {
				return elev_motor_direction_t.DIRN_DOWN;
            }
			if (allOrders[$ - 1] > floor)
            {
				return elev_motor_direction_t.DIRN_UP;
            }
			break;
		}
		}
	}
	return elev_motor_direction_t.DIRN_STOP;
}

/*
 * @brief   Thread responsible for operating the lift and carrying out orders delegated to this elevator
 * @details Implemented with a state machine
 *
 * param toElevatorChn: channel directed to this elevator
 * param toNetworkChn: channel directed to external network
 */
void operatorThread(
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!orderList_t operatorsOrdersChn
	)
{
	debug writelnGreen("    [x] operatorThread");

	orderList_t ordersUpdate;
	updateOrdersForThisElevator(ordersUpdate);

	while (true)
	{
		/* Check for update in orders for this elevator */
		if (operatorsOrdersChn.extract(ordersUpdate))
        {
			updateOrdersForThisElevator(ordersUpdate);
        }

		/* Read floor sensors */
		currentFloor = elev_get_floor_sensor_signal();
		if (currentFloor != -1)
        {
			previousValidFloor = currentFloor;
        }

		/* Do state dependent actions */
		switch (currentState)
		{
			case (state_t.INIT):
			{
				debug writelnYellow("Operator: now INIT");
				// wait for sync info?

				elev_set_motor_direction(elev_motor_direction_t.DIRN_DOWN);
				
		
				if(currentFloor == 0)
				{
					elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
					currentState = state_t.IDLE;
					debug writelnYellow("Operator: now IDLE");
					break;
				}
				break;
			}
			case (state_t.GOING_UP):
			{
				if (shouldStopToExpediteOnFloor(currentFloor))
				{
					stopAtFloor();
					toNetworkChn.insert(createExpediteOrder(previousValidFloor));
					previousDirection = state_t.GOING_UP;
					currentState = state_t.FLOORSTOP;
					debug writelnYellow("Operator: now FLOORSTOP");
				}
				break;
			}
			case (state_t.GOING_DOWN):
			{
				if (shouldStopToExpediteOnFloor(currentFloor))
				{
					stopAtFloor();
					toNetworkChn.insert(createExpediteOrder(previousValidFloor));
					previousDirection = state_t.GOING_DOWN;
					currentState = state_t.FLOORSTOP;
					debug writelnYellow("Operator: now FLOORSTOP");
				}
				break;
			}
			case (state_t.FLOORSTOP):
			{
				stopAtFloor();
				toNetworkChn.insert(createExpediteOrder(previousValidFloor));

				/* Check for new orders, restarts door timer */
				if (shouldStopToExpediteOnFloor(previousValidFloor))
				{
					toNetworkChn.insert(createExpediteOrder(previousValidFloor));
					timeAtFloorStop = Clock.currTime.toUnixTime();
				}
				/* Check where to go next */
				if (Clock.currTime.toUnixTime() > (timeAtFloorStop + stopDuration))
				{
					elev_set_door_open_lamp(0);
					if(getDirectionToNextOrder(previousValidFloor) == elev_motor_direction_t.DIRN_STOP)
					{
						currentState = state_t.IDLE;
						debug writelnYellow("Operator: now IDLE");
					}
					if(getDirectionToNextOrder(previousValidFloor) == elev_motor_direction_t.DIRN_DOWN)
					{
						currentState = state_t.GOING_DOWN;
						debug writelnYellow("Operator: now GOING_DOWN");
					}
					if(getDirectionToNextOrder(previousValidFloor) == elev_motor_direction_t.DIRN_UP)
					{
						currentState = state_t.GOING_UP;
						debug writelnYellow("Operator: now GOING_UP");
					}
				}
				break;
			}
			case (state_t.IDLE):
			{
                /* Check for new orders on the same floor */
				if (shouldStopToExpediteOnFloor(currentFloor))
				{
					currentState = state_t.FLOORSTOP;
					debug writelnYellow("Operator: now FLOORSTOP");
					break;
				}

				/* Check for new orders elsewhere */
				elev_motor_direction_t directionToNextOrder = getDirectionToNextOrder(previousValidFloor);
				if (directionToNextOrder == elev_motor_direction_t.DIRN_UP)
				{
					elev_set_motor_direction(directionToNextOrder);
					currentState = state_t.GOING_UP;
					debug writelnYellow("Operator: now GOING_UP");
				}
				if (directionToNextOrder == elev_motor_direction_t.DIRN_DOWN)
				{
					elev_set_motor_direction(directionToNextOrder);
					currentState = state_t.GOING_DOWN;
					debug writelnYellow("Operator: now GOING_DOWN");
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
