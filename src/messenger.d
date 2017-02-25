import std.stdio,
       std.concurrency,
       std.conv,
       std.variant,
       core.thread,
       core.time;


import main,
       udp_bcast,
       peers,
       channels,
       keeperOfSets,
       operator;

/*
 * @brief   Header used for switching content of order_t messages
 */
enum order_header_t
{
	delegateOrder = 0,
	confirmOrder,
	expediteOrder,
	syncRequest,
	syncInfo,
	heartbeat
}

/*
 * @brief   Message struct passed internally between threads and externally between elevators
 * @TODO    Jeg mener vi burde kalle meldings structen noe som "message_t", siden den ikke bare inneholder orders, men også heartbeats, syncInfo etc... f.ex: message_t; packet_t;
 */
struct order_t
{
	order_header_t type;
	string senderID;
	string targetID;
	string orderDeclaration;
	state_t currentState;
	int currentFloor;
	int timestamp;
}

/*
 * @brief   Prints the contents of an order_t message
 * @details Mostly used for debugging
 *
 * @param order_t:  the message which contents will be printed
 */
void print_order_content(order_t order)
{
	writeln("order:");
	write("    type: ");
	switch (order.type)
	{
	case order_header_t.delegateOrder:
	{
		writeln("delegateOrder");
		break;
	}
	case order_header_t.confirmOrder:
	{
		writeln("confirmOrder");
		break;
	}
	case order_header_t.expediteOrder:
	{
		writeln("expediteOrder");
		break;
	}
	case order_header_t.syncRequest:
	{
		writeln("syncRequest");
		break;
	}
	case order_header_t.syncInfo:
	{
		writeln("syncInfo");
		break;
	}
	case order_header_t.heartbeat:
	{
		writeln("heartbeat");
		break;
	}
	default:
		writeln("unknownOrderType");
		break;
	}
	writeln("    senderID:", order.senderID);
	writeln("    targetID:", order.targetID);
	writeln("    orderDeclaration:", order.orderDeclaration);
	writeln("    currentState:", order.currentState);
	writeln("    currentFloor:", order.currentFloor);
	writeln("    timestamp:", order.timestamp);
}

/*
 * @brief   Thread responsible for passing messages between network module and remaining modules
 * @details xxx
 *
 * @param toNetworkChn: channel directed to external network
 * @param toElevatorChn: channel directed to this elevator TODO: check if names correspond to use
 * @param elevatorID: the ID of this elevator
 */
void messengerThread(
	ref shared NonBlockingChannel!order_t toNetworkChn,
	ref shared NonBlockingChannel!order_t toElevatorChn,
	ubyte elevatorID
	)
{
	debug writeln("    [x] messengerThread");
	Tid networkTid;
	networkTid = udp_bcast.init!(order_t)(id, thisTid());

	order_t receivedToNetworkOrder;
	order_t receivedToElevatorOrder;

	while (true)
	{
		if (toNetworkChn.extract(receivedToNetworkOrder))
        {
			debug writeln("messenger: passing order to network");
            networkTid.send(receivedToNetworkOrder);
        }

		// Only the network thread uses receive
		receiveTimeout(
			msecs(1),
			(order_t orderFromNetwork)
		{
			writeln("messenger: received order from network");
			writeln(orderFromNetwork);
		},
			(Variant v)
		{
			writeln("messenger: received Variant from network");
		}
			);

		debug Thread.sleep(msecs(10));
		//TODO: connection-lost scenario/handling?
	}
}




