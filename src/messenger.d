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
 * @brief   Header used for switching content of message_t messages
 */
enum message_header_t
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
struct message_t
{
	message_header_t type;
	ubyte senderID;
	ubyte targetID;
	int orderFloor;
	direction_t orderDir;
	state_t currentState;
	int currentFloor;
	int timestamp;
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
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t toElevatorChn,
	ubyte elevatorID
	)
{
	debug writeln("    [x] messengerThread");
	Tid networkTid;
	networkTid = udp_bcast.init!(message_t)(id, thisTid());

	message_t receivedToNetworkOrder;
	message_t receivedToElevatorOrder;

	while (true)
	{
		if (toNetworkChn.extract(receivedToNetworkOrder))
		{
			debug writeln("messenger: passing  to network");

			if ( (receivedToNetworkOrder.message_header_t == message_header_t.delegateOrder)
			    && (receivedToNetworkOrder.orderDir == direction_t.INTERNAL)
                )
            {
				toElevatorChn.insert(recivedToNetworkOrder);
            }
			else
            {
				networkTid.send(receivedToNetworkOrder);
            }
		}

		// Only the network thread uses receive
		receiveTimeout(
			msecs(1),
			(message_t orderFromNetwork)
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
	}
}




