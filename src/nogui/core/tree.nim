import widget, render

# -------------------------
# Widget Tree Finder: Hover
# -------------------------

proc outside*(widget: GUIWidget): GUIWidget =
  result = widget
  # Walk to Outermost Parent
  while not isNil(result.parent):
    result = result.parent

proc inside*(widget: GUIWidget, x, y: int32): GUIWidget =
  result = widget.last
  if isNil(result):
    return widget
  # Find Children
  while true:
    # Enter Layout or Container Scope
    if result.pointOnArea(x, y):
      if isNil(result.last) or result.kind < wkLayout:
        return result
      else: result = result.last
    # Check Previous Widget
    elif isNil(result.prev):
      return result.parent
    else: result = result.prev

proc find*(pivot: GUIWidget, x, y: int32): GUIWidget =
  # Initial Widget
  result = pivot
  var w {.cursor.} = pivot
  # Point Inside All Parents?
  while w.parent != nil:
    if wHold in w.flags: break
    if not w.pointOnArea(x, y):
      result = w.parent
    w = w.parent
  # Find Inside of Outside
  result = inside(result, x, y)

# -------------------------
# Widget Tree Finder: Focus
# -------------------------

proc step*(pivot: GUIWidget, back: bool): GUIWidget =
  result = pivot
  # Check if is not a Toplevel Widget
  var outer {.cursor.} = pivot.parent
  if isNil(outer): return result
  # Find the Outermost Container
  while outer.kind < wkContainer:
    if isNil(outer.parent):
      break
    # Next Outermost
    outer = outer.parent
  # Find Next/Prev Focus
  while true:
    # Step Next Widget
    let top {.cursor.} = result.parent
    if back: result = result.prev
    else: result = result.next
    # Exit from Scope
    if isNil(result):
      result = top
      if result != outer:
        continue
    # Enter to Layout Scope
    while result.kind in {wkLayout, wkForward} or result == outer:
      var inside {.cursor.} = result
      # Locate at an Endpoint
      if back: inside = inside.last
      else: inside = inside.first
      if isNil(inside):
        break
      # Next Inside
      result = inside
    # Check Focusable Widget
    if result.kind > wkWidget: continue
    if {wVisible, wKeyboard} in result.flags or result == pivot:
      break

# --------------------------
# Widget Tree Walker: Layout
# --------------------------

proc absolute(widget: GUIWidget) =
  let
    rect = addr widget.rect
    metrics = addr widget.metrics
  var flags = widget.flags
  # Calcule Absolute Position
  rect.x = metrics.x
  rect.y = metrics.y
  # Calculate Absolute Size
  rect.w = metrics.w
  rect.h = metrics.h
  # Absolute is Relative when no parent
  if isNil(widget.parent): return
  # Move Absolute Position to Pivot
  let pivot = addr widget.parent.rect
  rect.x += pivot.x
  rect.y += pivot.y
  # Test Visibility Boundaries
  let test = (wHidden notin flags) and
    rect.x <= pivot.x + pivot.w and
    rect.y <= pivot.y + pivot.h and
    rect.x + rect.w >= pivot.x and
    rect.y + rect.h >= pivot.y
  # Mark Visible if Passed Visibility Test
  flags.excl(wVisible)
  if test: flags.incl(wVisible)
  # Replace Flags
  widget.flags = flags

proc prepare(widget: GUIWidget) =
  var w {.cursor.} = widget
  # Traverse Children
  while true:
    # Traverse Inside?
    if isNil(w.first):
      w.vtable.update(w)
    else:
      w = w.first
      continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      w = w.parent
      w.vtable.update(w)
    # Traverse Slibings?
    if w == widget: break
    else: w = w.next
    
proc organize(widget: GUIWidget) =
  var w {.cursor.} = widget
  # Traverse Children
  while true:
    w.absolute()
    # Is Visible?
    if wVisible in w.flags:
      w.vtable.layout(w)
      # Traverse Inside?
      if not isNil(w.first):
        w = w.first
        continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      w = w.parent
    # Traverse Slibings?
    if w == widget: break
    else: w = w.next

proc arrange*(widget: GUIWidget) =
  var
    w {.cursor.} = widget
    m = w.metrics
  # Prepare Widget
  w.prepare()
  # Propagate Metrics Changes to Parents
  while w.metrics != m and not isNil(w.parent):
    w = w.parent
    m = w.metrics
    # Prepare Widget
    w.vtable.update(w)
  # Layout Widgets
  w.organize()

# --------------------------
# Widget Tree Walker: Render
# --------------------------

proc render*(widget: GUIWidget, ctx: ptr CTXRender) =
  var w {.cursor.} = widget
  # Push Clipping
  ctx.push(w.rect)
  # Traverse Children
  while true:
    # Push Clipping
    if wVisible in w.flags:
      w.vtable.draw(w, ctx)
      # Traverse Children?
      if not isNil(w.first):
        if w.kind == wkContainer:
          ctx.push(w.rect)
        # Enter Scope
        w = w.first
        continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      w = w.parent
      # Remove Container Clipping
      if w.kind == wkContainer:
        ctx.pop()
    # Traverse Slibings?
    if w == widget: break
    else: w = w.next
  # Pop Clipping
  ctx.pop()
