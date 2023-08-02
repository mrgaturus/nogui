# -------------------
# SIMPLE LOGGER PROCS
# -------------------
from strutils import join

type
  LOGKind* = enum
    lvError
    lvWarning
    lvInfo    

proc log*(kind: LOGKind, x: varargs[string, `$`]) =
  const headers = [
    "\e[1;31m[ERROR]\e[00m ",
    "\e[1;33m[WARNING]\e[00m ",
    "\e[1;32m[INFO]\e[00m "
  ]
  # Show Log Message and it's data
  echo headers[ord kind], x.join(" ")

# -----------------------
# SIMPLE DEBUGER TEMPLATE
# -----------------------

template debug*(x: typed) =
  echo "\e[1;34m[DEBUG: ", typeof(x), "]\e[00m\n", x.repr
