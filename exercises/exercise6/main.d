

import  core.thread,
        core.time,
        std.conv,
        std.concurrency,
        std.random,
        std.stdio;


void incThread(int number)
{
	bool iamPrimary = false;

	int myNumber = number;
	Tid backupTID;

	while(!iamPrimary)
	{
		try
		{
			receive(
				(int currentNumber)
				{
					myNumber = currentNumber;
				}
				);
		}

		catch (Exception e)
		{
			e.writeln;
			iamPrimary = true;
		}
	}
	backupTID = spawn(&incThread, myNumber);
	writeln("restart!");
	auto quit = false;
	while(!quit)
	{
		writeln("primary:", myNumber);
		backupTID.send(myNumber);
		myNumber++;
		Thread.sleep(1.seconds);
		quit = dice(20, 80) == 0;
	}


	//check for backup, if no create backup
	//print incrementing number
	//send printed number to backup thread


}



void main()
{
	auto primeTid = spawn(&incThread, 0);
//	Thread.getThis.isDaemon = true;
}



// Ka om vi drep den med ctrl+c? da overleve jo ikke denne likevel..??
// Kanskje den må være main-tråden, likevel?