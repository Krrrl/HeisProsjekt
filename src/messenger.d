import std.stdio,
	   std.concurrency,
	   std.conv,
	   std.variant,
	   core.thread,
	   core.time;
	  
	  
import main,
	   udp_bcast,
	   peers,
	   channels;

struct order
{
	order_t type;
	string senderID;
	string targetID;
	string orderDeclaration;
	state_t currentState;
	int currentFloor;
	int timestamp;
};

void messageThread(shared NonBlockingChannel!order toNetworkChn, 
					shared NonBlockingChannel!order toElevatorChn, Tid bcast)
{
	order receivedToNetworkOrder;
	order receivedToElevatorOrder;

	while(true)
	{

		if(toNetworkChn.extract(receivedToNetworkOrder))
		{
			bcast.send(receivedToNetworkOrder);
		}


		receive(
            (order a)
            {
            toElevatorChn.insert(a);}
        );

		//TODO connection-lost scenario/handling?
	}
}




