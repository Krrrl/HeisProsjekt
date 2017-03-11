import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency;

import udp_bcast,
       peers;

import debugUtils,
       channels,
       keeperOfSets,
       messenger,
       iolib;

/*
 * @brief   Thread responsible for watching the livelihood of other elevators
 * @details watchdogThread sends orphaned orders of timed out elevators to the delegator
 *
 * @param toNetworkChn: channel directed to external network
 * @param ordersToThisElevatorChn: channel directed to this elevator
 * @param elevatorID: the ID of this elevator
 */
void watchdogThread(
	ref shared NonBlockingChannel!message_t watchdogFeedChn,
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn,
	)
{
	debug writelnGreen("    [x] watchdogThread");

	// Wait for other threads to initialize before starting the Night's Watch
	Thread.sleep(msecs(20));

	int heartBeats = 0;

	while (true)
	{
		//debug writeln("watchdog: [self] heartbeat ", heartBeats++);

		Thread.getThis().sleep(seconds(4));
	}
}
