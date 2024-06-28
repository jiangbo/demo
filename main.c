#define WIN32_LEAN_AND_MEAN // just say no to MFC

#include <windows.h>  // include all the windows headers
#include <windowsx.h> // include useful macros
#include <mmsystem.h> // very important and include WINMM.LIB too!
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char const *argv[])
{
    SND_ASYNC | SND_LOOP | SND_PURGE;
    int length = sizeof(unsigned long);
    // print length
    RGB()
    printf("length: %d\n", length);
    return 0;
}
