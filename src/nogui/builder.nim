import gui/[widget, event, render]
from gui/signal import 
  GUICallback, GUICallbackEX, 
  unsafeCallback, unsafeCallbackEX
import macros, macrocache
from strformat import fmt

# -------------------
# Widget VTable Types
# -------------------

type
  VMethodKind = enum
    mkHandle
    mkEvent 
    mkUpdate
    mkLayout
    mkDraw
    # Invalid Method
    mkInvalid

proc Handle(obj: GUIWidget, kind: GUIHandle) {.noconv.} = discard
proc Event(obj: GUIWidget, state: ptr GUIState) {.noconv.} = discard
proc Update(obj: GUIWidget) {.noconv.} = discard
proc Layout(obj: GUIWidget) {.noconv.} = discard
proc Draw(obj: GUIWidget, ctx: ptr CTXRender) {.noconv.} = discard
# Tracking VTable Methods
const mcMethods = CacheTable"vtables"

# ---------------------
# Widget VTable Methods
# ---------------------

func vtableCreate(): NimNode =
  result = nnkStmtList.newTree(
    bindSym"Handle",
    bindSym"Event", 
    bindSym"Update", 
    bindSym"Layout", 
    bindSym"Draw",
    # Dummy Value
    newEmptyNode()
  )

func vtableMagic(name, m: NimNode): NimNode =
  let
    declare = newStrLitNode("const void* vtable__")
    arrayStart = newStrLitNode("[] = {")
    arrayEnd = newStrLitNode("};")
    comma = newStrLitNode(",")
  # m must be statement list
  expectKind(m, nnkStmtList)
  let name = newStrLitNode(name.strVal)
  # Emit C Code Definition
  result = nnkPragma.newTree(
    nnkExprColonExpr.newTree(
      newIdentNode("emit"),
      nnkBracket.newTree(
        declare,
        name,
        arrayStart,
        m[ord mkHandle], comma,
        m[ord mkEvent], comma,
        m[ord mkUpdate], comma,
        m[ord mkLayout], comma,
        m[ord mkDraw], comma,
        arrayEnd
      )
    )
  )

func vtableInject(name, target: NimNode): NimNode =
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

# ---------------------
# Callback Proc Creator
# ---------------------

func cbAttribute(self, cb: NimNode): NimNode =
  let 
    sym = cb[0]
    declare = cb[^2]
    defs = nnkIdentDefs.newTree()
    inject = nnkAsgn.newTree()
    # Pointer Cast
    dot = nnkDotExpr.newTree(ident"self", declare[0])
    convert = nnkCast.newTree(
      bindSym"pointer", ident"self")
  # Return Attribute
  case declare.kind
  of nnkIdent:
    let call = bindSym"unsafeCallback"
    defs.add declare, bindSym"GUICallback"
    # Add Simple Injector
    inject.add(dot, nnkCall.newTree(call, convert, sym))
  of nnkExprColonExpr:
    let call = nnkBracketExpr.newTree(
      bindSym"unsafeCallbackEX", declare[1])
    defs.add declare[0], nnkBracketExpr.newTree(
      bindSym"GUICallbackEX", declare[1])
    # Add Extra Injector
    inject.add(dot, nnkCall.newTree(call, convert, sym))
  # is possible reach here?
  else: discard
  # Return Attribute and Injector
  result = nnkExprColonExpr.newTree(defs, inject)

