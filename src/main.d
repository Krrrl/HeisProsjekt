import std.stdio,
       std.concurrency;

import keeperOfSets,
       messenger;

void main()
{
    Tid keeperOfSetsTID = spawn(&keeperOfSetsThread, thisTid());

    while(1)
    {
        receive(
                (int a)
                {
                writeln("Tall: ", a, " heh.");
                }
            );
    }
}
