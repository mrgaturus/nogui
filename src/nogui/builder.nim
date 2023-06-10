import gui/[widget, event, render]
import macros, std/tables
from strformat import fmt

# -------------------
# Widget VTable Types
# -------------------

proc Handle(obj: GUIWidget, kind: GUIHandle) {.noconv.} = discard
proc Event(obj: GUIWidget, state: ptr GUIState) {.noconv.} = discard
proc Update(obj: GUIWidget) {.noconv.} = discard
proc Layout(obj: GUIWidget) {.noconv.} = discard
proc Draw(obj: GUIWidget, ctx: ptr CTXRender) {.noconv.} = discard

type
  VMethodKind = enum
    mkHandle, mkEvent, mkUpdate, mkLayout, mkDraw, mkInvalid
  VMethodTable = array[VMethodKind, NimNode]
# Tracking VTable Methods
var vtables {.compileTime.} = 
  initTable[string, VMethodTable]()
# Treeable Constructors
template node() {.pragma.}

# ---------------------
# Widget VTable Methods
# ---------------------

func vtableCreate(): VMethodTable =
  result = [
    bindSym"Handle", 
    bindSym"Event", 
    bindSym"Update", 
    bindSym"Layout", 
    bindSym"Draw",
    # Dummy Value
    newEmptyNode()
  ]

func vtableMagic(name: NimNode, m: VMethodTable): NimNode =
  let
    declare = newStrLitNode("const void* vtable__")
    arrayStart = newStrLitNode("[] = {")
    arrayEnd = newStrLitNode("};")
    comma = newStrLitNode(",")
  # Name must be ident
  expectKind(name, nnkIdent)
  let name = newStrLitNode(name.strVal)
  # Emit C Code Definition
  result = nnkPragma.newTree(
    nnkExprColonExpr.newTree(
      newIdentNode("emit"),
      nnkBracket.newTree(
        declare,
        name,
        arrayStart,
        m[mkHandle], comma,
        m[mkEvent], comma,
        m[mkUpdate], comma,
        m[mkLayout], comma,
        m[mkDraw], comma,
        arrayEnd
      )
    )
  )

func vtableInject(name, target: NimNode): NimNode =
  # Name must be ident
  expectKind(name, nnkIdent)
  expectKind(target, nnkIdent)
  let name = newStrLitNode(name.strVal)
  # Emit C Code Pointer Magic
  result = nnkPragma.newTree(
    nnkExprColonExpr.newTree(
      newIdentNode("emit"),
      nnkBracket.newTree(
        target,
        newStrLitNode" = (",
        nnkDotExpr.newTree(target, ident"type"),
        newStrLitNode") &vtable__", name, newStrLitNode";"
      )
    )
  )

# ----------------------
# Widget Type Attributes
# ----------------------

func wIdents(attribute: NimNode, public = false): NimNode =
  result = newNimNode(nnkIdentDefs)
  # Add Identification
  let ident = attribute[0]
  case ident.kind
  of nnkIdent:
    result.add if public: 
        postfix(ident, "*")
      else: ident
  of nnkBracket:
    for id in ident:
      result.add if public: 
          postfix(id, "*") 
        else: id
  else: result = newEmptyNode()
  # Add Attribute Type
  if result.kind == nnkIdentDefs:
    let s = attribute[1]
    expectKind(s, nnkStmtList)
    result.add s[0]
    # Add Boilerplate Empty
    result.add newEmptyNode()

func wDefines(attributes: NimNode): NimNode =
  result = newNimNode(nnkRecList)
  # Expect Statment List
  let stmts = attributes[1]
  expectKind(stmts, nnkStmtList)
  # Get Attributes from Statments
  for ident in stmts:
    case ident.kind
    of nnkCall:
      result.add wIdents(ident)
    of nnkPrefix:
      expectIdent(ident[0], "@")
      expectIdent(ident[1], "public")
      # Expect Statment List
      let publics = ident[2]
      expectKind(publics, nnkStmtList)
      # Process Each Public Attribute
      for pub in publics:
        if pub.kind == nnkCall:
          result.add wIdents(pub, true)
        # Add New Attribute
    else: continue

# ------------------
# Widget Type Object
# ------------------

func wDeclare(declare: NimNode): tuple[name, super: NimNode] =
  var name, super: NimNode
  # Extract Name and Parent Type
  expectKind(declare, {nnkIdent, nnkInfix})
  if declare.kind == nnkIdent:
    name = declare
    # Default Inherit
    super = ident"GUIWidget"
  else: 
    expectIdent(declare[0], "of")
    # There is an Inherit
    name = declare[1]
    super = declare[2]
  # Return Declare
  result = (name, super)

func wType(name, super, defines: NimNode): NimNode =
  # ref object of
  let n = nnkRefTy.newTree(
    nnkObjectTy.newTree(
      nnkEmpty.newNimNode(),
      nnkOfInherit.newTree(super),
      defines
    )
  )
  # Declare Type
  result = quote do:
    type `name` = `n` 

# -------------------
# Widget Proc/Methods
# -------------------

func wProc(self, fn: NimNode): NimNode =
  expectKind(self, nnkIdent)
  expectKind(fn, nnkProcDef)
  # Duplicate Node
  result = fn
  # Self Parameter
  let param = nnkIdentDefs.newTree(
    ident"self", self, 
    newEmptyNode()
  )
  # Inject Self Parameter
  result[3].insert(1, param)

