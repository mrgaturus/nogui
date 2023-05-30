# -------------------
# SIMPLE LOGGER PROCS
# -------------------

type
  LOGKind* = enum
    lvInfo
    lvError
    lvWarning

proc log*(kind: LOGKind, x: varargs[string, `$`]) =
  const headers = [
    "\e[1;31m[ERROR]\e[00m ",
    "\e[1;33m[WARNING]\e[00m ",
    "\e[1;32m[INFO]\e[00m "
  ]
  
  # Print Colored Header
  write(stdout, headers[ord kind])
  # Print Passed Data
  for args in x:
    write(stdout, args)
  write(stdout, "\n")

# -----------------------
# SIMPLE DEBUGER TEMPLATE
# -----------------------

template debug*(x: typed) =
  echo "\e[1;34m[DEBUG: ", typeof(x), "]\e[00m\n", x.repr
