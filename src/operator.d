import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency,
       std.datetime,
       std.algorithm.searching;

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

private shared state_t currentState = state_t.INIT;
private shared int currentFloor;

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
	ordersForThisElevator[button_type_t.UP] = orders.upQueue.dup;
	ordersForThisElevator[button_type_t.DOWN] = orders.downQueue.dup;
	ordersForThisElevator[button_type_t.INTERNAL] = orders.internalQueue.dup;
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
			debug writelnOrange("operator: updating my orders");
			debug writeln(ordersUpdate);
			updateOrdersForThisElevator(ordersUpdate);
			debug writeln(ordersForThisElevator);
		}

		/* Read floor sensors */
		currentFloor = elev_get_floor_sensor_signal();

		/* Do state dependent actions */
		switch(getCurrentState())
		{
			case (state_t.INIT):
			{
				// Find a floor, go up/down?
				// Wait for syncInfo?

				/* Go to idle */
				currentState = state_t.IDLE;

				break;
			}
			case (state_t.GOING_UP):
			{
				if (button_type_t.UP in ordersForThisElevator)
				{
					if (canFind(ordersForThisElevator[button_type_t.UP], currentFloor))
					{
						debug writelnOrange("operator: FLOORSTOP");
						currentState = state_t.FLOORSTOP;
					}
				}
				if (button_type_t.UP in ordersForThisElevator)
				{
					if (canFind(ordersForThisElevator[button_type_t.UP], currentFloor))
					{
						debug writelnOrange("operator: FLOORSTOP");
						currentState = state_t.FLOORSTOP;
					}
				}
				break;
			}
			case (state_t.GOING_DOWN):
			{
				if (canFind(ordersForThisElevator[button_type_t.DOWN], currentFloor)
					|| canFind(ordersForThisElevator[button_type_t.INTERNAL], currentFloor))
				{
					debug writelnOrange("operator: FLOORSTOP");
					currentState = state_t.FLOORSTOP;
				}
				break;
			}
			case (state_t.FLOORSTOP):
			{
				elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);

				// Open door & Set doorlight
				// Send expedite
				// Goto Floorstop
				// Start timer

				// Timeout
				debug writelnOrange("operator: IDLE");
				currentState = state_t.IDLE;
				break;
			}

			case (state_t.IDLE):
			{
				/* Check for new orders */

				break;
			}
			default:
			{
				break;
			}
		}
	}
}




