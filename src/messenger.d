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
       keeperOfSets;

enum order_header_t
{
	delegateOrder = 0,
	confirmOrder,
	expediteOrder,
	syncRequest,
	heartBeat
}

struct order
{
	order_header_t type;
	string senderID;
	string targetID;
	string orderDeclaration;
	state_t currentState;
	int currentFloor;
	int timestamp;
}

void messageThread(shared NonBlockingChannel!order toNetworkChn,
		   shared NonBlockingChannel!order toElevatorChn, Tid networkTid)
{
	order receivedToNetworkOrder;
	order receivedToElevatorOrder;

	while (true)
	{

		if (toNetworkChn.extract(receivedToNetworkOrder))
			networkTid.send(receivedToNetworkOrder);



        // Only the network thread uses receive
		receive(
			(order a)
		{
			toElevatorChn.insert(a);
		}
			);

		//TODO connection-lost scenario/handling?
	}
}