func wMethod(symbol, self, fn: NimNode): NimNode =
  expectKind(self, nnkIdent)
  expectKind(fn, nnkMethodDef)
  # Create Parameters
  let 
    params = fn[3]
    stmts = fn[6]
    inject = nnkIdentDefs.newTree(
      ident"self", self, newEmptyNode())
  # Inject Self Parameter
  params.insert(1, inject)
  # Create Proc Declaration
  result = nnkProcDef.newTree(
    symbol, 
    newEmptyNode(), 
    newEmptyNode(), 
    params,
    nnkPragma.newTree ident"noconv",
    newEmptyNode(),
    stmts
  )

proc wMethodCheck(fn, expect: NimNode) =
  # Reusable Kind Error Message
  proc error(msg: string, exp, got: NimNode; lines: NimNode) =
    error fmt"{msg} expected <{exp.repr}> got <{got.repr}>", lines
  # Expect Types
  expectKind(expect, nnkSym)
  expectKind(fn, nnkMethodDef)
  let # Parameters
    params = fn[3]
    formal = expect.getTypeImpl[0]
    # Return Type
    retFn = params[0]
    retEx = formal[0]
    # Parameters Count
    lenFn = params.len - 1
    lenEx = formal.len - 2
  # Check Return Parameter
  if retFn != retEx and not retFn.eqIdent(retEx):
    error("invalid return type:", 
      retEx, retFn, params)
  # Check Each Parameter
  var count = 2
  for i in 1 .. lenFn:
    let 
      defs = params[i]
      l = defs.len - 2
      # Parameter Type
      kindFn = defs[l]
      kindEx = formal[count][^2]
    # Hacky But Works
    if kindFn.repr != kindEx.repr:
      error("invalid parameter type:", 
        kindEx, kindFn, defs)
    # Step Parameter
    count += l
  # Check Parameters Count
  count -= 2; if count != lenEx:
    error("invalid parameter type:", 
      ident $lenEx, ident $count, params)

func wMethodKind(fn: NimNode): VMethodKind =
  # Expect A Method
  expectKind(fn, nnkMethodDef)
  let
    id = fn[0]
    name = id.strVal
  # Check Method Name Kind
  result = case name
  of "handle": wMethodCheck(fn, bindSym"Handle"); mkHandle
  of "event": wMethodCheck(fn, bindSym"Event"); mkEvent
  of "update": wMethodCheck(fn, bindSym"Update"); mkUpdate
  of "layout": wMethodCheck(fn, bindSym"Layout"); mkLayout
  of "draw": wMethodCheck(fn, bindSym"Draw"); mkDraw
  else: error("invalid method name", id);  mkInvalid

# ------------------
# Widget Constructor
# ------------------

proc wConstructor(self, fn: NimNode): NimNode =
  # Expect a new Call
  expectKind(fn, nnkCommand)
  expectIdent(fn[0], "new")
  # Expect Object Definition
  let 
    declare = fn[1]
    stmts = fn[2]
  expectKind(declare, {nnkObjConstr, nnkCall})
  expectKind(stmts, nnkStmtList)
  # Create Parameters
  let 
    params = nnkFormalParams.newTree(self)
    count = declare.len
  # Translate Each Parameter
  var defs = nnkIdentDefs.newTree()
  for i in 1 ..< count:
    let e = declare[i]
    expectKind(e, {nnkIdent, nnkExprColonExpr})
    # Decide if is 
    case e.kind
    of nnkIdent:
      defs.add e
    of nnkExprColonExpr:
      e.copyChildrenTo(defs)
      defs.add newEmptyNode()
      # Add new ident def
      params.add(defs)
      defs = nnkIdentDefs.newTree()
    else: continue
  echo params.treeRepr
  # Inject Initializers
  let 
    v = ident"v"
    k = bindSym"GUIMethods"
    pragma = bindSym"node"
    inject = vtableInject(self, v)
    body = quote do:
      new result
      block:
        var `v`: ptr `k`
        `inject`
        result.vtable = `v`
      `stmts`
  # Create Proc Definition
  result = nnkProcDef.newTree(
    postfix(declare[0], "*"),
    newEmptyNode(),
    newEmptyNode(),
    params,
    nnkPragma.newTree(pragma),
    newEmptyNode(),
    body
  )

# -----------------------
# Widget Definition Macro
# -----------------------

macro widget*(declare, body: untyped) =
  # 1 -- Declare Widget Type
  let 
    (name, super) = wDeclare(declare) 
    procs = nnkStmtList.newTree()
    news = nnkStmtList.newTree()
  var
    methods = vtableCreate()
    defines = newEmptyNode()
  if declare.kind == nnkInfix:
    methods = vtables[super.strVal]
  # 2 -- Find Defines, Procs and Methods
  for child in body:
    case child.kind
    of nnkCall: # attributes
      expectIdent(child[0], "attributes")
      expectKind(defines, nnkEmpty)
      defines = wDefines(child)
    of nnkCommand: # constructor
      news.add wConstructor(name, child)
    of nnkProcDef: # proc
      procs.add wProc(name, child)
    of nnkMethodDef: # method
      let 
        kind = wMethodKind(child)
        sym = genSym(nskProc, child[0].strVal)
        fn = wMethod(sym, name, child)
      # Overwrite Method
      methods[kind] = sym
      procs.add fn
    else: continue
  # 3 -- Add Type Definitions
  result = nnkStmtList.newTree()
  result.add wType(name, super, defines)
  procs.copyChildrenTo(result)
  # Add VTable C Magic
  result.add vtableMagic(name, methods)
  news.copyChildrenTo(result)
  #echo result.repr
