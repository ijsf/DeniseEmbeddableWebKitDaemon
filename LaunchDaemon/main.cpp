#include <stdio.h>
#include <dispatch/dispatch.h>

#include "XPCService.h"

int main(int argc, char *argv[]) {
    fprintf(stderr, "com.denise.daemon start\n");
    
    // Create XPC service
    XPCService service;
    
    // Main dispatch routine
    dispatch_main();

    fprintf(stderr, "com.denise.daemon exit\n");
}

