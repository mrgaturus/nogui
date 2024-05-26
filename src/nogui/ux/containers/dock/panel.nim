import base, session
# Dock Widget Creations
import ../../layouts/base
import ../../prelude

# -------------
# UX Dock Panel
# -------------

widget UXDockPanel:
  attributes:
    folded: bool
    r0: GUIRect
    # Dock Widgets
    {.cursor.}:
      header: UXDockHeader
      widget: GUIWidget
    # Dock Current Content
    content: UXDockContent

  callback cbClose:
    self.header.detach(self.content)
    let content = self.header.content
    # Detach or Select Content
    if isNil(content):
      self.detach()
    else: content.select()

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
    # Change Dock Folded
    self.folded = folded
    content.folded = folded
    # Relayout Dock Widgets
    self.send(wsLayout)

  # -- Dock Panel Manipulation --
  callback cbMove:
    let
      state = getApp().state
      pivot = addr self.header.pivot
      r0 = addr self.r0
      r1 = addr self.parent.rect
    # Backup Dock Rect
    if pivot.locked:
      self.r0 = self.rect
      pivot.locked = false
    # Calculate Cursor Delta
    let
      dx = state.mx - pivot.mx
      dy = state.my - pivot.my
    # Locate New Window Position
    let m = addr self.metrics
    m.x = int16(r0.x + dx - r1.x)
    m.y = int16(r0.y + dy - r1.y)
    # Relayout Widget
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
    # Store Content Dimensions
    if not isNil(self.content):
      self.content.w = m.w
      self.content.h = m.h
    # Use Content Dimensions
    m.w = content.w
    m.h = content.h
    # Replace Header Selected
    self.header.content = content[]
    self.content = content[]
    # Relayout Dock Panel
    self.relax(wsLayout)

  # -- Dock Panel Creation --
  new dockpanel():
    let
      header = dockheader()
      widget = dummy()
    # Configure Dock Header
    header.onhead = result.cbMove
    header.buttons.onfold = result.cbFold
    header.buttons.onclose = result.cbClose
    # Configure Dock Kind
    result.kind = wkForward
    result.flags = {wMouse}
    # Configure Widgets to Panel
    result.add(header)
    result.add(widget)
    # Configure Dock Widgets
    result.header = header
    result.widget = widget

  # -- Dock Panel Methods --
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
    if not self.folded:
      m1.x = m0.x
      m1.w = m0.w
      m1.y = m0.y + m0.h + pad
      m1.h = m.h - m1.y - pad0

  method event(state: ptr GUIState) =
    if state.kind == evCursorClick:
      let session = cast[UXDockSession](self.parent)
      session.elevate(self)

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
    pivot = addr self.header.pivot
  # Add Content to Panel
  panel.add(c0)
  GC_unref(c0)
  # Locate at the same Pivot
  panel.header.pivot = pivot[]
  pivot[].wasMoved()
  # Locate at the same Metrics
  panel.metrics = self.metrics
  panel.rect = self.rect
  send(panel.cbMove)
  # Attach to Last Session
  self.parent.add(panel)
  self.parent.send(wsLayout)
  # Continue Grabbing Window
  getWindow().send(wsUnHover)
  getApp().state.kind = evCursorClick
  panel.send(wsForward)

proc detach0(self: UXDockPanel, content: ptr UXDockContent) =
  let
    c0 = content[]
    header = self.header
    pivot = addr header.pivot
    # Extract Callback
    cbExtract = self.cb0(extract0)
  # Remove Selected Content
  header.detach(c0)
  header.content.select()
  # Create New Dock
  if pivot.locked:
    GC_ref(c0)
    send(cbExtract, c0)

proc add*(self: UXDockPanel, content: UXDockContent) =
  let cbDetach = self.cb0(detach0)
  # Define Context Callbacks
  content.onselect = self.cbSelect
  content.ondetach = cbDetach
  # Add and Select Content
  self.header.add(content)
  content.select()
