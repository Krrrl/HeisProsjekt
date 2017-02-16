//TODO ordne imports
import messengerC,
	   channels;



//NB MERGED MED DELEGATOR

// Ser ut som enums i D ikke vil ha typer som 'navn', her må vi finne på noe annet.
enum  order_t
{
    "delegateOrder" = 0,
    "confirmOrder" = 1,
    "expediteOrder" = 2,
    "syncRequest" = 3,
    "heartBeat" = 4
}


enum state_t
{
    INIT = 0,
    IDLE = 1,
    GOING_DOWN = 2,
    GOING_UP = 3,
    FLOORSTOP = 4
}

void keeperOfSetsThread(shared NonBlockingChannel!order toNetworkChn, 
						shared NonBlockingChannel!order toElevatorChn, 
						shared NonBlockingChannel!order watchdogFeedChn, 
						shared NonBlockingChannel!string locallyPlacedOrdersChn)
{
	order receivedFromNetwork;
	string localOrderInstance;

	while(true)
	{
		if(toElevatorChn.extract(receivedFromNetwork))
		{
			switch(receivedFromNetwork.type)
			{
					case "delegateOrder":
					{
						//if .targetID == myID
						//add to my own set
						//post orderConfirmation to toNetworkChn
					}
					case "confirmOrder":
					{
						//update sender's order set
						//set light in 
					}
					case "expediteOrder":
					{
						//remove order from sender's order set
						//remove light
						//
					}
					case "syncRequest":
					{
						//if myIP is the highest of my peers
						// post syncInfo(.senderID) to toNetworkChn
					}
					case "heartBeat":
					{
						//update senders state set
						//let watchdog know?
					}
					default:
					//discard message
			}
		}
		//orders from IO
		//Delegate, then post to toNetwork
		if(locallyPlacedOrdersChn.extract(localOrderInstance))
		{
			order = delegateOrder(localOrderInstance);

		}
	}
	//lage egne liste
	//lage liste for de andre heisan
}
