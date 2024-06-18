import macros, macrocache
# Import Location Management
from std/compilesettings import 
  querySetting, SingleValueSetting
from os import parentDir, `/`
# Used for Execute a Command
when not defined(skiplist):
  from strutils import join
const
  mcPackCount = CacheCounter"nogui:pack"
  mcIconCount = CacheCounter"nogui:icon"
  mcCursorCount = CacheCounter"nogui:cursor"
# Import Icon Identifiers Type
from data import CTXIconID, CTXCursorID

# ---------------------------
# gorge Executor with Checker
# ---------------------------

func eorge(line: NimNode, args: openArray[string]) =
  when not defined(skiplist):
    let (output, code) = gorgeEx(args.join " ")
    # Check if is succesfully
    if code != 0:
      error(output, line)
  # Avoid Error
  discard

func listWrite(line: NimNode, cmd, key, value: string) =
  const path = querySetting(outDir)
  # Reset Pack Directory
  if mcPackCount.value == 0:
    eorge line, ["nopack reset", path]
  # Write Pack File Line to List
  let entry = ["\"", key, " : ", value, "\""].join()
  eorge line, ["nopack", cmd, path, entry]
  inc(mcPackCount)

# -----------------------
# Folder Definition Macro
# -----------------------

macro folders*(paths: untyped) =
  let pathModule = lineInfoObj(paths).filename.parentDir()
  # Copy Each Defined Folder
  for path in paths:
    expectKind(path, nnkInfix)
    let 
      op = path[0]
      mode = op.eqIdent(">>")
    # Path Names
    var src = path[1].strVal
    let dst = path[2].strVal
    # Check External Copy
    if mode: src = pathModule / src
    else: expectIdent(op, "->")
    # Write Path List Entry
    listWrite(path, "path", src, dst)

# --------------------
# Constant Symbol Node
# --------------------

func symbol(item, ty: NimNode, class: string, value: int): NimNode =
  let 
    value = newIntLitNode(value)
    # Cursor Name and Visibility
    op = item[0]
    name = item[1]
  # Add Name Prefix
  var id = ident(class & name.strVal)
  copyLineInfo(id, name)
  # Check if is Public
  if op.eqIdent("*="): 
    id = postfix(id, "*")
  else: expectIdent(op, ":=")
  # Create New Definition
  result = nnkConstDef.newTree(
    id, ty, nnkCommand.newTree(ty, value)
  )

# ---------------------
# Icon Definition Macro
# ---------------------

macro icons*(dir: string, size: int, list: untyped) =
  let
    ty = bindSym"CTXIconID"
    # Icon Subdir / Icon Pixel Size
    subdir = dir.strVal
    fit = $size.intVal
  # Create Icon ID Constant Section
  result = nnkConstSection.newTree()
  # Define Each Icon
  for item in list:
    expectKind(item, nnkInfix)
    let name = subdir / item[2].strVal
    listWrite(item, "icon", name, fit)
    # Add New Fresh Constant Symbol
    let count = mcIconCount.value
    result.add symbol(item, ty, "icon", count)
    inc(mcIconCount)

template icons*(size: int, list: untyped) =
  icons("", size, list)

# -----------------------
# Cursor Definition Macro
# -----------------------

macro cursors*(dir: string, size: int, list: untyped) =
  # Create data folder if not exists
  let
    ty = bindSym"CTXCursorID"
    # Cursor Subdir / Pixel Size
    subdir = dir.strVal
    fit = $size.intVal
  # Create Cursor ID Constant Section
  result = nnkConstSection.newTree()
  # Define Each Icon
  for item in list:
    expectKind(item, nnkInfix)
    # Lookup Cursor Data
    let info = item[2]
    expectKind(info, nnkCommand)
    # Lookup Hotspot Data
    let hot = info[1]
    expectLen(hot, 2)
    # Cursor Information
    let
      key = subdir / info[0].strVal
      hotspot = $hot[0].intVal & "," & $hot[1].intVal
      value = fit & " - " & hotspot
    # Add New Entry to File List
    listWrite(item, "cursor", key, value)
    # Add New Fresh Constant Symbol
    let count = mcCursorCount.value
    result.add symbol(item, ty, "cursor", count)
    inc(mcCursorCount)

template cursors*(size: int, list: untyped) =
  cursors("", size, list)
