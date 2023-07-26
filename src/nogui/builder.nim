# TODO: complete inherit initialization
# TODO: shortcut for {.cursor.} on ref attributes
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
  #debugEcho declare.treeRepr
  let
    defs = nnkIdentDefs.newTree()
    inject = nnkAsgn.newTree()
    # Attribute Definition
    name = declare[0]
    ty = declare[1]
    # Pointer Casting
    dot = nnkDotExpr.newTree(ident"result", name)
    convert = nnkCast.newTree(
      bindSym"pointer", ident"result")
    dummy = newEmptyNode()
  # Return Attribute
  case ty.kind
  of nnkEmpty:
    let call = bindSym"unsafeCallback"
    defs.add name, bindSym"GUICallback", dummy
    # Add Simple Injector
    inject.add(dot, nnkCall.newTree(call, convert, sym))
  of nnkIdent:
    let call = nnkBracketExpr.newTree(
      bindSym"unsafeCallbackEX", ty)
    defs.add name, nnkBracketExpr.newTree(
      bindSym"GUICallbackEX", ty), dummy
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
    info = nnkExprColonExpr.newTree()
  # Add Self Parameter
  params.add nnkIdentDefs.newTree(
    ident"self", self, newEmptyNode())
  # Add State Parameter
  let s = nnkIdentDefs.newTree(
    ident"state", 
    nnkPtrTy.newTree(state), 
    newEmptyNode()
  )
  if state.kind == nnkEmpty:
    s[0] = genSym(nskParam, "state")
    s[1] = bindSym"pointer"
  params.add s
  # Add Extra Parameter if exists
  var stmts = fn[2]
  if declare.kind == nnkObjConstr:
    let extra = declare[1]
    # Check Parameter
    expectKind(extra, nnkExprColonExpr)
    expectLen(extra, 2)
    var
      name = extra[0]
      ty = extra[1]
    # Simulate Pass by Copy
    expectKind(ty, {nnkIdent, nnkCommand})
    if ty.kind == nnkCommand:
      let 
        fresh = genSym(nskParam)
        warped = quote do:
          var `name` = `fresh`[]; `stmts`
      # Remember Line
      expectIdent(ty[0], "sink")
      warped[0][0][0].copyLineInfo(extra)
      # Replace Values
      name = fresh
      stmts = warped
      ty = ty[1]
    # Change Info Kind
    ty = nnkPtrTy.newTree ty
    info.add(declare[0], ty[0])
    # Add Parameter and Store Extra Value Type
    params.add nnkIdentDefs.newTree(name, ty, newEmptyNode())
  else: info.add declare, newEmptyNode()
  # Declare New Callback
  let sym = genSym(nskProc, info[0].strVal)
  result = nnkProcDef.newTree(
    sym,
    newEmptyNode(),
    newEmptyNode(),
    params,
    newEmptyNode(),
    info, # Reserved ^2
    stmts
  )

# ------------------
# Widget Type Object
# ------------------

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

func wDefines(list, stmts: NimNode) =
  # Get Attributes from Statments
  for ident in stmts:
    case ident.kind
    of nnkCall:
      list.add wIdents(ident)
    of nnkPrefix:
      expectIdent(ident[0], "@")
      expectIdent(ident[1], "public")
      # Expect Statment List
      let publics = ident[2]
      expectKind(publics, nnkStmtList)
      # Process Each Public Attribute
      for pub in publics:
        if pub.kind == nnkCall:
          list.add wIdents(pub, true)
        # Add New Attribute
    else: continue

func wDeclare(declare, fallback: NimNode): NimNode =
  # Pack idents as [name, super, state]
  func wNames(n, fallback: NimNode): NimNode =
    # Check if has a inherit or not
    result = 
      if n.kind == nnkInfix:
        expectIdent(n[0], "of")
        nnkIdentDefs.newTree(n[1], n[2])
      else: nnkIdentDefs.newTree(n, fallback)
    # Add Space for State
    result.add newEmptyNode()
  # Check if is ident or not
  expectKind(declare, {nnkIdent, nnkInfix})
  # Check Declare Indents
  if declare.kind == nnkInfix and declare[0].eqIdent("->"):
      result = wNames(declare[1], fallback)
      result[2] = declare[2]
  else: result = wNames(declare, fallback)

