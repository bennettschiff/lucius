#ifndef LUCIUS_PROCESS_H
#define LUCIUS_PROCESS_H
#include <stdint.h>
#include <sys/types.h>

typedef struct {
    int32_t pid;
    uint32_t uid;
    uint64_t start_sec;
    uint64_t start_usec;
    uint64_t cpu_ns;
    uint64_t footprint;
    double timestamp;
    int metrics_available;
    char path[4096];
} LCProcess;

// Fixed-capacity list; returns a negative errno on failure or truncation.
int lc_list_user_pids(int32_t *pids, int capacity);
int lc_read_process(int32_t pid, LCProcess *result);
// Revalidates the full identity and current user before SIGTERM. Never escalates.
int lc_terminate_verified(const LCProcess *expected);
#endif
