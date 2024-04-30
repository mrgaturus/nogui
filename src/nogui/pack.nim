import macros, macrocache
# Import Location Management
from std/compilesettings import 
  querySetting, SingleValueSetting
from os import parentDir, `/`
# Used for Execute a Command
when not defined(skiplist):
  from strutils import join
# Packed Counters File
const
  mcPathsCount = CacheCounter"nogui:path"
  mcIconsCount = CacheCounter"nogui:icon"
  mcCursorsCount = CacheCounter"nogui:cursor"
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

# ----------------------
# Folder Preparing Procs
# ----------------------

func listPrepare(line: NimNode, name: string, clear: bool): string =
  const path = querySetting(outDir) / "pack"
  # Create Pack Folder if not exists
  eorge line, ["test -d", path, "||", "mkdir", path]
  # Pack List Location
  result = path / name
  if clear: # Remove File
    eorge line, ["rm -f", result]

func listEntry(line: NimNode, name, key, value: string) =
  # Write Line File Entry
  eorge line, ["echo", key, ":", value, ">>", name]

# -----------------------
# Folder Definition Macro
# -----------------------

macro folders*(paths: untyped) =
  # Create data folder if not exists
  let 
    pathClear = mcPathsCount.value == 0
    pathList = listPrepare(paths, "paths.list", pathClear)
    pathModule = lineInfoObj(paths).filename.parentDir()
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
    let pathName = src & "-:-" & dst
    listEntry(path, pathList, pathName, $ int mode)
    # Step Current Folder
    inc mcPathsCount

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
  result = nnkConstSection.newTree()
  let ty = bindSym"CTXIconID"
  # Create data folder if not exists
  let
    clear = mcIconsCount.value == 0
    entries = listPrepare(list, "icons.list", clear)
    # Icon Subdir / Icon Pixel Size
    subdir = dir.strVal
    fit = $size.intVal
  # Define Each Icon
  for item in list:
    expectKind(item, nnkInfix)
    let name = subdir / item[2].strVal
    listEntry(item, entries, name, fit)
    # Add New Fresh Constant Symbol
    let count = mcIconsCount.value
    result.add symbol(item, ty, "icon", count)
    inc(mcIconsCount)

template icons*(size: int, list: untyped) =
  icons("", size, list)

# -----------------------
# Cursor Definition Macro
# -----------------------

macro cursors*(dir: string, size: int, list: untyped) =
  result = nnkConstSection.newTree()
  let ty = bindSym"CTXCursorID"
  # Create data folder if not exists
  let
    clear = mcCursorsCount.value == 0
    entries = listPrepare(list, "cursors.list", clear)
    # Cursor Subdir / Pixel Size
    subdir = dir.strVal
    fit = $size.intVal
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
    listEntry(item, entries, key, value)
    # Add New Fresh Constant Symbol
    let count = mcCursorsCount.value
    result.add symbol(item, ty, "cursor", count)
    inc(mcCursorsCount)

template cursors*(size: int, list: untyped) =
  cursors("", size, list)
