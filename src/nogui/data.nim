import macros, macrocache
# Import Location Management
from std/compilesettings import 
  querySetting, SingleValueSetting
from os import parentDir, `/`
# Used for Execute a Command
when not defined(skipdata):
  from strutils import join

type GUIRasterIcon* = distinct int32
const mcIconsCount = CacheCounter"nogui:icon"

# ---------------------------
# gorge Executor with Checker
# ---------------------------

func eorge(line: NimNode, args: openArray[string]) =
  when not defined(skipdata):
    let (output, code) = gorgeEx(args.join " ")
    # Check if is succesfully
    if code != 0:
      error(output, line)
  # Avoid Error
  discard

# ----------------------
# Folder Preparing Procs
# ----------------------

func prepareFolder(line: NimNode, name: string): string =
  result = querySetting(outDir) / name
  # Create Data Folder if not exists
  eorge line, ["test -d", result, "||", "mkdir", result]

func prepareIcons(line: NimNode): string =
  result = prepareFolder(line, "icons")
  # Reset icon list if exists
  if mcIconsCount.value == 0:
    let file = result / "icons.list"
    eorge line, ["rm -f", file]

# -----------------------
# Folder Definition Macro
# -----------------------

macro folders*(files: untyped) =
  # Create data folder if not exists
  let 
    dataPath = prepareFolder(files, "data")
    sourcePath = lineInfoObj(files).filename.parentDir()
  # Copy Each Defined Folder
  for file in files:
    expectKind(file, nnkInfix)
    expectIdent(file[0], "->")
    let
      src = sourcePath / file[1].strVal
      dst = dataPath / file[2].strVal
    # Copy Current Path
    eorge file, ["cp -r", src, dst]

# ---------------------
# Icon Definition Macro
# ---------------------

func icon(item: NimNode): NimNode =
  let 
    value = newIntLitNode(mcIconsCount.value)
    ty = bindSym"GUIRasterIcon"
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

macro icons*(dir: string, list: untyped) =
  result = nnkConstSection.newTree()
  # Create data folder if not exists
  let 
    dataPath = prepareIcons(list)
    dataList = dataPath / "icons.list"
    dataSubdir = dir.strVal
  # Define Each Icon
  for item in list:
    expectKind(item, nnkInfix)
    let filename = dataSubdir / item[2].strVal
    eorge item, ["echo", filename, ">>", dataList]
    # Add New Fresh Constant
    result.add icon(item)
