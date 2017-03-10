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
       debugUtils,
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
	/* Channel fra messenger til keeper */
	shared NonBlockingChannel!message_t ordersToThisElevatorChn = new NonBlockingChannel!message_t;
	/* channel fra Keeper til network */
	shared NonBlockingChannel!message_t toNetworkChn = new NonBlockingChannel!message_t;
	/* channel mellom watchdog og Keeper */
	shared NonBlockingChannel!message_t watchdogFeedChn = new NonBlockingChannel!message_t;
	/* channel for putting orders that need to be delegated */
	shared NonBlockingChannel!message_t ordersToBeDelegatedChn = new NonBlockingChannel!message_t;
  /* channel for passing peer list to Keeper */
  shared NonBlockingChannel!PeerList peerListChn = new NonBlockingChannel!PeerList;
	/* channel for updating the operator on this elevators current orders*/
  shared NonBlockingChannel!OrderList operatorsOrdersChn = new NonBlockingChannel!OrderList;

	debug writeln("Initializing lift hardware ...");
	elev_type ioInterface = elev_type.ET_Comedi;
	if (args.length > 1)
		if (args[1] == "sim")
			ioInterface = elev_type.ET_Simulation;

	elev_init(ioInterface);
	debug
	{
		if (ioInterface == elev_type.ET_Simulation)
			writelnGreen("    [x] Simulator");
		else
			writelnGreen("    [x] Comedilib");
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
        ordersToThisElevatorChn,
        watchdogFeedChn,
        operatorsOrdersChn,
        peerListChn);

    messengerTid = spawnLinked(
        &messengerThread,
        toNetworkChn,
        ordersToThisElevatorChn,
        peerListChn);

    watchdogTid = spawnLinked(
        &watchdogThread,
        watchdogFeedChn,
        toNetworkChn,
        ordersToThisElevatorChn,
        ordersToBeDelegatedChn);

    operatorTid = spawnLinked(
        &operatorThread,
        ordersToThisElevatorChn,
        toNetworkChn,
        operatorsOrdersChn);

    delegatorTid = spawnLinked(
        &delegatorThread,
        ordersToThisElevatorChn,
        toNetworkChn,
        ordersToBeDelegatedChn);
        
	while (true)
	{
		receive(
			(LinkTerminated e)
		{
			writelnRed("*** main: A THREAD HAS TERMINATED ***");
            writeln(e);

            // TODO: use Tid's to kill all threads
            Array!Tid listOfTids;
            listOfTids.insert(messengerTid);
            listOfTids.insert(keeperOfSetsTid);
            listOfTids.insert(watchdogTid);
            listOfTids.insert(operatorTid);
            listOfTids.insert(delegatorTid);

            /* Stop motor forever to avoid undefined behaviour */
            while (true)
            {
              elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
            }
		}
			);
	}
}
