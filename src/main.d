import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.container.array,
       std.conv,
       std.concurrency;

import udp_bcast,
       peers,
       channels;

import debugUtils,
       coordinator,
       routor,
       watchdog,
       operator,
       delegator,
       iolib;

const nrOfFloors        = 4;
const nrOfButtons       = 3;
const nrOfPeers         = 3;

void main(string[] args)
{
	shared NonBlockingChannel!message_t ordersToThisElevatorChn = new NonBlockingChannel!message_t;
	shared NonBlockingChannel!message_t toNetworkChn = new NonBlockingChannel!message_t;
	shared NonBlockingChannel!message_t watchdogFeedChn = new NonBlockingChannel!message_t;
	shared NonBlockingChannel!message_t ordersToBeDelegatedChn = new NonBlockingChannel!message_t;
	shared NonBlockingChannel!message_t orderConfirmationsReceivedChn = new NonBlockingChannel!message_t;
	shared NonBlockingChannel!PeerList peerListChn = new NonBlockingChannel!PeerList;
	shared NonBlockingChannel!orderList_t operatorsOrdersChn = new
        NonBlockingChannel!orderList_t;
    shared NonBlockingChannel!message_t watchdogAlertChn = new NonBlockingChannel!message_t;

	debug writeln("Initializing lift hardware ...");
	elev_type ioInterface = elev_type.ET_Comedi;
	if (args.length > 1)
		if (args[1] == "sim")
			ioInterface = elev_type.ET_Simulation;

	elev_init(ioInterface);
	debug
	{
		if (ioInterface == elev_type.ET_Simulation)
			debug writelnGreen("    [x] Simulator");
		else
			debug writelnGreen("    [x] Comedilib");
	}

	debug writeln("Spawning Threads ...");
	Tid routorTid;
	Tid coordinatorTid;
	Tid watchdogTid;
	Tid operatorTid;
	Tid delegatorTid;
    Tid buttonCheckerTid;


	coordinatorTid = spawnLinked(
		&coordinatorThread,
		toNetworkChn,
		ordersToThisElevatorChn,
		ordersToBeDelegatedChn,
		watchdogFeedChn,
		watchdogAlertChn,
		operatorsOrdersChn,
		peerListChn);

	routorTid = spawnLinked(
		&routorThread,
		toNetworkChn,
		ordersToThisElevatorChn,
		orderConfirmationsReceivedChn,
		peerListChn);

	watchdogTid = spawnLinked(
		&watchdogThread,
		watchdogFeedChn,
		watchdogAlertChn);

	operatorTid = spawnLinked(
		&operatorThread,
		toNetworkChn,
		operatorsOrdersChn);

	delegatorTid = spawnLinked(
		&delegatorThread,
		toNetworkChn,
		ordersToBeDelegatedChn,
		orderConfirmationsReceivedChn);

	buttonCheckerTid = spawnLinked(
		&buttonCheckerThread,
		ordersToBeDelegatedChn);

	while (true)
	{
		receive(
			(LinkTerminated e)
		{
			writelnRed("*** main: A THREAD HAS TERMINATED ***");
			writeln(e);

			/* Stop motor forever to avoid undefined behaviour */
			while (true)
				elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
		}
			);
	}
}
