import ../../[prelude, labeling, pivot]
# Import Header Widgets
import ../../widgets/button
import ../../widgets/menu/[base, popup]
import ../../layouts/level
# Import Builder Macros
import ../../../[builder, pack]

# ----------------------
# UX Dock Header Helpers
# ----------------------

proc away(state: ptr GUIState, pivot: ptr GUIStatePivot): bool =
  pivot[].capture(state)
  # Check if Dragging is Outside Enough
  let away0 = float32 getApp().font.asc shr 1
  result = pivot.away >= away0

proc inside(rect: GUIRect, x: int32): bool =
  let
    x0 = rect.x
    x1 = x0 + rect.w
  # Check if Inside Line
  x >= x0 and x <= x1

proc inplace(rect: GUIRect, y: int32): bool =
  let
    y0 = rect.y
    h0 = rect.h
  # Check if Inside Height Place
  y >= y0 - h0 and y <= y0 + (h0 * 2)

# ---------------
# UX Dock Content
# ---------------

icons "dock", 16:
  context := "context.svg"
  close := "close.svg"
  # Dock Folding
  fold := "fold.svg"
  visible := "visible.svg"
  fallback := "fallback.svg"

controller UXDockContent:
  attributes:
    title: string
    icon: CTXIconID
    # Content Attributes
    {.public.}:
      serial: uint32
      # Content Frame
      [w, h]: int16
      folded: bool
      # Content Widgets
      widget: GUIWidget
      menu: UXMenu
      # Content Callbacks
      onselect: GUICallbackEX[UXDockContent]
      ondetach: GUICallbackEX[UXDockContent]

  new dockcontent(title: string, icon: CTXIconID, widget: GUIWidget):
    result.title = title
    result.icon = icon
    # Content Widget
    result.widget = widget

  new dockcontent(title: string, widget: GUIWidget):
    result.title = title
    result.icon = iconFallback
    # Content Widget
    result.widget = widget

  proc select*() = send(self.onselect, self)
  proc detach*() = send(self.ondetach, self)

# ------------------
# UX Dock Header Tab
# ------------------

widget UXDockTab:
  attributes:
    content: UXDockContent
    lm: GUILabelMetrics
    # Dock Header Status
    current: ptr UXDockContent
    cursor: ptr UXDockTab
    # Tab Arrange
    x0: int32

  new docktab(content: UXDockContent):
    result.content = content
    result.flags = {wMouse}

  proc alone: bool {.inline.} =
    self.prev == nil and self.next == nil

  proc selected: bool {.inline.} =
    self.content == self.current[]

  method update =
    let
      m = addr self.metrics
      # Content Label Metrics
      co = self.content
      lm = metricsLabel(co.title, co.icon)
      pad = getApp().space.pad shl 1
    # Calculate Min Size
    m.minW = lm.icon + pad
    m.maxW = lm.w + pad
    m.minH = lm.h
    # Set Label Metrics
    self.lm = lm

  proc reorder(state: ptr GUIState) =
    let x = state.mx
    if inside(self.rect, x): discard
    # Find Previous Slibings
    elif x - self.x0 < 0 and not isNil(self.prev):
      for tab in reverse(self.prev):
        if inside(tab.rect, x):
          self.detach()
          tab.attachPrev(self)
          self.parent.send(wsLayout)
          # Found Slibbing
          break
    # Find Next Slibings
    elif x - self.x0 > 0 and not isNil(self.next):
      for tab in forward(self.next):
        if inside(tab.rect, x):
          self.detach()
          tab.attachNext(self)
          self.parent.send(wsLayout)
          # Found Slibbing
          break
    # Change Current Axis
    self.x0 = x

  method event(state: ptr GUIState) =
    self.cursor[] = self
    # Only Interact if Unique
    if self.alone: return
    let content {.cursor.} = self.content
    # Select Dock Content when Clicked if is not Same
    if state.kind == evCursorRelease and self.test(wHover):
      if self.current[] != content:
        content.select()
    # Manipulate Tab if Selected
    if self.selected and self.test(wGrab):
      if inplace(self.rect, state.my):
        self.reorder(state)
      # Detach Content if Not in Height
      else: content.detach()

  method draw(ctx: ptr CTXRender) =
    let
      app = getApp()
      colors = app.colors
      # Content Label Metrics
      co {.cursor.} = self.content
      p = left(self.lm, self.rect)
      pad = app.space.pad
    # Decide Background Color
    var color: CTXColor
    if self.alone: discard
    elif self.selected:
      color = colors.focus
    elif self.test(wHover):
      color = colors.item
    # Fill Background Color
    ctx.color(color)
    ctx.fill rect(self.rect)
    # Draw Tab Icon
    ctx.color(colors.text)
    ctx.icon(co.icon, p.xi + pad, p.yi)
    # Draw Tab Label if has Enough Width
    if self.metrics.w >= self.metrics.maxW:
      ctx.text(p.xt + pad, p.yt, co.title)

  method handle(reason: GUIHandle) =
    let cursor = self.cursor
    # Change Selected Tab
    if reason == inHover: cursor[] = self
    elif reason == outHover: cursor[] = nil

