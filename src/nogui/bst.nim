# Arne Andersson's Binary Tree
# https://user.it.uu.se/~arnea/ps/simp.pdf

type
  NBinaryNode = ptr NBinaryKey
  NBinaryTop = ptr NBinaryTree
  NBinaryStack = object
    top: NBinaryNode
    tree: ptr NBinaryTree
  # Balanced Binary Tree
  NBinaryKey* = object
    id*, level: uint32
    tree*: ptr NBinaryTree
    # Balanced Tree Nodes
    left: NBinaryNode
    right: NBinaryNode
  NBinaryTree* = object
    ticket*, pad: uint32
    zero: NBinaryKey
    root: NBinaryNode
    # Sentinel Nodes
    dummy: NBinaryNode
    deleted: NBinaryNode
    result: NBinaryNode
    # Restore Nodes
    s0: NBinaryNode
    s1: NBinaryNode

# --------------------
# Binary Node Rotation
# --------------------

proc skew(node: var NBinaryNode) =
  if node.left.level == node.level:
    let tmp = node
    # Rotate Right
    node = node.left
    tmp.left = node.right
    node.right = tmp
    
proc split(node: var NBinaryNode) =
  if node.right.right.level == node.level:
    let tmp = node
    # Rotate Left
    node = node.right
    tmp.right = node.left
    node.left = tmp
    # Increment level
    node.level += 1

# ------------------------
# Binary Node Manipulation
# ------------------------

proc insert(node: var NBinaryNode, key: NBinaryNode) =
  if node == node.tree.dummy:
    key.level = 1
    key.left = node
    key.right = node
    # Node Inserted
    node.tree.result = key
    node = key
    return
  # Walk Inside Tree
  if key.id < node.id:
    insert(node.left, key)
  elif key.id > node.id:
    insert(node.right, key)
  # Balance Tree
  skew(node)
  split(node)

proc remove(node: var NBinaryNode, key: NBinaryNode) =
  let tree = node.tree
  if node == tree.dummy:
    return
  # Walk Inside Tree
  tree.result = node
  if key.id < node.id:
    remove(node.left, key)
  else: # Walk to Last Right
    tree.deleted = node
    remove(node.right, key)
  # Check Element Removal
  let
    del = tree.deleted
    dum = tree.dummy
  if node == tree.result and del != dum and key.id == del.id:
    swap(del.id, node.id)
    tree.s0 = del
    tree.s1 = node
    # Remove Element
    tree.deleted = dum
    tree.result = dum
    node = node.right
    return
  # Balance Tree
  let level = node.level - 1
  if node.left.level < level or node.right.level < level:
    # Prepare Right Level
    node.level = level
    if node.right.level > level:
      node.right.level = level
    # Apply Tree Rotations
    skew(node)
    skew(node.right)
    skew(node.right.right)
    split(node)
    split(node.right)

proc patch(node: var NBinaryNode, s0, s1: NBinaryNode) =
  if node == node.tree.dummy: return
  elif node == s0:
    swap(s0[], s1[])
    node = s1
  # Find Inside Tree
  elif s0.id > node.id:
    patch(node.right, s0, s1)
  else: patch(node.left, s0, s1)

# ------------------------
# Binary Tree Manipulation
# ------------------------

proc configure*(tree: var NBinaryTree) =
  assert tree.ticket == 0
  # Initialize Dummies
  let zero = addr tree.zero
  zero.tree = addr tree
  zero.left = zero
  zero.right = zero
  # Initialize Zentinels
  tree.root = zero
  tree.dummy = zero
  tree.deleted = zero
  tree.result = zero
  # Initialize Ticket
  tree.ticket = 1

proc insert*(tree: var NBinaryTree, key: ptr NBinaryKey): bool =
  assert isNil(key.tree)
  # Insert Node to Tree
  key.tree = addr tree
  tree.result = tree.dummy
  insert(tree.root, key)
  # Return Insert Check
  tree.result == key

proc remove*(tree: var NBinaryTree, key: ptr NBinaryKey): bool =
  assert key.tree == addr tree
  tree.s0 = tree.dummy
  tree.s1 = tree.dummy
  # Remove Node from Tree
  remove(tree.root, key)
  result = tree.s0 == key
  # Replace Node Pointer if Removed
  if result and tree.s0 != tree.s1:
    patch(tree.root, tree.s0, tree.s1)
  key[] = NBinaryKey(id: key.id)

proc register*(tree: var NBinaryTree, key: ptr NBinaryKey): bool =
  key.id = tree.ticket
  result = tree.insert(key)
  # Next Tree Ticket
  assert tree.ticket > 0
  inc(tree.ticket)

# ------------------
# Binary Tree Search
# ------------------

proc search(node: NBinaryNode, id: uint32) =
  if id == node.id:
    node.tree.result = node; return
  elif node == node.tree.dummy: return
  # Find Inside Tree
  elif id > node.id:
    search(node.right, id)
  else: search(node.left, id)

proc search*(tree: var NBinaryTree, id: uint32): ptr NBinaryKey =
  tree.result = tree.dummy
  # Find Inside Tree
  search(tree.root, id)
  if tree.result != tree.dummy:
    result = tree.result

# ---------------------------
# Binary Tree Traversal Stack
# ---------------------------

proc push(stack: var NBinaryStack, node: NBinaryNode) =
  if isNil(stack.top):
    stack.top = node
    stack.tree = node.tree
    wasMoved(node.tree)
    return
  # Push Binary Node Stack
  node.tree = cast[NBinaryTop](stack.top)
  stack.top = node

proc pop(stack: var NBinaryStack): NBinaryNode =
  result = stack.top
  # Pop Binary Node Stack
  stack.top = cast[NBinaryNode](result.tree)
  result.tree = stack.tree

# ---------------------
# Binary Tree Traversal
# ---------------------

iterator preorder*(tree: NBinaryTree): ptr NBinaryKey =
  let dummy = tree.dummy
  var stack: NBinaryStack
  # Initialize First Stack
  if tree.root != dummy:
    stack.push(tree.root)
  # Pre-order Traverse
  while not isNil(stack.top):
    let node = stack.pop()
    yield node
    # Push Preorder Elements
    if node.right != dummy:
      stack.push(node.right)
    if node.left != dummy:
      stack.push(node.left)

iterator inorder*(tree: NBinaryTree): ptr NBinaryKey =
  let dummy = tree.dummy
  var node = tree.root
  # In-order Traverse
  var stack: NBinaryStack
  while node != dummy or not isNil(stack.top):
    while node != dummy:
      stack.push(node)
      node = node.left
    # Yield Current Node
    node = stack.pop()
    yield node
    # Inside Right Node
    node = node.right

iterator postorder*(tree: NBinaryTree): ptr NBinaryKey =
  let dummy = tree.dummy
  var node = tree.root
  var last = dummy
  # Post-order Traverse
  var stack: NBinaryStack
  while node != dummy or not isNil(stack.top):
    if node != dummy:
      stack.push(node)
      node = node.left
      continue
    # Check Visited Node
    let peek = stack.top
    if peek.right != dummy and last != peek.right:
      node = peek.right
      continue
    # Process Node
    last = stack.pop()
    yield last