func cbCallback(self, state, fn: NimNode): NimNode =
  let
    declare = fn[1]
    # Callback Proc Parameters
    params = nnkFormalParams.newTree newEmptyNode()
  # Add Self and State Parameter
  params.add nnkIdentDefs.newTree(
    ident"self", self, newEmptyNode())
  params.add nnkIdentDefs.newTree(
    ident"state", state, newEmptyNode())
  # Add Extra Parameter if exists
  var
    stmts = fn[2]
    name = declare
  if declare.kind == nnkObjConstr:
    let extra = declare[1]
    # Check Parameter
    expectKind(extra, nnkExprColonExpr)
    expectLen(extra, 2)
    var
      name = extra[0]
      ty = extra[1]
    # Simulate Pass by Copy
    expectKind(ty, {nnkIdent, nnkPtrTy})
    if ty.kind == nnkIdent:
      let 
        fresh = genSym(nskParam)
        warped = quote do:
          let `name` = `fresh`[]; stmts
      # Replace Values
      name = fresh
      stmts = warped
      ty = nnkPtrTy.newTree ty
    # Add Parameter and Store Extra Value Type
    params.add nnkIdentDefs.newTree(name, ty, newEmptyNode())
    name = nnkExprColonExpr.newTree(declare[0], ty[0])
  # Declare New Callback
  let sym = genSym(nskProc, name.strVal)
  result = nnkProcDef.newTree(
    sym,
    newEmptyNode(),
    newEmptyNode(),
    params,
    newEmptyNode(),
    name, # Reserved ^2
    stmts
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
    # Expect Kinds
    expectKind(name, nnkIdent)
    expectKind(super, nnkIdent)
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

proc wConstructorParams(self, declare: NimNode): NimNode =
  expectKind(declare, {nnkObjConstr, nnkCall})
  # Create New Formal Parameters
  result = nnkFormalParams.newTree(self)
  let count = declare.len
  # Translate Each Parameter
  var defs = nnkIdentDefs.newTree()
  for i in 1 ..< count:
    let 
      e = declare[i]
      kind = e.kind
    expectKind(e, {nnkIdent,
      nnkExprColonExpr, nnkExprEqExpr})
    # Decide Which Parameter
    case kind
    of nnkIdent:
      defs.add e
    of nnkExprColonExpr:
      e.copyChildrenTo(defs)
      defs.add newEmptyNode()
    of nnkExprEqExpr:
      defs.add e[0], newEmptyNode(), e[1]
    else: break
    # Skip to New Ident Def
    if kind in {nnkExprColonExpr, nnkExprEqExpr}:
      result.add(defs)
      defs = nnkIdentDefs.newTree()

func wConstructorInject(self: NimNode): NimNode =
  let
    v = ident"v"
    k = bindSym"GUIMethods"
    inject = vtableInject(self, v)
  # Statemets to Initialize Widget
  result = quote do:
    new result
    block:
      var `v`: ptr `k`
      `inject`
      result.vtable = `v`

proc wConstructor(self, fn: NimNode): NimNode =
  expectIdent(fn[0], "new")
  # Expect Object Definition
  let 
    declare = fn[1]
    stmts = fn[2]
    # Translate Parameters
    params = wConstructorParams(self, declare)
  # Expect Statment List
  expectKind(stmts, nnkStmtList)
  # Inject Initializers
  let 
    v = ident"v"
    k = bindSym"GUIMethods"
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
    newEmptyNode(),
    newEmptyNode(),
    body
  )

# ----------------------
# Controller Constructor
# ----------------------

proc coConstructor(self, callbacks, fn: NimNode): NimNode =
  # Expect Object Definition
  let 
    declare = fn[1]
    stmts = fn[2]
    # Translate Parameters
    params = wConstructorParams(self, declare)
  # Expect Statment List
  expectKind(stmts, nnkStmtList)
  # Create Proc Definition
  result = nnkProcDef.newTree(
    postfix(declare[0], "*"),
    newEmptyNode(),
    newEmptyNode(),
    params,
    newEmptyNode(),
    newEmptyNode(),
    stmts
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
    methods = mcMethods[super.strVal]
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
        kind = ord wMethodKind(child)
        sym = genSym(nskProc, child[0].strVal)
        fn = wMethod(sym, name, child)
      # Overwrite Method
      methods[kind] = sym
      procs.add fn
    else: continue
  # 3 -- Store Methods
  mcMethods[name.strVal] = methods
  # 4 -- Add Type Definitions
  result = nnkStmtList.newTree()
  result.add wType(name, super, defines)
  procs.copyChildrenTo(result)
  # Add VTable C Magic
  result.add vtableMagic(name, methods)
  news.copyChildrenTo(result)
  #echo result.repr

macro child(self: GUIWidget, body: untyped) =
  let 
    fresh = genSym(nskLet, "temp")
    hook = bindSym"add"
  # Declare Temporal Variable
  result = nnkStmtList.newTree(
    nnkLetSection.newTree(
      nnkIdentDefs.newTree(
          fresh, newEmptyNode(), self
        )
      )
    )
  # Warp Each Widget
  for node in body:
    # Only Expect Any Valuable or Asign Item
    expectKind(node, {nnkIdent, nnkCall, nnkAsgn})
    let warp = nnkCommand.newTree(
      nnkDotExpr.newTree(fresh, hook), node)
    # Assing and Then Add
    if node.kind == nnkAsgn:
      warp[1] = node[0]
      result.add node
    # Add Warping
    result.add warp

template child*[T: GUIWidget](self: T, body: untyped): T =
  # Warp Each Children and Return
  child(self, body); self
