import std.stdio,
	   std.concurrency,
	   std.conv,
	   std.variant,
	   core.thread,
	   core.time;
	  
	  
import main,
	   udp_bcast,
	   peers;
	   
typedef enum {INIT = 0, IDLE = 1, GOING_DOWN = 2, GOING_UP = 3, FLOORSTOP = 4} state_t; 
//TODO flyttes til statemachine

struct outgoingDelegateOrder
{
	int targetID;
	string order;
}

struct incomingDelegateOrder
{
	int targetID;
	string order;
}

struct outgoingConfirmOrder
{
	int senderID;
	string order;
}

struct incomingConfirmOrder
{
	int senderID;
	string order;
}

struct outgoingExpediteOrder
{
	int senderID;
	string order;
}

struct incomingExpediteOrder
{
	int senderID;
	string order;
}

struct syncRequest
{
	int senderID;
}

struct heartbeat
{
	int senderID;
	state_t currentState; //change to state_t when implemented
	int currentFloor;
}

void delegateOnNetwork(int targetID, string order)
{
	bcast.send(outgoingDelegateOrder(targetID, order));
}

void confirmOnNetwork(string order)
{
	bcast.send(outgoingConfirmOrder(myID, order));
}

void expediteOnNetwork(string order)
{
	bcast.send(outgoingConfirmOrder(myID, order));
}

void heartbeatOnNetwork(state_t currentState, int currentFloor)
{
	bcast.send(heartbeat(myID, currentState, currentFloor));
}


void messageThread()
{
	while(true)
	{
		receive
		(			
			(delegateOrder a)
			{
			send(keeperOfSetsTID, a);
			debug writeln("received delegateOrder: ", a.order);
			}
			(confirmOrder a)
			{
			send(keeperOfSetsTID, a);
			debug writeln("receive confirmOrder: ", a.order);
			}
			(expediteOrder a)
			{
			send(keeperOfSetsTID, a);
			debug writeln("received expediteOrder: ", a.order);
			}
			(syncRequest a)
			{
			send(keeperOfSetsTID, a);
			debug writeln("received syncRequest from: ", a.senderID);
			}
			(heartBeat a)
			{
			send(keeperOfSetsTID, a);
			debug writeln("received heartBeat: ", a.senderID);
			}
		);
	}
}
