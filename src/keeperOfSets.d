import std.stdio;

import main,
       messenger,
       operator,
       channels;

enum direction_t
{
	DOWN            = 0,
	UP              = 1,
	INTERNAL        = 2
}

class ext_elevator_t{
public:
	string[main.nrOfFloors] upQueue;
	string[main.nrOfFloors] downQueue;
	string[main.nrOfFloors] internalOrders;
	bool alive;
	state_t currentState;


	string[] getQueue(direction_t);
}


// findMatch (



	private string[main.nrOfFloors] upQueue;
	private string[main.nrOfFloors] downQueue;
	private string[main.nrOfFloors] internalOrders;


	message_t confirmOrderToNetwork(string orderDeclaration, main.myID)
{


}

	message_t expediteOrderToNetwork(string orderDeclaration, main.myID)
{


}


	string nextInQueue(direction_t)
{


}





	void keeperOfSetsThread(
		shared NonBlockingChannel!message_t toNetworkChn,
		shared NonBlockingChannel!message_t toElevatorChn,
		shared NonBlockingChannel!message_t watchdogFeedChn)
{
	debug
	{
		writeln("    [x] keeperOfSetsThread");
	}

	//Generate your own sets





	//Generate sets for all other elevators
	foreach (int elev; 0..main.nrOfElevators - 1)
	{

	}

	while (true)
	{
		if (toElevatorChn.exstract(receivedFromNetwork))
		{
			debug { writeln("Received from toElevChn: ", receivedFromNetwork); }

		}

	}




	message_t receivedFromNetwork;
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
	                //message_t = delegateOrder(localOrderInstance);

		}
	}
	//lage egne liste
	//lage liste for de andre heisan
}
