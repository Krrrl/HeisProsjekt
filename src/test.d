import core.stdc.stdio;
import core.thread;
import std.concurrency;

void foo()
{
    for (int i =1; i > 0; i++) {
    printf("foo");
    }
}
void bar()
{
    for (int i =1; i > 0; i++) {
    printf("\n");
    }
}


int  main()
{
//    int array[];
 //   array = 0;

    auto fiber = spawn(&foo);
    auto fiber2 = spawn(&bar);
    printf("Current process id %d\n", getpid());

    return 0;
}

