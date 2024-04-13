#include "native.h"
// Includes POSIX Clock on C11
#define _POSIX_C_SOURCE 199309L
#include <time.h>

nogui_time_t nogui_time_now() {
  struct timespec ts;
  unsigned long long time;

  // Calculate Current POSIX Monotime
  if (clock_gettime(CLOCK_MONOTONIC, &ts) < 0)
    log_warning("bad tick calculated");
  // Calculate Time on Nanoseconds
  time = ts.tv_sec * 1000000000 + ts.tv_nsec;

  return time;
}

nogui_time_t nogui_time_ms(int ms) {
  // Convert time to Nanoseconds
  return (nogui_time_t) ms * 1000000;
}

void nogui_time_sleep(nogui_time_t time) {
  if (time <= 0)
    return;

  struct timespec ts;
  ts.tv_sec = time / 1000000000;
  ts.tv_nsec = time % 1000000000;

  // Sleep using nanosleep
  nanosleep(&ts, NULL);
}
