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
       delegator,
       iolib;

const nrOfFloors        = 4;
const nrOfButtons       = 3;
const nrOfPeers         = 3;

void main(string[] args)
{
	// channel fra messenger til keeper
	shared NonBlockingChannel!message_t toElevatorChn = new NonBlockingChannel!message_t;
	// channel fra Keeper til network
	shared NonBlockingChannel!message_t toNetworkChn = new NonBlockingChannel!message_t;
	// channel mellom watchdog og Keeper
	shared NonBlockingChannel!message_t watchdogFeedChn = new NonBlockingChannel!message_t;
    // channel for putting orders that need to be delegated
    shared NonBlockingChannel!message_t ordersToBeDelegatedChn = new NonBlockingChannel!message_t;
    // channel for 

	debug writeln("Initializing lift hardware ...");
	elev_type ioInterface = elev_type.ET_Comedi;
	if (args.length > 1)
		if (args[1] == "sim")
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
    Tid delegatorTid;

	keeperOfSetsTid = spawn(
		&keeperOfSetsThread,
		toNetworkChn,
		toElevatorChn,
		watchdogFeedChn);

	messengerTid = spawn(
		&messengerThread,
		toNetworkChn,
		toElevatorChn);

	watchdogTid = spawn(
		&watchdogThread,
		watchdogFeedChn,
		toNetworkChn,
		toElevatorChn,
        ordersToBeDelegatedChn);

    operatorTid = spawn(
        &operatorThread,
        toElevatorChn,
        toNetworkChn);

    delegatorTid = spawn(
            &delegatorThread,
            toElevatorChn,
            toNetworkChn,
            ordersToBeDelegatedChn);

	while (true)
	{
		// Check that the threads are still running, and if not restart either the thread or the whole program?
	}
}
