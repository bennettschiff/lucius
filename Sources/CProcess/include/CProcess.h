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
// Launch a diagnostic command in a new process group. Returns PID or -errno.
int lc_spawn_diagnostic(const char *path, char *const argv[], int output_fd, int read_fd);
// Read-only SMC adapter. No write command or fan-control operation is exposed.
int lc_smc_open(uint32_t *connection);
void lc_smc_close(uint32_t connection);
int lc_smc_read(uint32_t connection, const char *key, double *value);
// Volatile memory operations prevent optimized builds from eliding RAM reads.
void lc_memory_fill(uint64_t *memory, uint32_t count, uint64_t pattern, int address_pattern);
uint64_t lc_memory_check(const uint64_t *memory, uint32_t count, uint64_t pattern, int address_pattern, uint32_t *first);
uint64_t lc_cpu_integer_answer(void);
double lc_cpu_float_answer(void);

#endif
