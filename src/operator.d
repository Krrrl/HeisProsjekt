import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency,
       std.datetime,
       std.algorithm.searching,
       std.algorithm.sorting;

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
	GOING_UP = 0,       // casts to button_type_t UP
	GOING_DOWN = 1,     // casts to button_type_t DOWN
	FLOORSTOP = 2,
	INIT,
	IDLE
}
private shared int currentFloor = 0;
private int previousValidFloor = 0;
private shared state_t currentState = state_t.INIT;
private state_t previousDirection = state_t.INIT;

private int[][button_type_t] ordersForThisElevator;

state_t getCurrentState()
{
	return currentState;
}

int getCurrentFloor()
{
	return currentFloor;
}

void updateOrdersForThisElevator(OrderList orders)
{
	debug writelnOrange("operator: updating my orders");
	ordersForThisElevator[button_type_t.UP] = orders.upQueue.dup;
	ordersForThisElevator[button_type_t.DOWN] = orders.downQueue.dup;
	ordersForThisElevator[button_type_t.INTERNAL] = orders.internalQueue.dup;
	debug writeln(ordersForThisElevator);
}

message_t createExpediteOrder(int floor)
{
	message_t newExpediteOrder;
	newExpediteOrder.header = message_header_t.expediteOrder;
	newExpediteOrder.senderID = getMyID();
	newExpediteOrder.orderFloor = floor;
	newExpediteOrder.currentState = currentState;
	newExpediteOrder.currentFloor = currentFloor;
	newExpediteOrder.timestamp = Clock.currTime().stdTime;

	return newExpediteOrder;
}

bool shouldStopAtFloor(int floor)
{
	switch(currentState)
	{
		case(state_t.GOING_UP):
		{
			if (ordersForThisElevator[button_type_t.INTERNAL].length)
			{
				if (canFind(ordersForThisElevator[button_type_t.INTERNAL], floor))
					return true;
			}
			
			if (ordersForThisElevator[button_type_t.UP].length)
			{
				if (canFind(ordersForThisElevator[button_type_t.UP], floor))
					return true;
			}
			if (ordersForThisElevator[button_type_t.DOWN].length)
			{
				if (sort(ordersForThisElevator[button_type_t.DOWN].dup)[$ - 1] == floor)
					return true;
			}
			return false;
		}
		case(state_t.GOING_DOWN):
		{
			if (ordersForThisElevator[button_type_t.INTERNAL].length)
			{
				if (canFind(ordersForThisElevator[button_type_t.INTERNAL], floor))
					return true;
			}
			
			if (ordersForThisElevator[button_type_t.DOWN].length)
			{
				if (canFind(ordersForThisElevator[button_type_t.DOWN], floor))
					return true;
			}
			if (ordersForThisElevator[button_type_t.UP].length)
			{
				if (sort(ordersForThisElevator[button_type_t.UP].dup)[0] == floor)
					return true;
			}
			return false;
		}
		case(state_t.FLOORSTOP):
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
	int[] allOrders = ordersForThisElevator[button_type_t.UP] ~ ordersForThisElevator[button_type_t.DOWN] ~ ordersForThisElevator[button_type_t.INTERNAL];

	if (allOrders.length)
	{
		/* Sort all orders in ascending order */
		sort(allOrders);
		switch(previousDirection)
		{
			default:
			case(state_t.GOING_UP):
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
			case(state_t.GOING_DOWN):
			{
				 if (allOrders[0] < floor)
				 {
				 	return elev_motor_direction_t.DIRN_UP;
				 }
				 if (allOrders[$ - 1] > floor)
				 {
				 	return elev_motor_direction_t.DIRN_DOWN;
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
	ref shared NonBlockingChannel!OrderList operatorsOrdersChn
	)
{
	debug writelnGreen("    [x] operatorThread");

	OrderList ordersUpdate;
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
		switch(currentState)
		{
			case (state_t.INIT):
			{
				// Find a floor, go up/down?
				// Wait for syncInfo?
				elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
				/* Go to idle */
				debug writelnOrange("operator: IDLE");
				currentState = state_t.IDLE;

				break;
			}
			case (state_t.GOING_UP):
			{
				if (shouldStopAtFloor(currentFloor))
				{
					debug writelnOrange("operator: FLOORSTOP");
					elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
					toNetworkChn.insert(createExpediteOrder(previousValidFloor));
					
					previousDirection = state_t.GOING_UP;
					currentState = state_t.FLOORSTOP;
				}
				break;
			}
			case (state_t.GOING_DOWN):
			{
				if (shouldStopAtFloor(currentFloor))
				{
					debug writelnOrange("operator: FLOORSTOP");
					elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
					toNetworkChn.insert(createExpediteOrder(previousValidFloor));
					previousDirection = state_t.GOING_DOWN;
					currentState = state_t.FLOORSTOP;
				}
				break;
			}
			case (state_t.FLOORSTOP):
			{
				
				// Open door & Set doorlight
				// Start timer

				// Timeout
				debug writelnOrange("operator: IDLE");
				currentState = state_t.IDLE;
				break;
			}

			case (state_t.IDLE):
			{
				/* Check for new orders */
				elev_motor_direction_t directionToNextOrder = getDirectionToNextOrder(previousValidFloor);
				if (directionToNextOrder == elev_motor_direction_t.DIRN_UP)
				{
					debug writelnOrange("operator: GOING_UP");
					elev_set_motor_direction(directionToNextOrder);
					currentState = state_t.GOING_UP;
				}
				if (directionToNextOrder == elev_motor_direction_t.DIRN_DOWN)
				{
					debug writelnOrange("operator: GOING_DOWN");
					elev_set_motor_direction(directionToNextOrder);
					currentState = state_t.GOING_DOWN;
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