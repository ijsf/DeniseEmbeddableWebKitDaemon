#include <stdio.h>
#include <stdlib.h>
#include "XPCClient.h"

int main(int argc, char *argv[])
{
    // Create XPCClient and connect
    XPCClient client;
    client.connect();
    
    // Initialize browser
    client.initialize(640, 480);
    client.loadURL("https://www.xkcd.com");

    // Main dispatch routine
    dispatch_main();
}

