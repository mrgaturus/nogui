import widget, render, metrics

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

proc find*(pivot, outer: GUIWidget, x, y: int32): GUIWidget =
  # Initial Widget
  result = pivot
  var w {.cursor.} = pivot
  # Point Inside All Parents?
  while w != outer:
    if not w.pointOnArea(x, y):
      result = w.parent
    w = w.parent
  # Find Inside of Outside Pivot
  if result == outer or result.kind >= wkLayout:
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

proc cull(widget: GUIWidget, clip: GUIClipping) =
  let
    scope = clip.peek()
    # Check if is not Hidden and Inside or Toplevel
    check0 = wHidden notin widget.flags
    check1 = inside(widget.rect, scope)
    check2 = isNil(widget.parent)
  # Check Culling Visibility
  var flags = widget.flags
  flags.excl(wVisible)
  if check0 and (check1 or check2):
    flags.incl(wVisible)
  # Replace Widget Flags
  widget.flags = flags

proc absolute(widget: GUIWidget, clip: GUIClipping) =
  let
    rect = addr widget.rect
    metrics = addr widget.metrics
  # Prepare Absolute Metrics
  rect.x = metrics.x
  rect.y = metrics.y
  rect.w = metrics.w
  rect.h = metrics.h
  # Calculate Absolute Position
  if not isNil(widget.parent):
    let pivot = addr widget.parent.rect
    rect.x += pivot.x
    rect.y += pivot.y
  # Calculate Absolute Culling
  widget.cull(clip)

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
  var
    w {.cursor.} = widget
    w0 {.cursor.} = w.parent
    clip: GUIClipping
  # Accumulate Parents Clip
  while not isNil(w0):
    if w0.kind >= wkContainer:
      clip.push(w0.rect)
    # Next Parent
    w0 = w0.parent
  # Traverse Children
  while true:
    w.absolute(clip)
    # Arrange Widget if Visible
    if wVisible in w.flags:
      w.vtable.layout(w)
      # Traverse Children?
      if not isNil(w.first):
        if w.kind >= wkContainer:
          clip.push(w.rect)
        # Enter Scope
        w = w.first
        continue
    # Traverse Parents?
    while isNil(w.next) and w != widget:
      w = w.parent
      # Remove Container Clipping
      if w.kind >= wkContainer:
        clip.pop()
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
