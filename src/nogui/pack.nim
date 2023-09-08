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
# Glyph Icon ID Type
from data import GUIAtlasIcon

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

# ---------------------
# Icon Definition Macro
# ---------------------

func icon(item: NimNode): NimNode =
  let 
    value = newIntLitNode(mcIconsCount.value)
    ty = bindSym"GUIAtlasIcon"
    # Icon Name and Visibility
    op = item[0]
    name = item[1]
  # Add Name Prefix
  var id = ident("icon" & name.strVal)
  copyLineInfo(id, name)
  # Check if is Public
  if op.eqIdent("*="): 
    id = postfix(id, "*")
  else: expectIdent(op, ":=")
  # Create New Definition
  result = nnkConstDef.newTree(
    id, ty, nnkCommand.newTree(ty, value)
  )
  # Step Current Icon
  inc mcIconsCount

macro icons*(dir: string, size: int, list: untyped) =
  result = nnkConstSection.newTree()
  # Create data folder if not exists
  let
    iconsClear = mcIconsCount.value == 0
    iconsList = listPrepare(list, "icons.list", iconsClear)
    # Icon Subdir / Icon Pixel Size
    iconsSubdir = dir.strVal
    iconsSize = $size.intVal
  # Define Each Icon
  for item in list:
    expectKind(item, nnkInfix)
    let iconName = iconsSubdir / item[2].strVal
    listEntry(item, iconsList, iconName, iconsSize)
    # Add New Fresh Constant
    result.add icon(item)

template icons*(size: int, list: untyped) =
  icons("", size, list)
