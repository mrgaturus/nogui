import gui/[widget, event, render]
from gui/signal import 
  GUICallback, GUICallbackEX, 
  unsafeCallback, unsafeCallbackEX
import macros, macrocache

# -------------------
# Widget VTable Types
# -------------------

type
  MethodKind = enum
    mkInvalid
    # Widget Methods
    mkHandle
    mkEvent 
    mkUpdate
    mkLayout
    mkDraw

proc handle0(obj: GUIWidget, kind: GUIHandle) {.noconv.} = discard
proc event0(obj: GUIWidget, state: ptr GUIState) {.noconv.} = discard
proc update0(obj: GUIWidget) {.noconv.} = discard
proc layout0(obj: GUIWidget) {.noconv.} = discard
proc draw0(obj: GUIWidget, ctx: ptr CTXRender) {.noconv.} = discard
# Tracking Objects, Callbacks and Methods
const mcObjects = CacheTable"nobjects"

# ---------------------
# Widget VTable Methods
# ---------------------

func vtableCreate(): NimNode =
  result = nnkStmtList.newTree(
    nnkStmtList.newNimNode(),
    # Widget Methods
    bindSym"handle0",
    bindSym"event0", 
    bindSym"update0", 
    bindSym"layout0", 
    bindSym"draw0",
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

func vtableInject(name: NimNode): NimNode =
  let
    name = newStrLitNode(name.strVal)
    ty = bindSym"GUIMethods"
    tmp = genSym(nskVar, "tmp")
  # Emit C Code Pointer Magic
  let inject = nnkPragma.newTree(
    nnkExprColonExpr.newTree(
      newIdentNode("emit"),
      nnkBracket.newTree(
        tmp, newStrLitNode" = (", ty,
        newStrLitNode"*) &vtable__", name, newStrLitNode";"
      )
    )
  )
  # Warp Into a Block
  result = quote do:
    block:
      var `tmp`: ptr `ty`; `inject`
      self.vtable = `tmp`

# ---------------------
# Callback Proc Creator
# ---------------------

func cbAttribute(self, cb: NimNode): NimNode =
  let 
    sym = cb[0]
    declare = cb[^2]
    # Attribute Lists
    defs = nnkIdentDefs.newTree()
    inject = nnkAsgn.newTree()
    # Attribute Definition
    name = declare[0]
    ty = declare[1]
    post = postfix(name, "*")
    # Pointer Casting
    dot = nnkDotExpr.newTree(ident"self", name)
    convert = nnkCast.newTree(
      bindSym"pointer", ident"self")
    dummy = newEmptyNode()
  # Return Attribute
  case ty.kind
  of nnkEmpty:
    let call = bindSym"unsafeCallback"
    defs.add post, bindSym"GUICallback", dummy
    # Add Simple Injector
    inject.add(dot, nnkCall.newTree(call, convert, sym))
  of nnkIdent:
    let call = nnkBracketExpr.newTree(
      bindSym"unsafeCallbackEX", ty)
    defs.add post, nnkBracketExpr.newTree(
      bindSym"GUICallbackEX", ty), dummy
    # Add Extra Injector
    inject.add(dot, nnkCall.newTree(call, convert, sym))
  # is possible reach here?
  else: discard
  # Return Attribute and Injector
  result = nnkExprColonExpr.newTree(defs, inject)

func cbCallback(self, fn: NimNode): NimNode =
  let
    declare = fn[1]
    # Callback Proc Parameters
    params = nnkFormalParams.newTree newEmptyNode()
    info = nnkExprColonExpr.newTree()
  # Add Self Parameter
  params.add nnkIdentDefs.newTree(
    ident"self", self, newEmptyNode())
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
      warped[0][0][0].copyLineInfo(declare)
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

# ----------------------
# Widget Type Attributes
# ----------------------

func wTraits(stmts: NimNode): NimNode =
  let dummy = newEmptyNode()
  var # Type, Name, Pragmas
    name = dummy
    pragmas = nnkPragma.newTree()
  # Check Pragma Traits
  for trait in stmts:
    if trait.eqIdent("public"):
      name = nnkPostfix.newTree(ident"*", dummy)
    # Otherwise Add Pragma
    else: pragmas.add trait
  # Warp Pragmas Into PragmaExpr
  if pragmas.len > 0:
    pragmas = nnkPragmaExpr.newTree(dummy, pragmas)
  # Return New IdentDef Template
  result = nnkIdentDefs.newTree(
    name, pragmas)

func wIdent(name, traits: NimNode): NimNode =
  result = traits[0].copyNimTree
  let p = traits[1].copyNimTree
  # Assemble Attribute Ident
  if result.kind == nnkPostfix:
    result[1] = name
  else: result = name
  # Assemble Pragmas
  if p.kind == nnkPragmaExpr:
    p[0] = result
    result = p

func wAttribute(attribute, traits: NimNode): NimNode =
  result = newNimNode(nnkIdentDefs)
  # Add Identification
  let ident = attribute[0]
  case ident.kind
  of nnkIdent:
    result.add wIdent(ident, traits)
  of nnkBracket:
    for id in ident:
      result.add wIdent(id, traits)
  else: result = newEmptyNode()
  # Add Attribute Type
  if result.kind == nnkIdentDefs:
    var ty = attribute[1]
    expectKind(ty, nnkStmtList)
    ty = ty[0]
    # Add Attribute Type
    result.add ty
    result.add newEmptyNode()

# ------------------
# Widget Type Object
# ------------------

func wDefines(list, stmts: NimNode) =
  let
    du = newEmptyNode()
    dummy = nnkIdentDefs.newTree(du, du)
  # Get Attributes from Statments
  for ident in stmts:
    case ident.kind
    of nnkCall:
      list.add wAttribute(ident, dummy)
    of nnkPragmaBlock:
      let 
        traits = wTraits(ident[0])
        idents = ident[1]
      # Process Each Attribute
      for id in idents:
        if id.kind == nnkCall:
          list.add wAttribute(id, traits)
        # Add New Attribute
    else: continue

func wDeclare(declare, fallback: NimNode): NimNode =
  result = nnkIdentDefs.newTree(declare, fallback)
  # Type has Inheritance
  if declare.kind == nnkInfix:
    expectIdent(declare[0], "of")
    result[0] = declare[1]
    result[1] = declare[2]

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
    type `name` * = `n`
  # Warning / Error Information
  result[0][0].copyLineInfo(defines)

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
  let params0 = fn[3]
  if expect.kind == nnkEmpty:
    error("invalid method name", params0)
  # Prepare Expected Signature
  let params1 = expect.getTypeImpl[0]
  params1.del(1)
  # Check Method Equality
  if params0.repr != params1.repr:
    error("expected parameters: " & params1.repr, params0)

func wMethodKind(fn: NimNode): MethodKind =
  let
    id = fn[0]
    name = id.strVal
    # Expected Method List
    expects = [
      newEmptyNode(),
      # Invalid Method
      bindSym"handle0",
      bindSym"event0",
      bindSym"update0",
      bindSym"layout0",
      bindSym"draw0",
    ]
  # Check Method Name Kind
  result = case name
  of "handle": mkHandle
  of "event": mkEvent
  of "update": mkUpdate
  of "layout": mkLayout
  of "draw": mkDraw
  else: mkInvalid
  # Lookup Method and Check
  let expect = expects[ord result]
  wMethodCheck(fn, expect)

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

func wConstructor(self, fn: NimNode): NimNode =
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
    # Inject Target ^1
    stmts
  )

