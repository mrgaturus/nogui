import base, snap
# Dock Widget Creations
import ../../layouts/base
import ../../[prelude, pivot]

# -------------
# UX Dock Panel
# -------------

widget UXDockPanel:
  attributes:
    pivot: DockPivot
    content: UXDockContent
    # Dock Widgets
    {.cursor.}:
      header: UXDockHeader
      widget: GUIWidget
    # Dock Session Watcher
    {.public, cursor.}:
      onwatch: GUICallbackEX[UXDockPanel]

  proc grouped*: bool {.inline.} =
    let parent {.cursor.} = self.parent
    not isNil(parent) and parent.kind == wkLayout

  proc unique*: bool {.inline.} =
    let tab {.cursor.} = self.content.tab
    isNil(tab) or tab.next == tab.prev

  callback cbClose:
    var content = self.content
    # Detach Current Tab
    if not self.unique:
      self.header.detach(content)
      content = self.header.content
      content.select()
      return
    # Dismiss Content
    content.dismiss()
    # Watch Dock Closing
    self.flags.excl(wMouse)
    force(self.onwatch, addr self)

  callback cbFold:
    let
      content {.cursor.} = self.content
      folded = not content.folded
      m = addr self.metrics
    # Backup Dock Dimensions
    if folded:
      content.w = m.w
      content.h = m.h
    else:
      m.w = content.w
      m.h = content.h
    # Update Dock Panel Layout
    content.folded = folded
    self.send(wsLayout)

  callback cbSelect(content: UXDockContent):
    let
      m = addr self.metrics
      # Content Widget
      w0 = self.widget
      w = content.widget
    if w0 != w:
      w0.replace(w)
      self.widget = w
    # Use Content Dimensions
    m.w = content.w
    m.h = content.h
    # Replace Header Selected
    self.header.content = content[]
    self.content = content[]
    # Relayout Dock Panel
    let stick = self.pivot.stick
    var s {.cursor.}: GUIWidget = self
    if self.grouped or stick in {dockLeft, dockRight}:
      s = s.parent
    s.relax(wsLayout)

  # -- Dock Panel Creation --
  new dockpanel():
    let
      header = dockheader()
      widget = dummy()
    # Configure Dock Header
    header.buttons.onfold = result.cbFold
    header.buttons.onclose = result.cbClose
    # Configure Dock Kind
    result.kind = wkWidget
    result.flags = {wMouse}
    # Configure Widgets to Panel
    result.add(header)
    result.add(widget)
    # Configure Dock Widgets
    result.header = header
    result.widget = widget

  # -- Dock Panel Layout --
  method update =
    let
      folded = self.content.folded
      w {.cursor.} = self.widget
      # Dock Widget Metrics
      m = addr self.metrics
      m0 = addr self.header.metrics
      m1 = addr self.widget.metrics
      # Dock Padding Metric
      pad = getApp().space.margin
      pad0 = (pad shl 1) + pad
    # Calculate Minimun Size
    m.minW = max(m0.minW, m1.minW) + pad0
    m.minH = m0.minH + pad0
    # Check Content Folded
    if not folded: 
      w.flags.excl(wHidden)
      m.minH += m1.minH + pad
    else: # Fold Dock Height
      w.flags.incl(wHidden)
      m.h = m.minH
    # Clamp Minimun Size
    m.w = max(m.w, m.minW)
    m.h = max(m.h, m.minH)

  method layout =
    let
      content {.cursor.} = self.content
      pad = getApp().space.margin
      pad0 = pad + (pad shr 1)
      # Dock Widget Metrics
      m = addr self.metrics
      m1 = addr self.widget.metrics
      m0 = addr self.header.metrics
    # Locate Header Widget
    m0.x = pad0
    m0.y = pad0
    m0.w = m.w - (pad0 shl 1)
    m0.h = m0.minH
    # Locate Body Widget
    if not content.folded:
      m1.x = m0.x
      m1.w = m0.w
      m1.y = m0.y + m0.h + pad
      m1.h = m.h - m1.y - pad0
      # Update Content Dimensions
      content.w = m.w
      content.h = m.h

  # -- Dock Panel Interaction --
  proc geometry(state: ptr GUIState) =
    let
      pivot = addr self.pivot
      x = state.mx
      y = state.my
    # Move Dock Panel
    if pivot.sides == {}: discard
    elif state.kind == evCursorRelease: discard
    elif pivot.sides == {dockMove}:
      self.metrics = pivot[].move(x, y)
      self.relax(wsLayout)
      # Send Watch Dock
      send(self.onwatch, self)
    # Resize Dock Panel Metrics
    elif pivot.sides != {dockLocked}:
      self.metrics = pivot[].resize(x, y)
      self.relax(wsLayout)

  proc capture(state: ptr GUIState) =
    let
      win = getWindow()
      # Dock Panel Pivots
      p0 = addr self.pivot
      p1 = addr self.header.pivot
      locked = self.grouped or self.content.folded
    # Calculate Resize Pivot when not Grabbed
    if {wHover, wGrab} * self.flags == {wHover}:
      p0[].resize0(self, state.mx, state.my)
      p0[].restrict0()
    # Calculate Move Pivot
    p1[].capture(state)
    let away0 = getApp().font.asc shr 1
    if p0.sides == {} and p1.away > float32(away0):
      p0[].move0(self, p1.mx, p1.my)
    # Check if Panel is not Locked
    if p0.sides == {dockMove}: discard
    elif locked and p0.sides != {}:
      p0.sides = {dockLocked}
      return
    # Change Pivot Cursor
    win.cursor(p0[].cursor)

  proc redirect(widget: GUIWidget, state: ptr GUIState): bool =
    let
      inside = widget.pointOnArea(state.mx, state.my)
      grab = state.kind != evCursorClick and self.test(wGrab)
    # Redirect Only if not Grabbed and Inside
    result = inside and not grab
    if not result: return result
    # Reset Frame Pivot
    wasMoved(self.header.pivot)
    self.pivot.sides = {}
    # Redirect to Widget
    getWindow().cursorReset()
    widget.send(wsRedirect)

  method event(state: ptr GUIState) =
    let
      pivot = addr self.pivot
      widget {.cursor.} = self.widget
      header {.cursor.} = self.header
      # Content Selected Tab
      tab {.cursor.} = self.content.tab
      unique = tab.next == tab.prev
      grab = self.test(wGrab) or state.kind == evCursorRelease
      check = grab and (unique or {wGrab, wHover} * tab.flags == {})
    # Capture Selected Sides
    let sides = pivot.sides
    self.capture(state)
    # Check Selected Sides
    if sides != {} and check:
      self.geometry(state)
      self.send(wsStop)
    # Forward to Content Widget
    elif tab.test(wGrab): discard
    elif self.redirect(widget, state): discard
    elif header.pointOnArea(state.mx, state.my):
      header.send(wsForward)

  method handle(reason: GUIHandle) =
    if reason in {outGrab, outHover}:
      let
        tab {.cursor.} = self.content.tab
        moved = dockMove in self.pivot.sides
        check = isNil(tab) or wGrab in tab.flags
      if reason == outGrab and moved and not check:
        send(self.onwatch, self)
      # Reset Pivot if not Grab and Hover
      if {wGrab, wHover} * self.flags == {}:
        wasMoved(self.header.pivot)
        self.pivot.sides = {}
        # Reset Cursor
        getWindow().cursorReset()

  # -- Dock Panel Background --
  method draw(ctx: ptr CTXRender) =
    let 
      colors = addr getApp().colors
      # Calculate Dock Outer Margin
      pad0 = getApp().space.margin shr 1
      pad1 = pad0 shl 1
    # Inset Background Rect
    var rect = self.rect
    rect.x += pad0; rect.y += pad0
    rect.w -= pad1; rect.h -= pad1
    # Draw Background Rect
    ctx.color colors.panel and 0xF0FFFFFF'u32
    ctx.fill rect(rect)

