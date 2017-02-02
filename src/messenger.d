/*
imports

define delegateOrder struct:
	{
		target ID : int
		order	  : string
	}
	
	
define confirmOrder struct:
	{
		sender ID : int
		order	  : string
	}

define expediteOrder struct:
	{
		sender ID : int
		order	  : string
	}

define syncRequest struct:
	{
		sender ID : int
	}

define heartBeat Struct:
	{
		sender ID : int
		sender State : state_t
		sender Floor : int
	}

*/

struct delegateOrder
{
	int targetID;
	string order;
}

struct confirmOrder
{
	int senderID;
	string order;
}

struct expediteOrder
{
	int senderID;
	string order;
}

struct syncRequest
{
	int senderID;
}

struct heartBeat
{
	int senderID;
	int currentState; //change to state_t when implemented
	int currentFloor;
}

	
	
