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

/*
 * @brief   Thread responsible for watching the livelihood of other elevatorTAGs
 * @details watchdogThread sends orphaned orders of timed out elevatorTAGs to the delegator
 *
 * @param toNetworkChn: channel directed to external network
 * @param ordersToThiselevatorTAGChn: channel directed to this elevatorTAG
 * @param elevatorTAGID: the ID of this elevatorTAG
 */
void watchdogThread(
	ref shared NonBlockingChannel!message_t watchdogFeedChn,

	ref shared NonBlockingChannel!message_t watchdogAlertChn,

	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToThiselevatorTAGChn,
	ref shared NonBlockingChannel!message_t ordersToBeDelegatedChn,
	)
{
	debug writelnGreen("    [x] watchdogThread");

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
					confirmed.timestamps[receivedFromKeeper.orderFloor] = receivedFromKeeper.timestamp;
					latestConfirm[receivedFromKeeper.senderID] = confirmed;
					debug writeln("Woof, CONFIRM received from: ", receivedFromKeeper.senderID, "at time: ", receivedFromKeeper.timestamp);
					mostRecentConfirm[receivedFromKeeper.senderID] = receivedFromKeeper.timestamp;
					break;
				}

				case message_header_t.expediteOrder:
				{
					watchdogTAG expedited;
					expedited.orders[receivedFromKeeper.orderFloor] = true;
					expedited.timestamps[receivedFromKeeper.orderFloor] = receivedFromKeeper.timestamp;
					latestExpedite[receivedFromKeeper.senderID] = expedited;
					debug writeln("Woof, EXPEDITE received from: ", receivedFromKeeper.senderID, "at time: ", receivedFromKeeper.timestamp);
					mostRecentExpedite[receivedFromKeeper.senderID] = receivedFromKeeper.timestamp;
					break;
				}
				default:
				{
					debug writeln("Woof, non-CONFIRM/EXPEDITE received??");
				}
			}
		}
		//clearing old confirms against recent expedites
		foreach(ubyte id, elevatorTAG; latestConfirm)
		{
			foreach(floor; elevatorTAG.orders)
			if(latestExpedite[id].orders[floor] && elevatorTAG.orders[floor])
			{
				//check if there has been an expedite on a floor after the confirm for that floor
				if((Clock.currTime().toUnixTime() - latestExpedite[id].timestamps[floor])
					 < (Clock.currTime().toUnixTime()) - elevatorTAG.timestamps[floor])
				{
					elevatorTAG.orders[floor] = false;
					latestExpedite[id].orders[floor] = false;
				}
			}
		}

		//checking for confirmed orders timeing-out, and alerting KeeperOfSets if there are any.
		foreach(ubyte id, elevatorTAG; latestConfirm)
		{
			foreach(floor; elevatorTAG.orders)
			{
				//check if there is a confirmed order on this floor, and if it has passed the confirmedTimeoutThreshold without a repleneshing action in between
				if(elevatorTAG.orders[floor])
				{
					//checking for replenishing action
					if(((Clock.currTime().toUnixTime() - mostRecentConfirm[id]) < confirmedTimeoutThreshold)
						|| ((Clock.currTime().toUnixTime() - mostRecentExpedite[id]) < confirmedTimeoutThreshold))
					{
						break;
					}

					//checking for timed-out orders
					if((Clock.currTime().toUnixTime() - elevatorTAG.timestamps[floor]) > confirmedTimeoutThreshold)
					{
						message_t orderAlert;
						orderAlert.header = message_header_t.watchdogAlert;
						orderAlert.targetID = id;
						orderAlert.orderFloor = floor;
						watchdogAlertChn.insert(orderAlert);
					}
				}
			}
		}
	}
}