# ----------------------
# UX Dock Header Tabbing
# ----------------------

widget UXDockTabbing:
  attributes:
    pivot: ptr GUIStatePivot
    onhead: ptr GUICallback
    onfold: ptr GUICallback
    current: ptr UXDockContent
    # Tab Dispatched
    {.cursor.}:
      cursor: UXDockTab
    # Min Size Levels
    min0: int32 # Icons + Labels
    min1: int32 # Selected Icon + Label
    min2: int32 # Icons Only

  new docktabbing():
    result.flags = {wMouse}
    result.kind = wkForward

  proc configure(tab: UXDockTab) =
    tab.current = self.current
    tab.cursor = addr self.cursor

  method update =
    let content {.cursor.} = self.current[]
    # Calculate Minimun Size
    var min0, min1, min2, h: int16
    for w0 in forward(self.first):
      let
        tab {.cursor.} = UXDockTab(w0)
        m = addr tab.metrics
      # Configure Dock Tab
      self.configure(tab)
      # Calculate Endpoints
      min0 += m.maxW
      min2 += m.minW
      # Calculate Partial Minified
      if tab.content != content:
        min1 += m.minW
      else: min1 += m.maxW
      # Calculate Minimun Height
      h = max(h, tab.metrics.minH)
    # Change Minimun Endpoints
    self.min0 = min0
    self.min1 = min1
    self.min2 = min2
    # Change Minimun Metric
    self.metrics.minW = min2
    self.metrics.minH = h

  proc level(): int32 =
    result = 2
    # Check Minimun Range
    let w = self.metrics.w
    result -= int32(w >= self.min1)
    result -= int32(w >= self.min0)

  method layout =
    let
      h = self.metrics.minH
      content {.cursor.} = self.current[]
      level = self.level()
    # Locate Tab Widgets
    var x: int16
    for w0 in forward(self.first):
      let
        tab {.cursor.} = UXDockTab(w0)
        selected = tab.content == content
        m = addr tab.metrics
      # Decide Width Size
      var w = m.minW
      if level == 0 or (level == 1 and selected):
        w = m.maxW
      # Locate Tab Widget
      m.x = x; m.y = 0
      m.w = w; m.h = h
      # Next Tab Widget
      x += w

  method event(state: ptr GUIState) =
    let
      cursor {.cursor.} = self.cursor
      pivot = self.pivot
      # Check if Was Dragged Away and not Selected
      alone = self.first == self.last
      nothing = isNil(cursor) or not cursor.selected()
      check = state.away(pivot)
    # Move Widget Frame
    if check and (nothing or alone):
      self.onhead[].send()
      self.send(wsStop)
    # Fold Widget Frame when Double Clicked
    elif not nothing or alone:
      if pivot.clicks == 2:
        self.onfold[].send()
      else: return
    # Reset Pivot Clicks
    pivot.clicks = 0

  method handle(reason: GUIHandle) =
    if reason in {inHover, outHover}:
      self.pivot.clicks = 0