# ----------------------------
# UX Dock Panel Attach/Dettach
# ----------------------------

proc add*(self: UXDockPanel, content: UXDockContent)
template cb0(self: UXDockPanel, fn: proc): GUICallbackEX[UXDockContent] =
  let self0 = cast[pointer](self)
  unsafeCallbackEX[UXDockContent](self0, fn)

proc extract0(self: UXDockPanel, content: ptr UXDockContent) =
  let
    c0 = content[]
    panel = dockpanel()
    header {.cursor.} = self.header
  # Add Content to Panel
  panel.add(c0)
  GC_unref(c0)
  # Locate at the same Metrics
  panel.header.pivot = header.pivot
  panel.pivot = self.pivot
  panel.metrics = self.metrics
  panel.rect = self.rect
  # Clear Panel Pivot
  wasMoved(header.pivot)
  self.pivot.sides = {}
  # Attach to Session Last
  self.parent.add(panel)
  # Continue Grabbing Window
  getWindow().send(wsUnHover)
  panel.onwatch = self.onwatch
  panel.send(wsForward)

proc detach0(self: UXDockPanel, content: ptr UXDockContent) =
  let
    c0 = content[]
    header = self.header
  # Close Window if Unique
  if self.unique:
    force(self.cbClose)
    return
  # Remove Selected Content
  header.detach(c0)
  header.content.select()
  # Extract to New Panel if Dragging
  if self.pivot.sides == {dockMove}:
    let cbExtract = self.cb0(extract0)
    send(cbExtract, c0)
    GC_ref(c0)

proc add*(self: UXDockPanel, content: UXDockContent) =
  let cbDetach = self.cb0(detach0)
  # Define Context Callbacks
  content.onselect = self.cbSelect
  content.ondetach = cbDetach
  # Add and Select Content
  self.header.add(content)
  content.select()
