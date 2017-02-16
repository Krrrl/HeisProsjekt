import std.stdio,
       std.string,
       std.conv,
       std.concurrency;

import udp_bcast,
       peers;

import channels,
       keeperOfSets,
       messenger,
       iolib;

const nrOfFloors = 4;
const nrOfPeers = 3;

void main(string[] args)
{

    ubyte id;

	if (args.length > 1)
        id = parse!ubyte(args[1]);
    //id = args[1].to!(ubyte);

	//init
	//instansier channelsan til keeperOfSets
	//spawn keeperOfSets
	//oppdater keeperOfSets med syncInfo
	//spawn resten av trådan
	//


	shared NonBlockingChannel!order toElevatorChn = new NonBlockingChannel!order;                   //channel fra network til Keeper
	shared NonBlockingChannel!order toNetworkChn = new NonBlockingChannel!order;                    //channel fra Keeper til network
	shared NonBlockingChannel!order watchdogFeedChn = new NonBlockingChannel!order;                 //channel mellom watchdog og Keeper
	shared NonBlockingChannel!string locallyPlacedOrdersChn = new NonBlockingChannel!string;        //channel mellom I/O og Keeper

    Tid messengerTid;
    Tid networkTid;

	messengerTid = spawn(&messageThread, toNetworkChn, toElevatorChn, networkTid);
	networkTid = udp_bcast.init!(order)(id, messengerTid);


	//netwerks config og init, fra network-D main.d:
	//		Tid peerTx = peers.init;                    -- lage liste over peers
	//		ubyte id = peers.id;						-- returnere ID'en til peers
	//		Tid networkTid = udp_bcast.init!(HelloMsg, ArrayMsg)(id);


	spawn(&keeperOfSetsThread,
	      toNetworkChn,
	      toElevatorChn,
	      watchdogFeedChn,
	      locallyPlacedOrdersChn);

	//spawn watchdog
	//spawn io-dude


	while (true)
	{
		//??
	}

}
