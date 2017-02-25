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
       iolib;

/*
 * @brief   Thread responsible for watching the livelihood of other elevators
 * @details watchdogThread sends orphaned orders of timed out elevators to the delegator
 *
 * @param toNetworkChn: channel directed to external network
 * @param toElevatorChn: channel directed to this elevator
 * @param elevatorID: the ID of this elevator
 */
void watchdogThread(
	ref shared NonBlockingChannel!order_t watchdogFeedChn,
	ref shared NonBlockingChannel!order_t toNetworkChn,
	ref shared NonBlockingChannel!order_t toElevatorChn,
    ref shared NonBlockingChannel!string locallyPlacedOrdersChn,
	ubyte elevatorID
	)
{
	debug writeln("    [x] watchdogThread");

    // Wait for other threads to initialize before starting the Night's Watch
    Thread.sleep(msecs(20));

    int heartBeats = 0;

	while (true)
	{
		debug writeln("watchdog: [self] heartbeat ", heartBeats++);

		Thread.getThis().sleep(seconds(4));
	}
}
