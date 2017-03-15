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
       coordinator,
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
	/* Channel fra messenger til coordinator */
	shared NonBlockingChannel!message_t ordersToThisElevatorChn = new NonBlockingChannel!message_t;
	/* channel fra Keeper til network */
	shared NonBlockingChannel!message_t toNetworkChn = new NonBlockingChannel!message_t;
	/* channel mellom watchdog og Keeper */
	shared NonBlockingChannel!message_t watchdogFeedChn = new NonBlockingChannel!message_t;
	/* channel for putting orders that need to be delegated */
	shared NonBlockingChannel!message_t ordersToBeDelegatedChn = new NonBlockingChannel!message_t;
	/* channel for putting received order confirmations between delegator and messenger */
	shared NonBlockingChannel!message_t orderConfirmationsReceivedChn = new NonBlockingChannel!message_t;
	/* channel for passing peer list to Keeper */
	shared NonBlockingChannel!PeerList peerListChn = new NonBlockingChannel!PeerList;
	/* channel for updating the operator on this elevators current orders*/
	shared NonBlockingChannel!orderList_t operatorsOrdersChn = new
        NonBlockingChannel!orderList_t;
    /* channel for watchdog-alerts to coordinator about timed-out orders */
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
	Tid messengerTid;
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

	messengerTid = spawnLinked(
		&messengerThread,
		toNetworkChn,
		ordersToThisElevatorChn,
		orderConfirmationsReceivedChn,
		peerListChn);

	watchdogTid = spawnLinked(
		&watchdogThread,
		watchdogFeedChn,
		watchdogAlertChn,
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

			// TODO: use Tid's to kill all threads
			Array!Tid listOfTids;
			listOfTids.insert(messengerTid);
			listOfTids.insert(coordinatorTid);
			listOfTids.insert(watchdogTid);
			listOfTids.insert(operatorTid);
			listOfTids.insert(delegatorTid);

			/* Stop motor forever to avoid undefined behaviour */
			while (true)
				elev_set_motor_direction(elev_motor_direction_t.DIRN_STOP);
		}
			);
	}
}