func wType(name, super, defines: NimNode): NimNode =
  let recs = nnkRecList.newTree()
  # Capture Defines
  for def in defines:
    case def.kind
    of nnkStmtList:
      recs.wDefines(def)
    of nnkIdentDefs:
      recs.add def
    else: discard 
  # check super inherit
  var inherit = super
  if inherit.kind != nnkEmpty:
    inherit = nnkOfInherit.newTree(super)
  # ref object of
  let n = nnkRefTy.newTree(
    nnkObjectTy.newTree(
      nnkEmpty.newNimNode(),
      inherit, recs
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

func wMethodCheck(fn, expect: NimNode) =
  # Reusable Kind Error Message
  func error(msg: string, exp, got: NimNode; lines: NimNode) =
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
  else: error("invalid method name", id); mkInvalid

# ------------------
# Widget Constructor
# ------------------

func wConstructorParams(self, declare: NimNode): NimNode =
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

func wConstructor(self, inject, fn: NimNode): NimNode =
  expectIdent(fn[0], "new")
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
    # Inject -> Statements
    inject.add(stmts)
  )

# -------------------------
# Widget Structure Analysis
# -------------------------

func wStructure(idents, inject, methods, body: NimNode): NimNode =
  let
    # Unpack Idents
    name = idents[0]
    super = idents[1]
    state = idents[2]
    # Collect Widget Objects
    defines = newTree(nnkStmtList)
    procs = newTree(nnkStmtList)
    news = newTree(nnkStmtList)
  # 2 -- Find Defines, Procs and Methods
  for child in body:
    case child.kind
    of nnkCall: # attributes
      expectIdent(child[0], "attributes")
      let stmts = child[1]
      # Add Define List
      expectKind(stmts, nnkStmtList)
      defines.add stmts
    of nnkCommand: # new or callback
      let ty = child[0]
      expectKind(ty, nnkIdent)
      # TODO: Allow Widget Use A State
      case ty.strVal
      of "callback":
        let 
          cb = cbCallback(name, state, child)
          attrib = cbAttribute(name, cb)
        # Add Callback Attribute
        defines.add attrib[0]
        inject.add attrib[1]
        # Add Callback
        procs.add cb
      of "new": news.add wConstructor(name, inject, child)
      else: discard
    of nnkProcDef: # proc
      procs.add wProc(name, child)
    of nnkMethodDef: # method
      let
        kind = ord wMethodKind(child)
        sym = genSym(nskProc, child[0].strVal)
        fn = wMethod(sym, name, child)
      # Overwrite Method if is Widget
      expectKind(methods, nnkStmtList)
      methods[kind] = sym
      procs.add fn
    else: discard
  # 3 -- Define Type
  result = nnkStmtList.newTree()
  result.add wType(name, super, defines)
  # 3 -- Add Structure
  result.add procs
  result.add news

# -----------------------
# Widget Definition Macro
# -----------------------

macro widget*(declare, body: untyped) =
  let
    fallback = bindSym"GUIWidget"
    idents = wDeclare(declare, fallback)
    # Unpack Idents
    name = idents[0]
    super = idents[1]
    # Injector
    v = ident"v"
    k = bindSym"GUIMethods"
    inject0 = vtableInject(name, v)
    # Inject Initializer
    inject = quote do:
      new result
      block:
        var `v`: ptr `k`
        `inject0`
        result.vtable = `v`
  # Create Widget VTable and Structure
  let 
    methods = # Create new VTable
      if super == fallback: vTableCreate()
      else: mcMethods[super.strVal]
    struct = wStructure(idents, inject, methods, body)
    magic = vtableMagic(name, methods)
  # Return Widget Structure
  mcMethods[name.strVal] = methods
  result = nnkStmtList.newTree(magic, struct)
  #echo result.repr

macro controller*(declare, body: untyped) =
  let
    dummy = newEmptyNode()
    idents = wDeclare(declare, dummy)
    # Simple Injector
    inject = quote do:
      new result
      discard
  # Return Controller Structure
  result = wStructure(idents, inject, dummy, body)
  #echo result.repr

macro child(self: GUIWidget, body: untyped) =
  let hook = bindSym"add"
  # Declare Statement List
  result = nnkStmtList.newTree()
  # Warp Each Widget
  for node in body:
    # Only Expect Any Valuable or Asign Item
    expectKind(node, {nnkIdent, nnkCall, nnkAsgn})
    let warp = nnkCommand.newTree(
      nnkDotExpr.newTree(self, hook), node)
    # Assing and Then Add
    if node.kind == nnkAsgn:
      warp[1] = node[0]
      result.add node
    # Add Warping
    result.add warp

template child*[T: GUIWidget](self: T, body: untyped): T =
  # Warp Childrens
  let tmp = self
  child(tmp, body); tmp