# ----------------------
# UX Dock Header Buttons
# ----------------------

widget UXDockButtons of UXLayoutHLevel:
  attributes:
    {.cursor.}:
      btnFold: UXButtonCB
      btnClose: UXButtonCB
      btnMenu: UXButtonCB
    # Callback Manager
    {.public.}:
      onfold: GUICallback
      onclose: GUICallback
    # Dock Manipulation
    pivot: ptr GUIStatePivot
    onhead: ptr GUICallback
    menu: ptr UXMenuMapper

  proc cb0fold = force(self.onfold)
  proc cb0close = force(self.onclose)

  callback cbMenu:
    let map = self.menu
    if isNil(map.menu): return
    # Locate Menu to Button
    map.pivot.mode = menuVerticalSimple
    map[].locate(self.btnMenu.rect)
    map[].open()

  new dockbuttons():
    let
      # Create Buttons Callback
      self0 = cast[pointer](result)
      cbFold = unsafeCallback(self0, cb0fold)
      cbClose = unsafeCallback(self0, cb0close)
      # Create Widget Buttons
      btnClose = button(iconClose, cbClose)
      btnFold = button(iconFold, cbFold)
      btnMenu = button(iconContext, result.cbMenu)
    # Create Buttons Layout
    result.add btnClose.clear()
    result.add btnFold.clear()
    result.add btnMenu.clear()
    # Define Widget Buttons
    result.btnMenu = btnMenu
    result.btnFold = btnFold
    result.btnClose = btnClose
    # Define Widget Kind
    result.kind = wkForward
    result.flags = {wMouse}

  proc updateButtons*(folded: bool) =
    privateAccess(UXButtonBase)
    # Change Fold Icon
    self.btnFold.icon =
      if folded: iconFold
      else: iconVisible

  method event(state: ptr GUIState) =
    if state.away(self.pivot):
      self.onhead[].send()
      self.send(wsStop)

# --------------
# UX Dock Header
# --------------

widget UXDockHeader:
  attributes:
    tabs: UXDockTabbing
    menu: UXMenuMapper
    # Header Configurable
    {.public.}:
      pivot: GUIStatePivot
      buttons: UXDockButtons
      # Header Dock Content
      content: UXDockContent
      onhead: GUICallback

  new dockheader():
    result.kind = wkContainer
    # Create Dock Widgets
    let
      tabs = docktabbing()
      buttons = dockbuttons()
    # Configure Dock Tabs
    tabs.pivot = addr result.pivot
    tabs.onhead = addr result.onhead
    tabs.onfold = addr buttons.onfold
    tabs.current = addr result.content
    # Configure Dock Buttons
    buttons.pivot = addr result.pivot
    buttons.onhead = addr result.onhead
    buttons.menu = addr result.menu
    # Add Dock Widgets
    result.add(tabs)
    result.add(buttons)
    # Store Dock Content
    result.tabs = tabs
    result.buttons = buttons

  proc add*(content: UXDockContent) =
    let tab = docktab(content)
    self.tabs.add(tab)

  # -- Widget Methods --
  method update =
    let
      m = addr self.metrics
      tabs = addr self.tabs.metrics
      # Folded Content Check
      content {.cursor.} = self.content
      folded = isNil(content) or content.folded
    # Update Header Buttons
    self.buttons.updateButtons(folded)
    self.menu = map(content.menu)
    # Calculate Minimum Height
    m.minH = tabs.minH

  method layout =
    let
      m = addr self.metrics
      tabs = addr self.tabs.metrics
      lvl = addr self.last.metrics
    # Arrange Buttons to Right
    lvl.x = m.w - lvl.minW
    lvl.w = lvl.minW
    lvl.h = m.minH
    # Arrange Tabs to Left
    tabs.w = lvl.x
    tabs.h = m.minH
