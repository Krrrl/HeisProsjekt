import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency,
       std.datetime;

import udp_bcast,
       peers,
       messenger,
       keeperOfSets,
       main;

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

struct watchdogTAG
{
	bool[int] orders;
	long[int] timestamps;
}

private watchdogTAG[ubyte] latestConfirm;
private long[ubyte] mostRecentConfirm;
private watchdogTAG[ubyte] latestExpedite;
private long[ubyte] mostRecentExpedite;

//longest do-nothing interval allowed.
private long confirmedTimeoutThreshold = 4;

void watchdogThread(
	ref shared NonBlockingChannel!message_t watchdogFeedChn,

	ref shared NonBlockingChannel!message_t watchdogAlertChn,

	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn,
	)
{
	debug writelnGreen("    [x] watchdogThread");



	// Wait for other threads to initialize before starting the Night's Watch
	Thread.sleep(msecs(20));

	int heartBeats = 0;

	message_t receivedFromKeeper;

	while (true)
	{
		//debug writeln("watchdog: [self] heartbeat ", heartBeats++);

		//keeping lists up-to-date
		if(watchdogFeedChn.extract(receivedFromKeeper))
		{
			switch(receivedFromKeeper.header)
			{
				case message_header_t.confirmOrder:
				{
					watchdogTAG confirmed;
					confirmed.orders[receivedFromKeeper.orderFloor] = true;
					confirmed.timestamps[receivedFromKeeper.orderFloor] =
                        receivedFromKeeper.timestamp;
					latestConfirm[receivedFromKeeper.senderID] = confirmed;
					debug writeln("Woof, CONFIRM received from: ", receivedFromKeeper.senderID, "at time: ", receivedFromKeeper.timestamp);
					mostRecentConfirm[receivedFromKeeper.senderID] = receivedFromKeeper.timestamp;
					break;
				}

				case message_header_t.expediteOrder:
				{
					watchdogTAG expedited;
					expedited.orders[receivedFromKeeper.orderFloor] = true;
					expedited.timestamps[receivedFromKeeper.orderFloor] =
                        receivedFromKeeper.timestamp;
					latestExpedite[receivedFromKeeper.senderID] = expedited;
					debug writeln("Woof, EXPEDITE received from: ", receivedFromKeeper.senderID, "at time: ", receivedFromKeeper.timestamp);
					mostRecentExpedite[receivedFromKeeper.senderID] = receivedFromKeeper.timestamp;
					break;
				}
			}
		}

		//clearing old confirms against recent expedites
		foreach(elevator; latestConfirm)//assuming latestConfirm and latestExpedite is of same length
		{
			foreach(floor; main.nrOfFloors)
			if(latestExpedite[elevator].orders[floor] && latestConfirm.orders[floor])
			{
				//check if there has been an expedite on a floor after the confirm for that floor
				if((Clock.currTime().toUnixTime() - latestExpedite[elevator].timestamps[floor])
					 < (Clock.currTime().toUnixTime()) - latestConfirm[elevator].timestamps[floor])
				{
					latestConfirm[elevator].orders[floor] = false;
					latestExpedite[elevator].orders[floor] = false;
				}
			}
		}

		//checking for confirmed orders timeing-out, and alerting KeeperOfSets if there are any.
		foreach(elevator; latestConfirm)//again assuming latestConfirm and latestExpedite is of same length.
		{
			foreach(floor; main.nrOfFloors)
			{
				//check if there is a confirmed order on this floor, and if it has passed the confirmedTimeoutThreshold without a repleneshing action in between
				if(latestConfirm[elevator].orders[floor])
				{
					//checking for replenishing action
					if(((Clock.currTime().toUnixTime() - mostRecentConfirm[elevator]) < confirmedTimeoutThreshold)
						|| ((Clock.currTime().toUnixTime() - mostRecentExpedite[elevator]) < confirmedTimeoutThreshold))
					{
						break;
					}

					//checking for timed-out orders
					if((Clock.currTime().toUnixTime() - latestConfirm[elevator].timestamps[floor]) > confirmedTimeoutThreshold)
					{
						message_t orderAlert;
						orderAlert.header = message_header_t.watchdogAlert;
						orderAlert.targetID = elevator;
						orderAlert.orderFloor = floor;
						watchdogAlertChn.insert(orderAlert);
					}
				}
			}
		}
		Thread.getThis().sleep(seconds(4)); //for the night is _long_ and full of errors
	}
}
