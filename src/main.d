import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.container.array,
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


    keeperOfSetsTid = spawnLinked(
        &keeperOfSetsThread,
        toNetworkChn,
        toElevatorChn,
        watchdogFeedChn);

    messengerTid = spawnLinked(
        &messengerThread,
        toNetworkChn,
        toElevatorChn);

    watchdogTid = spawnLinked(
        &watchdogThread,
        watchdogFeedChn,
        toNetworkChn,
        toElevatorChn,
        ordersToBeDelegatedChn);

    operatorTid = spawnLinked(
        &operatorThread,
        toElevatorChn,
        toNetworkChn);

    delegatorTid = spawnLinked(
        &delegatorThread,
        toElevatorChn,
        toNetworkChn,
        ordersToBeDelegatedChn);
        
	while (true)
	{
		receive(
			(LinkTerminated e)
		{
			writeln("\x1B[31m *** main: A THREAD HAS TERMINATED ***");
            writeln(e);
            // TODO: kill/restart application
            Array!Tid listOfTids;
            listOfTids.insert(messengerTid);
            listOfTids.insert(keeperOfSetsTid);
            listOfTids.insert(watchdogTid);
            listOfTids.insert(operatorTid);
            listOfTids.insert(delegatorTid);
		}
			);
	}
}