# -------------------------
# Widget Structure Analysis
# -------------------------

func wStructureInject(self, info, inject, news: NimNode) =
  let
    sym = genSym(nskProc, "inject")
    params = nnkFormalParams.newTree()
  var inject0 = nnkProcDef.newTree(
    sym,
    newEmptyNode(),
    newEmptyNode(),
    params,
    newEmptyNode(),
    newEmptyNode(),
    inject
  )
  # Add Injector Call to Object Info
  inject0 = wProc(self, inject0)
  info[0].add newCall(sym, ident"result")
  let calls = info[0]
  # Inject Calls
  for fn in news:
    let stmts = fn[^1]
    # Replace Constructor Body
    fn[^1] = quote do:
      new result
      `calls`
      `stmts`
  # Define Injector Proc
  news.insert(0, inject0)

func wStructure(idents, info, inject, body: NimNode): NimNode =
  let
    # Unpack Idents
    name = idents[0]
    super = idents[1]
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
      # Decide new or callback
      case ty.strVal
      of "callback":
        let 
          cb = cbCallback(name, child)
          attrib = cbAttribute(name, cb)
        # Add Callback Attribute
        defines.add attrib[0]
        inject.add attrib[1]
        # Add Callback
        procs.add cb
      of "new":
        news.add wConstructor(name, child)
      else: discard
    of nnkProcDef: # proc
      procs.add wProc(name, child)
    of nnkMethodDef: # method
      if info.len < 6:
        continue
      # Define Method
      let
        kind = ord wMethodKind(child)
        sym = genSym(nskProc, child[0].strVal)
        fn = wMethod(sym, name, child)
      # Overwrite Method
      info[kind] = sym
      procs.add fn
    else: discard
  # 3 -- Constructor Injection
  wStructureInject(name, info, inject, news)
  # 4 -- Type & Structure
  result = nnkStmtList.newTree()
  result.add wType(name, super, defines)
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
    # Inject Statements Intializer
    inject0 = vtableInject(name)
    inject = nnkStmtList.newTree(inject0)
  # Create Widget Structure
  let 
    info = # Check for Inheritance
      if super == fallback: vTableCreate()
      else: mcObjects[super.strVal].copyNimTree
    # Create Widget Structure
    struct = wStructure(idents, info, inject, body)
    magic = vtableMagic(name, info)
  # Return Widget Structure
  mcObjects[name.strVal] = info
  result = nnkStmtList.newTree(struct, magic)
  #echo result.repr

macro controller*(declare, body: untyped) =
  let
    dummy = newEmptyNode()
    idents = wDeclare(declare, dummy)
    inject = nnkStmtList.newTree()
    # Create Controller Structure
    name = idents[0]
    super = idents[1]
    info = # Check for Inheritance
      if super == dummy or super == ident"RootObj":
        nnkStmtList.newTree(inject.copyNimNode)
      else: mcObjects[super.strVal].copyNimTree
  # Return Controller Structure
  result = wStructure(idents, info, inject, body)
  mcObjects[name.strVal] = info
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
  block: child(tmp, body)
  # Return Widget
  tmp
