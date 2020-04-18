#include <AppKit/AppKit.h>

#include "XPCService.h"

// Browser instance - ACHTUNG global hack
WebKitEmbed::Browser browser;

//////////////////////////////////////////////////////////////////////////////
//
// Thread helper class
//
// This Objective-C class implements a NSThread on which functions can be scheduled,
// equal to the GCD dispatch_async behaviour when using the main queue.
//
// Our WebKitEmbed requires certain functions to be called from ONE AND ONLY ONE THREAD
// due to its use of GTK+. Unfortunately, GCD does not guarantee that whenever
// dispatch_async is used on the main queue, the thread in which it is executed
// is always the same.
//
// This is a common misconception: a main queue is NOT a main thread.
//
// As a solution, this class can be used instead to guarantee execution on the same thread.
//
typedef void(^TCVoidBlock)(void);

@interface ThreadHelper : NSObject
// Schedules a block to run on this thread
- (void)schedule:(TCVoidBlock)block waitUntilDone:(BOOL)wait;
@end

@implementation ThreadHelper
    NSThread* mThread;

- (void)threadLoop {
    bool shouldRun = true;

    // Get the run loop
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    
    // Loop that takes care of the run loop (not a busy loop)
    while (shouldRun && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
}

- (void)performBlock:(TCVoidBlock)block {
    block();
}

- (void)start {
    // Create the thread
    mThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadLoop) object:nil];
    [mThread start];
}

// Schedules a block to run on this thread
- (void)schedule:(TCVoidBlock)block waitUntilDone:(BOOL)wait {
    [self performSelector:@selector(performBlock:) onThread:mThread withObject:[block copy] waitUntilDone:wait];
}
@end

// Instance - ACHTUNG global hack
ThreadHelper* g_mainThread;

//////////////////////////////////////////////////////////////////////////////

XPCService::XPCService() {
    fprintf(stderr, "XPCService::XPCService\n");

    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    
    // Main thread helper
    g_mainThread = [ThreadHelper alloc];
    [g_mainThread start];

    // Initialize
    initialize();
}

XPCService::~XPCService() {
}

