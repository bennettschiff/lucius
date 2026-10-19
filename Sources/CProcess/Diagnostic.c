#include "CProcess.h"
#include <spawn.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>

int lc_spawn_diagnostic(const char *path, char *const argv[], int output_fd, int read_fd) {
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    int error = posix_spawn_file_actions_init(&actions);
    if (error) return -error;
    error = posix_spawnattr_init(&attributes);
    if (error) { posix_spawn_file_actions_destroy(&actions); return -error; }
    sigset_t empty, defaults;
    sigemptyset(&empty);
    sigfillset(&defaults);
    short flags = POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_CLOEXEC_DEFAULT;
    if (!(error = posix_spawnattr_setflags(&attributes, flags)) &&
        !(error = posix_spawnattr_setpgroup(&attributes, 0)) &&
        !(error = posix_spawnattr_setsigmask(&attributes, &empty)) &&
        !(error = posix_spawnattr_setsigdefault(&attributes, &defaults)) &&
        !(error = posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)) &&
        !(error = posix_spawn_file_actions_adddup2(&actions, output_fd, STDOUT_FILENO)) &&
        !(error = posix_spawn_file_actions_adddup2(&actions, output_fd, STDERR_FILENO)) &&
        !(error = posix_spawn_file_actions_addclose(&actions, output_fd)) &&
        !(error = posix_spawn_file_actions_addclose(&actions, read_fd))) {
        char *environment[] = {"PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL=C", "LANG=C", NULL};
        pid_t pid = 0;
        error = posix_spawn(&pid, path, &actions, &attributes, argv, environment);
        posix_spawnattr_destroy(&attributes);
        posix_spawn_file_actions_destroy(&actions);
        return error ? -error : pid;
    }
    posix_spawnattr_destroy(&attributes);
    posix_spawn_file_actions_destroy(&actions);
    return -error;
}
