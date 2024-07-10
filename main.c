// Example1_1
// main.cpp
// Ernest Pazera
// 04OCT2001
// TGO-01-C
// Libs: d3d8.lib

#include <windows.h> //include windows stuff
#include <stdio.h>   //standard input/output
#include "D3D8.h"    //include direct3d8 stuff

// constants
// window class name
const char *WINDOWCLASS = "3D42DGP";
// window title
const char *WINDOWTITLE = "Example 1.1 (TGO-01-C): Creating and Destroying an IDirect3D8 object";

// globals
// instance handle
HINSTANCE g_hInstance = NULL;
// window handle
HWND g_hWnd = NULL;
// IDirect3D8 pointer
IDirect3D8 *g_pd3d = NULL;

// function prototypes
// winmain
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd);
// window procedure
LRESULT CALLBACK TheWindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
// initialization
void Prog_Init();
// clean up
void Prog_Done();

// window procedure
LRESULT CALLBACK TheWindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    // which message did we get?
    switch (uMsg)
    {
    case WM_DESTROY: // window being destroyed
    {
        // quit

        PostQuitMessage(0);

        // message handled, return 0

        return (0);
    }
    break;
    default: // all other messages, send to default handler
        return (DefWindowProc(hWnd, uMsg, wParam, lParam));
    }
}

// winmain
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd)
{
    // grab instance handle
    g_hInstance = hInstance;

    // redirect stderr and stdout output
    freopen("stderr.txt", "w", stderr);
    freopen("stdout.txt", "w", stdout);

    // fill in window class
    WNDCLASSEX wc;
    wc.cbClsExtra = 0;                                          // no extra class information
    wc.cbSize = sizeof(WNDCLASSEX);                             // size of structure
    wc.cbWndExtra = 0;                                          // no extra window information
    wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);     // black brush
    wc.hCursor = NULL;                                          // no cursor
    wc.hIcon = NULL;                                            // no icon
    wc.hIconSm = NULL;                                          // no small icon
    wc.hInstance = g_hInstance;                                 // instance handle
    wc.lpfnWndProc = TheWindowProc;                             // window procedure
    wc.lpszClassName = WINDOWCLASS;                             // name of class
    wc.lpszMenuName = NULL;                                     // no menu
    wc.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS | CS_OWNDC; // class styles

    // register window class
    RegisterClassEx(&wc);

    // create window
    g_hWnd = CreateWindowEx(0, WINDOWCLASS, WINDOWTITLE, WS_OVERLAPPEDWINDOW, 0, 0, 320, 240, NULL, NULL, g_hInstance, NULL);

    // show the window
    ShowWindow(g_hWnd, nShowCmd);

    // initialization
    Prog_Init();

    MSG msg;
    // message pump
    for (;;)
    {
        // check for a message
        if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
        {
            // message exists

            // check for quit message
            if (msg.message == WM_QUIT)
                break;

            // translate the message
            TranslateMessage(&msg);

            // dispatch the message
            DispatchMessage(&msg);
        }
    }

    // clean up
    Prog_Done();

    // exit
    return (msg.wParam);
}

// initialization
void Prog_Init()
{
    // create the IDirect3D8 object
    g_pd3d = Direct3DCreate8(D3D_SDK_VERSION);

    // error check
    if (g_pd3d)
    {
        // success
        fprintf(stdout, "IDirect3D8 object created successfully.\n");
    }
    else
    {
        // failure
        fprintf(stderr, "IDirect3D8 object creation failed.\n");
    }
}

// clean up
void Prog_Done()
{
    // safe release of IDirect3D8 object
    if (g_pd3d)
    {
        // release
        g_pd3d->Release();

        // set to null
        g_pd3d = NULL;

        // report action
        fprintf(stdout, "IDirect3D8 object released.\n");
    }
}