void XPCService::initialize() {
    // Initialize browser
    fprintf(stderr, "Initializing browser\n");
    [g_mainThread schedule:^{
        // THREAD-MAIN
        browser.initialize();
    } waitUntilDone:TRUE];
    
    // Create mach service
    fprintf(stderr, "Initializing XPC service\n");
    m_connMachService = xpc_connection_create_mach_service(MACH_SERVICE_NAME, NULL, XPC_CONNECTION_MACH_SERVICE_LISTENER);
    if (m_connMachService) {
        // Handle incoming connections
        xpc_connection_set_event_handler(m_connMachService, ^(xpc_object_t peer_) {
            if (xpc_get_type(peer_) == XPC_TYPE_ERROR)
            {
                fprintf(stderr, "Error while creating XPC service: %s\n", xpc_dictionary_get_string(peer_, XPC_ERROR_KEY_DESCRIPTION));
                xpc_connection_cancel(m_connMachService);
                return;
            }
            xpc_connection_t peer = (xpc_connection_t)peer_;
            
            // Get unique identifier for this peer
            const pid_t pid = xpc_connection_get_pid(peer);
            
            // Look up peer data (will create new instance if it does not exist)
            PeerData& peerData = m_peerMap[pid];
            
            // If this is a new peer, initialize all values
            if (peerData.peer == nullptr) {
                fprintf(stderr, "new peer connection %llu %llu\n", (uint64_t)pid, (uint64_t)peer);

                // Create browser instance
                peerData.tab = browser.createTab();
                
                // Set browser callbacks
                peerData.tab->setCallbackDeniseLoadProduct([this](const Denise::Wrapper::ProductType productType, const std::string productId, const std::string productLoadData) {
                    xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                    {
                        xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
                        {
                            xpc_dictionary_set_uint64(dict, "productType", (uint)productType);
                            xpc_dictionary_set_string(dict, "productId", productId.c_str());
                            xpc_dictionary_set_string(dict, "productLoadData", productLoadData.c_str());
                        }
                        xpc_dictionary_set_value(res, "deniseLoadProduct", dict);
                    }
                    // Send to all peers
                    for(auto it = m_peerMap.begin(); it != m_peerMap.end(); ++it) {
                        xpc_connection_send_message(it->second.peer, res);
                    }
                });
                peerData.tab->setCallbackDeniseSetOverlay([this](const bool visible) {
                    xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                    {
                        xpc_dictionary_set_bool(res, "deniseSetOverlay", visible);
                    }
                    // Send to all peers
                    for(auto it = m_peerMap.begin(); it != m_peerMap.end(); ++it) {
                        xpc_connection_send_message(it->second.peer, res);
                    }
                });
                peerData.tab->setCallbackDeniseSetHeader([this](const bool visible) {
                    xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                    {
                        xpc_dictionary_set_bool(res, "deniseSetHeader", visible);
                    }
                    // Send to all peers
                    for(auto it = m_peerMap.begin(); it != m_peerMap.end(); ++it) {
                        xpc_connection_send_message(it->second.peer, res);
                    }
                });
                peerData.tab->setCallbackDeniseAppNotificationSet([this]() {
                    xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                    {
                        xpc_dictionary_set_bool(res, "deniseAppNotificationSet", true);
                    }
                    // Send to all peers
                    for(auto it = m_peerMap.begin(); it != m_peerMap.end(); ++it) {
                        xpc_connection_send_message(it->second.peer, res);
                    }
                });
                peerData.tab->setCallbackDeniseAppNotificationReset([this]() {
                    xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                    {
                        xpc_dictionary_set_bool(res, "deniseAppNotificationReset", true);
                    }
                    // Send to all peers
                    for(auto it = m_peerMap.begin(); it != m_peerMap.end(); ++it) {
                        xpc_connection_send_message(it->second.peer, res);
                    }
                });

                peerData.tab->setCallbackLoadFailed([this, pid](const WebKitEmbed::Browser::LoadEvent loadEvent, const std::string URI, const WebKitEmbed::Browser::Error error) -> bool {
                    // THREAD-BROWSER
                    // Check for peer validity
                    auto it = m_peerMap.find(pid);
                    if (it != m_peerMap.end()) {
                        PeerData& peerData = it->second;
                        
                        // Send signal
                        xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                        {
                            xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
                            {
                                xpc_dictionary_set_uint64(dict, "event", (uint64)loadEvent);
                                xpc_dictionary_set_string(dict, "uri", URI.c_str());
                                xpc_dictionary_set_uint64(dict, "errorCode", (uint64)error.code);
                                xpc_dictionary_set_string(dict, "errorMessage", error.message.c_str());
                            }
                            xpc_dictionary_set_value(res, "loadFailed", dict);
                        }
                        xpc_connection_send_message(peerData.peer, res);
                    }
                    return true;
                });
                peerData.tab->setCallbackIsLoading([this, pid](const bool loading) {
                    // THREAD-BROWSER
                    // Check for peer validity
                    auto it = m_peerMap.find(pid);
                    if (it != m_peerMap.end()) {
                        PeerData& peerData = it->second;

                        // Send signal
                        xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                        xpc_dictionary_set_bool(res, "isLoading", loading);
                        xpc_connection_send_message(peerData.peer, res);
                    }
                });
                peerData.tab->setCallbackPaint([this, pid](const uint8_t *srcData, const WebKitEmbed::Browser::Point &dstPoint, const WebKitEmbed::Browser::Rect &srcSize, const WebKitEmbed::Browser::Rect &srcRect) {
                    // THREAD-BROWSER
                    // Check for peer validity
                    auto it = m_peerMap.find(pid);
                    if (it != m_peerMap.end()) {
                        PeerData& peerData = it->second;
                        bool result = false;
                        
                        // Update paint buffer
                        {
                            const uint32_t imageWidth = peerData.frameWidth;
                            const uint32_t imageHeight = peerData.frameHeight;
                            const uint8_t imageStride = peerData.frameStride;
                            
                            // Perform a bounds check
                            if (!((dstPoint.x + srcRect.width) <= imageWidth && (dstPoint.y + srcRect.height) <= imageHeight)) {
                                // Translated rectangle does not fit into our image
                            }
                            {
                                // Translated rectangle fits into our image
                                
                                // Check if this is a full update, in which case optimized memcpy can be used
                                if(dstPoint.x == 0 && dstPoint.y == 0 && srcRect.width == imageWidth && srcRect.height == imageHeight) {
                                    if(srcData) {
                                        memcpy(peerData.frameData, srcData, imageWidth * imageHeight * imageStride);
                                    }
                                    else {
                                        memset(peerData.frameData, 0, imageWidth * imageHeight * imageStride);
                                    }
                                }
                                else {
                                    // Region update (need to slice a rectangle out of data)
                                    // ACHTUNG performance
                                    
                                    const unsigned int srcTotalRowLength = srcSize.width * imageStride;
                                    const unsigned int dstTotalRowLength = imageWidth * imageStride;
                                    
                                    // Bounds checked variables
                                    const unsigned int dstX = (dstPoint.x < imageWidth) ? dstPoint.x : imageWidth;
                                    const unsigned int dstY = (dstPoint.y < imageHeight) ? dstPoint.y : imageHeight;
                                    const unsigned int copyWidth = ((dstX + srcRect.width) < imageWidth) ? srcRect.width : imageWidth - dstX;
                                    const unsigned int copyHeight = ((dstY + srcRect.height) < imageHeight) ? srcRect.height : imageHeight - dstY;
                                    const unsigned int bytesPerRow = copyWidth * imageStride;
                                    const unsigned int rows = copyHeight;
                                    
                                    unsigned int srcOffset = ((srcRect.y * srcSize.width) + (srcRect.x)) * imageStride;
                                    unsigned int dstOffset = ((dstY * imageWidth) + (dstX)) * imageStride;
                                    
                                    if (rows > 0 && bytesPerRow > 0) {
                                        for(uint16_t y = 0; y < rows; ++y) {
                                            if(srcData) {
                                                memcpy(((uint8_t*)peerData.frameData) + dstOffset, srcData + srcOffset, bytesPerRow);
                                            } else {
                                                memset(((uint8_t*)peerData.frameData) + dstOffset, 0, bytesPerRow);
                                            }
                                            srcOffset += srcTotalRowLength;
                                            dstOffset += dstTotalRowLength;
                                        }
                                    }
                                }
                                result = true;
                            }
                        }
                        // Send signal
                        xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                        xpc_dictionary_set_bool(res, "frame", result);
                        xpc_connection_send_message(peerData.peer, res);
                    }
                });
            }
            else {
                fprintf(stderr, "existing peer connection %llu %llu\n", (uint64_t)pid, (uint64_t)peer);
            }

            // Save current working peer connection
            // ACHTUNG: hack!
            peerData.peer = peer;

            // Handle messages
            xpc_connection_set_event_handler(peer, ^(xpc_object_t event) {
                if (event == XPC_ERROR_CONNECTION_INVALID) {
                    printf("Connection closed by remote end\n");
                    return;
                }
                
                if (xpc_get_type(event) != XPC_TYPE_DICTIONARY) {
                    printf("Received something else than a dictionary!\n");
                    return;
                }
                
                printf("Message received: %p\n", event);
                printf("%s\n", xpc_copy_description(event));

                // Create response object
                xpc_object_t res = xpc_dictionary_create(NULL, NULL, 0);
                
                // loadURL
                if (xpc_dictionary_get_value(event, "loadURL")) {
                    [g_mainThread schedule:^{
                        // THREAD-MAIN
                        fprintf(stderr, "loadURL\n");
                        peerData.tab->loadURL(xpc_dictionary_get_string(event, "loadURL"));
                     } waitUntilDone:TRUE];
                    xpc_dictionary_set_bool(res, "loadURL", true);
                }
                
                // mouseMove
                {
                    xpc_object_t dict = xpc_dictionary_get_value(event, "mouseMove");
                    if (dict && xpc_get_type(dict) == XPC_TYPE_DICTIONARY) {
                        const uint x = (uint)xpc_dictionary_get_uint64(dict, "x");
                        const uint y = (uint)xpc_dictionary_get_uint64(dict, "y");
                        const WebKitEmbed::Browser::ModifierKeys mods = (WebKitEmbed::Browser::ModifierKeys)xpc_dictionary_get_uint64(dict, "mods");
                        [g_mainThread schedule:^{
                            // THREAD-MAIN
                            peerData.tab->mouseMove(x, y, mods);
                         } waitUntilDone:TRUE];
                        xpc_dictionary_set_bool(res, "mouseMove", true);
                    }
                }
                
                // mouseDown
                {
                    xpc_object_t dict = xpc_dictionary_get_value(event, "mouseDown");
                    if (dict && xpc_get_type(dict) == XPC_TYPE_DICTIONARY) {
                        const uint x = (uint)xpc_dictionary_get_uint64(dict, "x");
                        const uint y = (uint)xpc_dictionary_get_uint64(dict, "y");
                        const WebKitEmbed::Browser::ModifierKeys mods = (WebKitEmbed::Browser::ModifierKeys)xpc_dictionary_get_uint64(dict, "mods");
                        [g_mainThread schedule:^{
                            // THREAD-MAIN
                            peerData.tab->mouseDown(x, y, mods);
                         } waitUntilDone:TRUE];
                        xpc_dictionary_set_bool(res, "mouseDown", true);
                    }
                }

                // mouseUp
                {
                    xpc_object_t dict = xpc_dictionary_get_value(event, "mouseUp");
                    if (dict && xpc_get_type(dict) == XPC_TYPE_DICTIONARY) {
                        const uint x = (uint)xpc_dictionary_get_uint64(dict, "x");
                        const uint y = (uint)xpc_dictionary_get_uint64(dict, "y");
                        const WebKitEmbed::Browser::ModifierKeys mods = (WebKitEmbed::Browser::ModifierKeys)xpc_dictionary_get_uint64(dict, "mods");
                        [g_mainThread schedule:^{
                            // THREAD-MAIN
                            peerData.tab->mouseUp(x, y, mods);
                         } waitUntilDone:TRUE];
                        xpc_dictionary_set_bool(res, "mouseUp", true);
                    }
                }

                // keyPressed
                {
                    xpc_object_t dict = xpc_dictionary_get_value(event, "keyPress");
                    if (dict && xpc_get_type(dict) == XPC_TYPE_DICTIONARY) {
                        const uint keys = (uint)xpc_dictionary_get_uint64(dict, "keys");
                        const WebKitEmbed::Browser::ModifierKeys mods = (WebKitEmbed::Browser::ModifierKeys)xpc_dictionary_get_uint64(dict, "mods");
                        [g_mainThread schedule:^{
                            // THREAD-MAIN
                            fprintf(stderr, "keyPress %u %u\n", keys, mods);
                            peerData.tab->keyPress(keys, mods);
                         } waitUntilDone:TRUE];
                        xpc_dictionary_set_bool(res, "keyPressed", true);
                    }
                }

                // frame
                {
                    xpc_object_t frame = xpc_dictionary_get_value(event, "frame");
                    if (frame && xpc_get_type(frame) == XPC_TYPE_DICTIONARY) {
                        bool result = false;
                        
                        if (xpc_dictionary_get_value(frame, "shm")) {
                            // Map memory
                            // Validate and calculate frame dimensions
                            peerData.frameWidth = (uint)xpc_dictionary_get_uint64(frame, "width");
                            peerData.frameHeight = (uint)xpc_dictionary_get_uint64(frame, "height");
                            peerData.frameStride = (uint)xpc_dictionary_get_uint64(frame, "stride");
                            peerData.frameSize = peerData.frameWidth * peerData.frameHeight * peerData.frameStride;
                            if (peerData.frameSize) {
                                fprintf(stderr, "XPC frame map (width=%u height=%u stride=%u)\n",
                                        peerData.frameWidth,
                                        peerData.frameHeight,
                                        peerData.frameStride);
                                peerData.frameData = nullptr;
                                if (xpc_shmem_map(xpc_dictionary_get_value(frame, "shm"), &peerData.frameData)) {
                                    // Client's shared memory has been mapped into this process
                                    result = true;
                                    
                                    // Ensure tab is initialized and its size is set appropriately
                                    [g_mainThread schedule:^{
                                         // THREAD-MAIN
                                         if (!peerData.tab->isInitialized()) {
                                             fprintf(stderr, "initialize\n");
                                             peerData.tab->initialize(peerData.frameWidth, peerData.frameHeight);
                                         }
                                         else {
                                             fprintf(stderr, "setSize\n");
                                             peerData.tab->setSize(peerData.frameWidth, peerData.frameHeight);
                                         }
                                     } waitUntilDone:TRUE];
                                }
                            }
                        }
                        else {
                            // Unmap memory
                            munmap(peerData.frameData, peerData.frameSize);
                            peerData.frameData = nullptr;
                        }
                        xpc_dictionary_set_bool(res, "frame", result);
                    }
                }
                
                // Send response
                xpc_connection_send_message(peer, res);
            });
            
            xpc_connection_resume(peer);
        });
        xpc_connection_resume(m_connMachService);
    }
}

