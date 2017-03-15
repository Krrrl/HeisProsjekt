import core.time,
       core.thread,
       std.stdio,
       std.string,
       std.conv,
       std.concurrency,
       std.datetime;

import udp_bcast,
       peers;

import main,
       messenger,
       debugUtils,
       channels,
       coordinator,
       messenger,
       iolib;


struct watchdogTag
{
	bool[int] orders;
	long[int] timestamps;
}

private watchdogTag[ubyte] latestConfirms;
private long[ubyte] mostRecentConfirmTime;
private watchdogTag[ubyte] latestExpedites;
private long[ubyte] mostRecentExpediteTime;

private long confirmedTimeoutThresholdms = 15;

/* Thread watching the livelihood of elevators with orders */
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
                /* Update confirm lists */
				case message_header_t.confirmOrder:
				{
                    if (senderID !in latestConfirms)
                    {
                        latestConfirms[senderID] = watchdogTag();
                    }

					latestConfirms[senderID].orders[orderFloor] = true;
                    latestConfirms[senderID].timestamps[orderFloor] = timestamp;
					debug writeln("Woof: confirm received from: ", senderID, "at time: ", timestamp);
					mostRecentConfirmTime[senderID] = timestamp;
					break;
				}

                /* Update expedite lists */
				case message_header_t.expediteOrder:
				{
                    if (senderID !in latestExpedites)
                    {
                        latestExpedites[senderID] = watchdogTag();
                    }
                    latestExpedites[senderID].orders[orderFloor] = true;
                    latestExpedites[senderID].timestamps[orderFloor] = timestamp;
					debug writeln("watchdog: expedite received from: ", senderID, "at time: ", timestamp);
					mostRecentExpediteTime[senderID] = timestamp;
					break;
				}
				default:
				{
					debug writelnRed("watchdog: non-confirm/expedite received");
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

		/* Checking for timed out orders, that will be reported to coordinator */
		foreach(ubyte id, elevatorTAG; latestConfirms)
		{
            bool replenished = false;
			foreach(floor; elevatorTAG.orders.keys)
			{
				/* Check for confirmed order on each floor, and if it has passed the
                 * confirmedTimeoutThresholdms without a repleneshing action in between */
				if(elevatorTAG.orders[floor])
				{
					/* Checking for replenishing activity */
                    if ((id in mostRecentConfirmTime) && (id in mostRecentConfirmTime))
                    {
                        if(((Clock.currTime().toUnixTime() - mostRecentConfirmTime[id]) < confirmedTimeoutThresholdms)
                            || ((Clock.currTime().toUnixTime() - mostRecentExpediteTime[id]) < confirmedTimeoutThresholdms))
                        {
                            replenished = true;
                        }
                    }

					/* Checking for timed-out orders if elevator isn't active */
                    if (!replenished)
                    {
                        if((Clock.currTime().toUnixTime() - elevatorTAG.timestamps[floor]) > confirmedTimeoutThresholdms)
                        {
                            message_t orderAlert;
                            orderAlert.header = message_header_t.watchdogAlert;
                            orderAlert.targetID = id;
                            orderAlert.orderFloor = floor;

                            debug writelnRed("watchdog: Alerting coordinator about timeout");
                            debug writeln(orderAlert);

                            /* Remove confirm and expedite so they don't time out again */
                            elevatorTAG.orders[floor] = false;
                            latestExpedites[id].orders[floor] = false;
                            watchdogAlertChn.insert(orderAlert);
                        }
                    }
				}
			}
		}
	}
}
