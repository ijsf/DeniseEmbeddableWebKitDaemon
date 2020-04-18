#ifndef XPCService_hpp
#define XPCService_hpp

// WebKitGTK dependency
#include <EmbedBrowser/Browser.h>

#include <map>
#include <xpc/xpc.h>

class XPCService {
public:
    const char* MACH_SERVICE_NAME = "com.denise.daemon";

    XPCService();
    virtual ~XPCService();
    
private:
    void initialize();
    
private:
    xpc_connection_t m_connMachService;
    
    dispatch_source_t m_timer;
    
    struct PeerData {
        PeerData() : peer(nullptr), frameData(nullptr), frameSize(0) {};
        
        // Browser tab
        std::shared_ptr<WebKitEmbed::Browser::Tab> tab;
        
        // Connection
        xpc_connection_t peer;
        
        // Frame data
        void* frameData;
        size_t frameSize;
        uint frameWidth;
        uint frameHeight;
        uint frameStride;
    };
    std::map<pid_t, PeerData> m_peerMap;
};

#endif /* XPCService_hpp */
