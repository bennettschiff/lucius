// Bounded, read-only measurement of one process using Lucius's own metrics bridge.
#include "CProcess.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    int pid = atoi(argv[1]);
    int seconds = atoi(argv[2]);
    if (pid <= 1 || seconds < 1 || seconds > 60) return 2;
    LCProcess first, last;
    if (lc_read_process(pid, &first)) return 3;
    uint64_t peak = first.footprint;
    printf("second,cpu_one_core_percent,physical_footprint_mb\n");
    last = first;
    for (int i = 1; i <= seconds; i++) {
        sleep(1);
        LCProcess now;
        if (lc_read_process(pid, &now)) return 4;
        if (now.start_sec != first.start_sec || now.start_usec != first.start_usec) return 5;
        double cpu = (now.cpu_ns - last.cpu_ns) / 1e9 / (now.timestamp - last.timestamp) * 100;
        printf("%d,%.3f,%.2f\n", i, cpu, now.footprint / 1048576.0);
        fflush(stdout);
        if (now.footprint > peak) peak = now.footprint;
        last = now;
    }
    printf("average_cpu=%.3f peak_footprint_mb=%.2f\n", (last.cpu_ns - first.cpu_ns) / 1e9 / (last.timestamp - first.timestamp) * 100, peak / 1048576.0);
    return 0;
}
