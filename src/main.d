import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency;

import udp_bcast,
       peers;

import channels,
       keeperOfSets,
       messenger,
       watchdog,
       operator,
       iolib;

const nrOfFloors        = 4;
const nrOfPeers         = 3;

void main(string[] args)
{
    // Parse in an id if parameters are given
	ubyte id;
	if (args.length > 1)
    {
		id = parse!ubyte (args[1]);
    }
    else
    {
        id = 0;
    }

	// channel fra messenger til keeper
	shared NonBlockingChannel!order_t toElevatorChn = new NonBlockingChannel!order_t;
	// channel fra Keeper til network
	shared NonBlockingChannel!order_t toNetworkChn = new NonBlockingChannel!order_t;
	// channel mellom watchdog og Keeper
	shared NonBlockingChannel!order_t watchdogFeedChn = new NonBlockingChannel!order_t;
	// channel mellom I/O og Keeper
	shared NonBlockingChannel!string locallyPlacedOrdersChn = new NonBlockingChannel!string;

	debug writeln("Initializing lift hardware ...");
	elev_type ioInterface = elev_type.ET_Comedi;
	if (args.length > 2)
		if (args[2] == "sim")
			ioInterface = elev_type.ET_Simulation;

	elev_init(ioInterface);
	debug
	{
		if (ioInterface == elev_type.ET_Simulation)
			writeln("    [x] Simulator");
		else
			writeln("    [x] Comedilib");
	}

	debug writeln("Spawning Threads ...");
	Tid messengerTid;
	Tid keeperOfSetsTid;
	Tid watchdogTid;
    Tid operatorTid;

	keeperOfSetsTid = spawn(
		&keeperOfSetsThread,
		toNetworkChn,
		toElevatorChn,
		watchdogFeedChn,
		locallyPlacedOrdersChn);

	messengerTid = spawn(
		&messengerThread,
		toNetworkChn,
		toElevatorChn,
		id);

	watchdogTid = spawn(
		&watchdogThread,
		watchdogFeedChn,
		toNetworkChn,
		toElevatorChn,
        locallyPlacedOrdersChn, // watchdog puts orphaned orders in this channel
		id);

    operatorTid = spawn(
        &operatorThread,
        toElevatorChn,
        toNetworkChn);

	Tid peerTx = peers.init;

	//netwerks config og init, fra network-D main.d:
	//		Tid peerTx = peers.init;                    -- lage liste over peers
	//		ubyte id = peers.id;						-- returnere ID'en til peers
	//		Tid networkTid = udp_bcast.init!(HelloMsg, ArrayMsg)(id);


	//spawn watchdog
	//spawn io-dude

	while (true)
	{

		// Check that the threads are still running, and if not restart either the thread or the whole program?
	}



}
