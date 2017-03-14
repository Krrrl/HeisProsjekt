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

private watchdogTAG[ubyte] latestConfirms;
private long[ubyte] mostRecentConfirmTime;
private watchdogTAG[ubyte] latestExpedites;
private long[ubyte] mostRecentExpediteTime;

//longest do-nothing interval allowed.
private long confirmedTimeoutThreshold = 2;

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
		/* Keeping timestamp lists up-to-date */
		if(watchdogFeedChn.extract(receivedFromKeeper))
		{
            ubyte senderID = receivedFromKeeper.senderID;
            int orderFloor = receivedFromKeeper.orderFloor;
            long timestamp = receivedFromKeeper.timestamp;
			switch(receivedFromKeeper.header)
			{
                /* Update  */
				case message_header_t.confirmOrder:
				{
                    if (senderID !in latestConfirms)
                    {
                        latestConfirms[senderID] = watchdogTAG();
                    }

					latestConfirms[senderID].orders[orderFloor] = true;
                    latestConfirms[senderID].timestamps[orderFloor] = timestamp;
					debug writeln("Woof: CONFIRM received from: ", senderID, "at time: ", timestamp);
					mostRecentConfirmTime[senderID] = timestamp;
					break;
				}

                /*   */
				case message_header_t.expediteOrder:
				{
                    if (senderID !in latestExpedites)
                    {
                        latestExpedites[senderID] = watchdogTAG();
                    }
                    latestExpedites[senderID].orders[orderFloor] = true;
                    latestExpedites[senderID].timestamps[orderFloor] = timestamp;
					debug writeln("Woof: EXPEDITE received from: ", senderID, "at time: ", timestamp);
					mostRecentExpediteTime[senderID] = timestamp;
					break;
				}
				default:
				{
					debug writelnRed("Woof: non-CONFIRM/EXPEDITE received??");
				}
			}
		}

		/* Clearing old confirms against recent expedites */
		foreach(ubyte id, elevatorTAG; latestConfirms)
		{
			foreach(floor; elevatorTAG.orders.keys)
            {
                if (id in latestExpedites)
                {
                    //debug writelnRed("id in exped");
                    if (floor in latestExpedites[id].orders)
                    {
                        if(latestExpedites[id].orders[floor] && elevatorTAG.orders[floor])
                        {
                        /* Check if there has been an expedite on a floor after the confirm for that floor */
                            if((Clock.currTime().toUnixTime() - latestExpedites[id].timestamps[floor])
                                 < (Clock.currTime().toUnixTime()) - elevatorTAG.timestamps[floor])
                            {
                                debug writelnYellow("watchdog: cleared confirm with expedite");
                                elevatorTAG.orders[floor] = false;
                                latestExpedites[id].orders[floor] = false;
                            }
                        }
                    }
                }
            }
		}

		/* Checking for confirmed orders timeing-out, and alerting KeeperOfSets if there are any */
		foreach(ubyte id, elevatorTAG; latestConfirms)
		{
			foreach(floor; elevatorTAG.orders.keys)
			{
				/* Check if there is a confirmed order on this floor, and if it has passed the
                 * confirmedTimeoutThreshold without a repleneshing action in between */
                //debug writeln(elevatorTAG);
                //debug writeln(floor);
				if(elevatorTAG.orders[floor])
				{
					/* Checking for replenishing action */
                    if ((id in mostRecentConfirmTime) && (id in mostRecentConfirmTime))
                    {
                        if(((Clock.currTime().toUnixTime() - mostRecentConfirmTime[id]) < confirmedTimeoutThreshold)
                            || ((Clock.currTime().toUnixTime() - mostRecentExpediteTime[id]) < confirmedTimeoutThreshold))
                        {
                            break;
                        }
                    }

					/* Checking for timed-out orders */
					if((Clock.currTime().toUnixTime() - elevatorTAG.timestamps[floor]) > confirmedTimeoutThreshold)
					{
						message_t orderAlert;
						orderAlert.header = message_header_t.watchdogAlert;
						orderAlert.targetID = id;
						orderAlert.orderFloor = floor;

                        debug writelnRed("watchdog: ALERTING A TIMEOUT");
                        debug writeln(orderAlert);

                        /* Remove tracking */
                        elevatorTAG.orders[floor] = false;
					    latestExpedites[id].orders[floor] = false;
						watchdogAlertChn.insert(orderAlert);
					}
				}
			}
		}
	}
}
