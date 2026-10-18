#include "CProcess.h"
#include <libproc.h>
#include <sys/proc_info.h>
#include <sys/resource.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <time.h>

int lc_list_user_pids(int32_t *pids, int capacity) {
    if (!pids || capacity <= 0) return -EINVAL;
    int bytes = proc_listpids(PROC_UID_ONLY, getuid(), pids, capacity * sizeof(int32_t));
    if (bytes <= 0) return -(errno ? errno : EACCES);
    if (bytes >= capacity * sizeof(int32_t)) return -EOVERFLOW;
    return bytes / sizeof(int32_t);
}

int lc_read_process(int32_t pid, LCProcess *result) {
    if (!result || pid <= 0) return EINVAL;
    memset(result, 0, sizeof(*result));
    struct proc_bsdinfo info = {0};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != sizeof(info))
        return errno ? errno : ESRCH;
    if (proc_pidpath(pid, result->path, sizeof(result->path)) <= 0)
        return errno ? errno : EACCES;
    result->pid = pid;
    result->uid = info.pbi_uid;
    result->start_sec = info.pbi_start_tvsec;
    result->start_usec = info.pbi_start_tvusec;
    struct rusage_info_v2 usage = {0};
    if (proc_pid_rusage(pid, RUSAGE_INFO_V2, (rusage_info_t *)&usage) == 0) {
        result->metrics_available = 1;
        result->cpu_ns = usage.ri_user_time + usage.ri_system_time;
        result->footprint = usage.ri_phys_footprint;
    }
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    result->timestamp = ts.tv_sec + ts.tv_nsec / 1e9;
    // Detect replacement while reading the metrics.
    struct proc_bsdinfo after = {0};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &after, sizeof(after)) != sizeof(after))
        return ESRCH;
    if (after.pbi_start_tvsec != info.pbi_start_tvsec ||
        after.pbi_start_tvusec != info.pbi_start_tvusec || after.pbi_uid != info.pbi_uid)
        return ESTALE;
    return 0;
}

int lc_terminate_verified(const LCProcess *expected) {
    if (!expected || expected->pid <= 1 || expected->uid != getuid()) return EPERM;
    LCProcess fresh;
    int error = lc_read_process(expected->pid, &fresh);
    if (error) return error;
    if (fresh.uid != getuid() || fresh.uid != expected->uid ||
        fresh.start_sec != expected->start_sec || fresh.start_usec != expected->start_usec ||
        strcmp(fresh.path, expected->path) != 0) return ESTALE;
    // POSIX kill has no atomic identity argument; keep this final race window minimal.
    return kill(fresh.pid, SIGTERM) == 0 ? 0 : errno;
}
