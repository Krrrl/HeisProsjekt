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


void main(string[] args)
{
	ubyte id;
	if(args.length > 1){
		id = args[1].to!ubyte;
	}

	nrOfPeers = 2;
	nrOfFloors = 4;
	//init
	//instansier channelsan til keeperOfSets
	//spawn keeperOfSets
	//oppdater keeperOfSets med syncInfo
	//instansier channelsan til keeperOfSets
	//spawn resten av trådan
	//


	shared NonBlockingChannel!order toElevatorChn = new NonBlockingChannel!order; //channel fra network til Keeper
	shared NonBlockingChannel!order toNetworkChn = new NonBlockingChannel!order; //channel fra Keeper til network
	shared NonBlockingChannel!order	watchdogFeedChn = new NonBlockingChannel!order; //channel mellom watchdog og Keeper
	shared NonBlockingChannel!string locallyPlacedOrdersChn = new NonBlockingChannel!string; //channel mellom I/O og Keeper
	

	Tid messageTid = spawn(&messageThread, toNetworkChn, toElevatorChn, bcast);
	Tid bcast = udp_bcast.init!(order)(id, messageTid);


	//netwerks config og init, fra network-D main.d:
	//		Tid peerTx = peers.init;                    -- lage liste over peers
	//		ubyte id = peers.id;						-- returnere ID'en til peers
	//		Tid bcast = udp_bcast.init!(HelloMsg, ArrayMsg)(id);


	spawn(&keeperOfSetsThread, nrOfPeers, nrOfFloors, 
											toNetworkChn, 
											toElevatorChn, 
											watchdogFeedChn, 
											locallyPlacedOrdersChn);

	//spawn watchdog
	//spawn io-dude


	while(true)
	{
		//??
	}

}


void messageThread(shared NonBlockingChannel!order toNetworkChn, shared NonBlockingChannel!order toElevatorChn, Tid bcast)
{
	order receivedToNetworkOrder;
	order receivedToElevatorOrder;

	while(true)
	{

		if(toNetworkChn.extract(receivedToNetworkOrder))
		{
			bcast.send(receivedToNetworkOrder);
		}


		receive((order a){toElevatorChn.insert(a)});


		//TODO connection-lost scenario/handling?
	}
}




