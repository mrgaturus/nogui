import random
import nogui/bst
# Private Field Access
import std/importutils
privateAccess(NBinaryKey)
privateAccess(NBinaryTree)

type
  NBinaryFuzzer = object
    keys: seq[NBinaryKey]
    numbers: seq[uint32]
    aux: seq[uint32]
    # Balanced Binary Tree
    tree: NBinaryTree

# --------------------------
# Binary Recursive Traversal
# --------------------------

proc preorder(node: ptr NBinaryKey, list: var seq[uint32]) =
  if node == node.tree.dummy:
    return
  list.add(node.id)
  preorder(node.left, list)
  preorder(node.right, list)

proc inorder(node: ptr NBinaryKey, list: var seq[uint32]) =
  if node == node.tree.dummy:
    return
  inorder(node.left, list)
  list.add(node.id)
  inorder(node.right, list)

proc postorder(node: ptr NBinaryKey, list: var seq[uint32]) =
  if node == node.tree.dummy:
    return
  postorder(node.left, list)
  postorder(node.right, list)
  list.add(node.id)

# ------------------
# Binary Tree Fuzzer
# ------------------

proc configure(fuzzy: var NBinaryFuzzer) =
  fuzzy.tree.ticket = 0
  configure(fuzzy.tree)
  let max = rand(16384)
  # Create Fuzzy Arrays
  setLen(fuzzy.keys, max)
  setLen(fuzzy.numbers, max)
  setLen(fuzzy.aux, max)
  # Initialize Fuzzy
  var idx = 0
  while idx < max:
    let id = uint32 rand(65535)
    fuzzy.keys[idx] = NBinaryKey(id: id)
    fuzzy.numbers[idx] = id
    if fuzzy.tree.insert(addr fuzzy.keys[idx]):
      inc(idx)

proc preorder(fuzzy: var NBinaryFuzzer) =
  var idx = 0; setLen(fuzzy.aux, 0)
  preorder(fuzzy.tree.root, fuzzy.aux)
  for key in preorder(fuzzy.tree):
    assert key.id == fuzzy.aux[idx]
    inc(idx)
  assert idx == len(fuzzy.aux)

proc inorder(fuzzy: var NBinaryFuzzer) =
  var idx = 0; setLen(fuzzy.aux, 0)
  inorder(fuzzy.tree.root, fuzzy.aux)
  for key in inorder(fuzzy.tree):
    assert key.id == fuzzy.aux[idx]
    inc(idx)
  assert idx == len(fuzzy.aux)

proc postorder(fuzzy: var NBinaryFuzzer) =
  var idx = 0; setLen(fuzzy.aux, 0)
  postorder(fuzzy.tree.root, fuzzy.aux)
  for key in postorder(fuzzy.tree):
    assert key.id == fuzzy.aux[idx]
    inc(idx)
  assert idx == len(fuzzy.aux)

proc search(fuzzy: var NBinaryFuzzer) =
  for n in fuzzy.numbers:
    let key = search(fuzzy.tree, n)
    assert not isNil(key) and key.id == n

proc remove(fuzzy: var NBinaryFuzzer) =
  for key in mitems(fuzzy.keys):
    assert remove(fuzzy.tree, addr key)
  # Ensure was Removed and not Changed
  for idx, n in pairs(fuzzy.numbers):
    assert fuzzy.keys[idx].id == n
    let key = search(fuzzy.tree, n)
    assert isNil(key)

# --------------------
# Testing Main Program
# --------------------

proc test(fuzzy: var NBinaryFuzzer) =
  fuzzy.configure()
  # Test Traversals
  fuzzy.preorder()
  fuzzy.inorder()
  fuzzy.postorder()
  # Test Searching
  fuzzy.search()
  fuzzy.remove()

proc main() =
  var fuzzy: NBinaryFuzzer
  for _ in 0 ..< 100:
    fuzzy.test()

when isMainModule:
  main()
