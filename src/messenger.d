import std.stdio,
       std.concurrency,
       std.conv,
       std.variant,
       std.datetime,
       core.thread,
       core.time;


import main,
       debugUtils,
       udp_bcast,
       peers,
       channels,
       keeperOfSets,
       operator;


enum button_type_t
{
	UP              = 0,
	DOWN            = 1,
	INTERNAL        = 2
}

struct button_types_t
{
	button_type_t[3] buttons = [
		button_type_t.UP,
		button_type_t.DOWN,
		button_type_t.INTERNAL
	];

	int opApply(scope int delegate(ref button_type_t) dg)
	{
		int result = 0;

		for (int i = 0; i < buttons.length; i++)
		{
			result = dg(buttons[i]);
			if (result)
				break;
		}
		return result;
	}
}

/*
 * @brief   Header used for switching content of message_t messages
 */
enum message_header_t
{
	delegateOrder = 0,
	confirmOrder,
	expediteOrder,
	syncRequest,
	syncInfo,
	heartbeat
}

/*
 * @brief   Message struct passed internally between threads and externally between elevators
 */
struct message_t
{
	message_header_t header;
	ubyte senderID;
	ubyte targetID;
	int orderFloor;
	button_type_t orderDirection;
	state_t currentState;
	int currentFloor;
	long timestamp;
	shared int[main.nrOfFloors] syncInfo;
}

private shared ubyte _myID = 0;

private PeerList peerList;

ubyte getMyID()
{
	return _myID;
}

PeerList getPeerList()
{
	return peerList;
}

void updatePeerList(PeerList list)
{
	peerList = list;
	debug writeln(" >> PeerList", getPeerList());
}

message_t createSyncRequest()
{
	message_t newSyncMessage;

	newSyncMessage.header   = message_header_t.syncRequest;
	newSyncMessage.senderID = getMyID();
    newSyncMessage.currentState = getCurrentState();
    newSyncMessage.currentFloor = getPreviousValidFloor();
    newSyncMessage.timestamp = Clock.currTime().toUnixTime();

	return newSyncMessage;
}

/*
 * @brief   Thread responsible for passing messages between network module and remaining modules
 * @details xxx
 *
 * @param toNetworkChn: channel directed to external network
 * @param toElevatorChn: channel directed to this elevator TODO: check if names correspond to use
 * @param elevatorID: the ID of this elevator
 */
void messengerThread(
	ref shared NonBlockingChannel!message_t toNetworkChn,
	ref shared NonBlockingChannel!message_t ordersToThisElevatorChn,
	ref shared NonBlockingChannel!PeerList peerListChn,
	)
{
	debug writelnGreen("    [x] messengerThread");
	Tid peerTx = peers.init;
	_myID = peers.id;
	debug writeln("messenger: myID is [", getMyID(), "]");
	Tid networkTid = udp_bcast.init!(message_t)(getMyID(), thisTid());

    debug writeln("messenger: sending sync request");
    toNetworkChn.insert(createSyncRequest());

	message_t receivedToNetworkOrder;
	message_t receivedToElevatorOrder;

	while (true)
	{
		if (toNetworkChn.extract(receivedToNetworkOrder))
		{
			if ( (receivedToNetworkOrder.header == message_header_t.delegateOrder)
			     && (receivedToNetworkOrder.targetID == getMyID())
			     )
				ordersToThisElevatorChn.insert(receivedToNetworkOrder);
			else
				networkTid.send(receivedToNetworkOrder);
		}

		/* Only the network thread uses receive */
		receiveTimeout(
			msecs(1),
			(message_t orderFromNetwork)
		{
			debug writeln("messenger: received order from network");
			debug writeln(" >> ", orderFromNetwork);
			ordersToThisElevatorChn.insert(orderFromNetwork);

		},
			(PeerList list)
		{
			debug writelnBlue("messenger: received PeerList from network");
			updatePeerList(list);
			peerListChn.insert(list);
		},
			(Variant v)
		{
			debug writelnYellow("messenger: received Variant from network");
			debug writeln(">>> ", v);
		}
			);
	}
}




