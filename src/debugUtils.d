import std.stdio;

void writelnYellow(string text)
{
    writeln("\033[33m", text, "\033[0m");
}

void writelnRed(string text)
{
    writeln("\033[31m", text, "\033[0m");
}

void writelnGreen(string text)
{
    writeln("\033[32m", text, "\033[0m");
}
