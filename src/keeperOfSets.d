import std.stdio,
       std.concurrency;

import messenger;


void keeperOfSetsThread(Tid spawnerTid)
{
    for (int i = 0; i < 100; i++)
    {
        send(spawnerTid, i);
    }
    /*receive
    (
        (delegateOrder a)
        {
        
        },
        (confirmOrder a)
        {
        },
        (expediteOrder a)
        {
        }
     );
     */
}


