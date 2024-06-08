#include "native.h"
#include <stdio.h>
#include <stdarg.h>

static void log_base(const char* base, const char* format, va_list args) {
  // Print Log Format
  printf("%s", base);
  vprintf(format, args);
  // Line Jump
  putchar('\n');
}

// --------------------
// Native Simple Logger
// --------------------

void log_error(const char* format, ... ) {
  va_list args;
  va_start(args, format);
  // Print With Tagged Red Error
  log_base("\e[1;31m[ERROR]\e[00m ", format, args);
  va_end(args);
}

void log_warning(const char* format, ... ) {
  va_list args;
  va_start(args, format);
  // Print With Tagged Yellow Warning
  log_base("\e[1;33m[WARNING]\e[00m ", format, args);
  va_end(args);
}

void log_info(const char* format, ... ) {
  va_list args;
  va_start(args, format);
  // Print With Tagged Blue Info
  log_base("\e[1;32m[INFO]\e[00m ", format, args);
  va_end(args);
}
