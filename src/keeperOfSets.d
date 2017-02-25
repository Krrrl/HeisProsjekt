import std.stdio;

import messenger,
       channels;


void keeperOfSetsThread(shared NonBlockingChannel!order_t toNetworkChn,
			shared NonBlockingChannel!order_t toElevatorChn,
			shared NonBlockingChannel!order_t watchdogFeedChn,
			shared NonBlockingChannel!string locallyPlacedOrdersChn)
{
    debug
    {
        writeln("    [x] keeperOfSetsThread");
    }

	order_t receivedFromNetwork;
	string localOrderInstance;

	while (true)
	{
		if (toElevatorChn.extract(receivedFromNetwork))
		{
            debug {
                writeln("keeperOfSets: received ");
                //printOrder(receivedFromNetwork);
            }
/*
			switch (receivedFromNetwork.type)
			{
                case order_header_t.delegateOrder:
                {
                    //if .targetID == myID
                    //add to my own set
                    //post orderConfirmation to toNetworkChn
                }
                case order_header_t.confirmOrder:
                {
                    //update sender's order set
                    //set light in
                }
                case order_header_t.expediteOrder:
                {
                    //remove order from sender's order set
                    //remove light
                    //
                }
                case order_header_t.syncRequest:
                {
                    //if myIP is the highest of my peers
                    // post syncInfo(.senderID) to toNetworkChn
                }
                case order_header_t.heartBeat:
                {
                    //update senders state set
                    //let watchdog know?
                }
                default:
                    //discard message
			}
            */
		}
		//orders from IO
		//Delegate, then post to toNetwork
		if (locallyPlacedOrdersChn.extract(localOrderInstance))
		{
			//order_t = delegateOrder(localOrderInstance);

		}
	}
	//lage egne liste
	//lage liste for de andre heisan
}
