#include "CProcess.h"
#include <IOKit/IOKitLib.h>
#include <string.h>
#include <math.h>

// Wire protocol layout cross-checked against exelban/stats (MIT); see
// THIRD-PARTY-NOTICES.md. Only READ_KEYINFO (9) and READ_BYTES (5) exist here.
typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } LCVersion;
typedef struct { uint16_t version, length; uint32_t cpu, gpu, memory; } LCLimits;
typedef struct { uint32_t size, type; uint8_t attributes; } LCKeyInfo;
typedef struct {
    uint32_t key;
    LCVersion version;
    LCLimits limits;
    LCKeyInfo info;
    uint8_t result, status, command;
    uint32_t data;
    uint8_t bytes[32];
} LCSMCMessage;
_Static_assert(sizeof(LCSMCMessage) == 80, "Unexpected SMC ABI");

static uint32_t fourcc(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24) | ((uint32_t)(uint8_t)s[1] << 16) |
           ((uint32_t)(uint8_t)s[2] << 8) | (uint8_t)s[3];
}
int lc_smc_open(uint32_t *connection) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return -1;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, connection);
    IOObjectRelease(service);
    return result;
}
void lc_smc_close(uint32_t connection) { if (connection) IOServiceClose(connection); }
int lc_smc_read(uint32_t connection, const char *key, double *value) {
    if (!connection || !key || strlen(key) != 4 || !value) return -1;
    LCSMCMessage in = {0}, out = {0};
    in.key = fourcc(key); in.command = 9;
    size_t size = sizeof(out);
    kern_return_t result = IOConnectCallStructMethod(connection, 2, &in, sizeof(in), &out, &size);
    if (result || out.result || size != sizeof(out) || out.info.size == 0 || out.info.size > 32) return -1;
    uint32_t type = out.info.type, bytes = out.info.size;
    in.info.size = bytes; in.command = 5;
    memset(&out, 0, sizeof(out)); size = sizeof(out);
    result = IOConnectCallStructMethod(connection, 2, &in, sizeof(in), &out, &size);
    if (result || out.result || size != sizeof(out)) return -1;
    if (type == fourcc("flt ") && bytes == 4) {
        float f; memcpy(&f, out.bytes, sizeof(f)); *value = f;
    } else if (type == fourcc("sp78") && bytes == 2) {
        *value = (int16_t)((out.bytes[0] << 8) | out.bytes[1]) / 256.0;
    } else if (type == fourcc("fpe2") && bytes == 2) {
        *value = ((out.bytes[0] << 8) | out.bytes[1]) / 4.0;
    } else if (type == fourcc("ui8 ") && bytes == 1) { *value = out.bytes[0];
    } else if (type == fourcc("ui16") && bytes == 2) { *value = (out.bytes[0] << 8) | out.bytes[1];
    } else { return -1; }
    return isfinite(*value) ? 0 : -1;
}
void lc_memory_fill(uint64_t *memory, uint32_t count, uint64_t pattern, int address_pattern) {
    volatile uint64_t *p = memory;
    for (uint32_t i = 0; i < count; ++i) p[i] = address_pattern ? pattern ^ ((uint64_t)i * 0x9E3779B97F4A7C15ULL) : pattern;
}
uint64_t lc_memory_check(const uint64_t *memory, uint32_t count, uint64_t pattern, int address_pattern, uint32_t *first) {
    const volatile uint64_t *p = memory;
    uint64_t errors = 0;
    for (uint32_t i = 0; i < count; ++i) {
        uint64_t expected = address_pattern ? pattern ^ ((uint64_t)i * 0x9E3779B97F4A7C15ULL) : pattern;
        if (p[i] != expected) { if (errors == 0 && first) *first = i; ++errors; }
    }
    return errors;
}

// Volatile accumulators require real arithmetic even in optimized builds.
uint64_t lc_cpu_integer_answer(void) {
    volatile uint64_t hash = 14695981039346656037ULL;
    for (uint32_t i = 0; i < 65536; ++i) hash = (hash ^ (i & 255)) * 1099511628211ULL;
    return hash;
}
double lc_cpu_float_answer(void) {
    volatile double sum = 0;
    for (uint32_t i = 1; i <= 4096; ++i) sum = sum + (double)i * 0.5;
    return sum;
}
