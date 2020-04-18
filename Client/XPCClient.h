#ifndef XPCClient_hpp
#define XPCClient_hpp

#include <string>

#include <xpc/xpc.h>

class XPCClient {
public:
    const char* MACH_SERVICE_NAME = "com.denise.daemon";
    const char* SHM_NAME = "denise";

    XPCClient() : m_frameData(nullptr), m_frameSize(0) {
    }
    
    virtual ~XPCClient() {
        // Close shared memory region
        shmClose();
    }
    
    bool connect() {
        // Create mach service (client)
        m_connMachService = xpc_connection_create_mach_service(MACH_SERVICE_NAME, NULL, 0);
        if (m_connMachService != nullptr) {
            // General event/message handler
            xpc_connection_set_event_handler(m_connMachService, ^(xpc_object_t event) {
                // ACHTUNG
                printf("Received message in generic event handler: %p\n", event);
                printf("%s\n", xpc_copy_description(event));
                
                if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) {
                    // frame
                    if (xpc_dictionary_get_value(event, "frame")) {
                        printf("frame\n");
                    }
                }
            });
            
            // Resume connection
            xpc_connection_resume(m_connMachService);
            
            return true;
        }
        return false;
    }
    
    /*** Browser ***/
    void initialize(const uint width, const uint height) {
        setSize(width, height);
    }
    void loadURL(const std::string& url) {
        if (m_connMachService) {
            // Communicate with XPCService
            xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
            {
                xpc_dictionary_set_string(msg, "loadURL", url.c_str());
            }
            xpc_object_t reply = xpc_connection_send_message_with_reply_sync(m_connMachService, msg);
        }
    }
    void setSize(const uint width, const uint height) {
        if (m_connMachService) {
            // ACHTUNG stride 4 (ARGB32)
            const uint stride = 4;
            const size_t frameSize = width * height * stride;
            
            void* frameData = allocateSharedMemory(frameSize);
            if (frameData) {
                // Communicate with XPCService
                xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
                {
                    xpc_object_t frame = xpc_dictionary_create(NULL, NULL, 0);
                    {
                        xpc_dictionary_set_uint64(frame, "width", (uint64_t)width);
                        xpc_dictionary_set_uint64(frame, "height", (uint64_t)height);
                        xpc_dictionary_set_uint64(frame, "stride", (uint64_t)stride);
                        xpc_dictionary_set_value(frame, "shm", xpc_shmem_create(frameData, frameSize));
                    }
                    xpc_dictionary_set_value(msg, "frame", frame);
                }
                // Exchange shared memory region with service,
                // sync with reply so that the old m_frame will no longer be used
                xpc_object_t reply = xpc_connection_send_message_with_reply_sync(m_connMachService, msg);
            }
            // Replace m_frame with currently shared memory region, deallocating any previous shared regions
            if (m_frameData) {
                deallocateSharedMemory(m_frameData, m_frameSize);
            }
            m_frameData = frameData;
            m_frameSize = frameSize;
        }
    }

private:
    void* allocateSharedMemory(const size_t size) {
        if (shmOpen(size)) {
            // mmap region as shared memory
            void* data = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, m_fdShm, 0);
            
            // Clear contents
            memset(data, 0, size);
            
            // Return mmapped region
            return data;
        }
        return nullptr;
    }
    void deallocateSharedMemory(void* data, const size_t size) {
        munmap(data, size);
    }
    bool shmOpen(const size_t size) {
        // Unlink shm device
        shm_unlink(SHM_NAME);
        // Open shm device
        m_fdShm = shm_open(SHM_NAME, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
        if (m_fdShm >= 0) {
            // Set shared memory size
            ftruncate(m_fdShm, size);
            return true;
        }
        return false;
    };
    bool shmClose() {
        if (m_fdShm >= 0) {
            shm_unlink(SHM_NAME);
            return true;
        }
        return false;
    };
    
private:
    xpc_connection_t m_connMachService;
    int m_fdShm;

    // Shared memory region for frame buffer
    void* m_frameData;
    size_t m_frameSize;
};

#endif /* XPCClient_hpp */
