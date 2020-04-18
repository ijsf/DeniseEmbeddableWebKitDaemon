#include "XPCClient.h"

void* XPCClient::allocateMemoryRegion(const size_t size) {
    if (m_connMachService != nullptr) {
        if (shmOpen(size)) {
            // mmap region as shared memory
            void* data = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, m_fdShm, 0);
            
            // Clear contents
            memset(data, 0, size);
            
            // Communicate region to XPCService
            xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_value(msg, "shm", xpc_shmem_create(data, size));
            xpc_connection_send_message(m_connMachService, msg);
            
            // Return mmapped region
            return data;
        }
    }
    return nullptr;
}

void XPCClient::deallocateMemoryRegion(void* data, const size_t size) {
    munmap(data, size);
}
