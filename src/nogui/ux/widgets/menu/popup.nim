import ../../../core/shortcut
import ../../containers/scroll
import base, items

# -------------
# GUI Menu List
# -------------

widget UXMenuList:
  attributes:
    menu: UXMenuOpaque

  proc stole(menu: UXMenuOpaque) =
    let m = GUIWidget(menu)
    self.first = m.first
    self.last = m.last
    # Configure Parent for Children
    for w in forward(m.first):
      w.parent = self
    # Clear Menu Children
    m.first = nil
    m.last = nil

  new menulist(menu: UXMenuOpaque):
    result.kind = wkLayout
    # Stole Menu Children
    result.stole(menu)
    result.menu = menu

  method update =
    # Initial Max Width
    var y, width: int16
    width = self.metrics.w
    # Calculate Max Width
    for w in forward(self.first):
      width = max(w.metrics.minW, width)
      y += w.metrics.minH
    # Fit Dimensions
    self.metrics.minfit(width, y)

  method layout =
    var y: int16
    # Width for each widget
    let width = self.parent.metrics.w
    # Arrange Each Widget
    for w in forward(self.first):
      let 
        metrics = addr w.metrics
        h = metrics.minH
      metrics.x = 0
      metrics.y = y
      metrics.w = width
      metrics.h = h
      # Step Height
      y += h

# --------------
# GUI Menu Popup
# --------------

widget UXMenu:
  attributes:
    top: GUIWidget
    label: string
    slot: UXMenuSlot
    # Menu Pivot Position
    pivot: UXMenuPivot
    watchdog: GUIObserver
    # Menu List
    listed: bool
    {.cursor.}:
      list: UXMenuList
      view: UXScrollview

  # -- Menu Toplevel --
  callback cbClose:
    self.send(wsClose)
    # Close Top Levels
    let top = self.top
    if not isNil(top) and top.vtable == self.vtable:
      let m = cast[UXMenu](top)
      send(m.cbClose)
    # Remove Selected
    self.slot.unselect()

  callback cbPivot(p: UXMenuPivot):
    let p0 = addr self.pivot
    if p0[] != p[] and self.test(wVisible):
      self.relax(wsLayout)
    # Change Pivot
    p0[] = p[]

  callback cbWatchResize:
    if self.test(wVisible):
      self.relax(wsLayout)

  # -- Menu Configure --
  new menu(label: string):
    result.kind = wkPopup
    result.flags = {wMouse, wKeyboard}
    result.label = label
    # Define Slot Done Callback
    result.slot.ondone = result.cbClose
    let obs = observer(result.cbWatchResize, {evWindowResize})
    result.watchdog = obs

  proc map*: UXMenuMapper =
    if isNil(self): return
    # Configure Menu Mapping
    result.menu = self
    result.cb = self.cbPivot

  proc warp(w0: GUIWidget) =
    # Warp menu into a menuitem
    var w {.cursor.} = w0
    if w.vtable == self.vtable:
      let 
        w0 = cast[UXMenu](w)
        item = menuitem(w0.label, w0.map)
      # Warp into MenuItem
      w0.top = self
      w0.replace(item)
      w = item
    # Bind Menu Slot With Item
    if w of UXMenuItem:
      let item = cast[UXMenuItem](w)
      item.slot = addr self.slot

  proc gather() =
    # Configure Menu List
    for widget in forward(self.first):
      self.warp(widget)
    # Warp Menu List Into Scroller
    let
      list = menulist(UXMenuOpaque self)
      view = scrollview(list)
    self.list = list
    self.view = view
    # Scrollview as Unique
    self.add(view)
    self.listed = true
    view.vtable.update(view)

  method update =
    let
      m0 = addr self.metrics
      border = getApp().space.line shl 1
    # Configure UXMenu Children
    if not self.listed:
      self.gather()
    # Fit Minimum Size
    var m1 = addr self.list.metrics
    m0.minW = m1.minW + border
    m0.minH = m1.minH + border
    m0.w = m0.minW
    m0.h = m0.minH
    # Apply Pivot Position
    let
      h0 = m0.h
      w0 = m0.w
      p0 = self.pivot.forced
    self.apply(self.pivot)
    # Adjust to Minimum Scrollview Size
    if h0 != m0.h and w0 == m0.w and p0 == 0:
      m1 = addr self.view.metrics
      m0.minW = m1.minW + border
      m0.w = m0.minW

  method layout =
    let
      m1 = addr self.view.metrics
      border = getApp().space.line
    m1[].fit(self.metrics)
    m1[].inset(border)

  # -- Menu Interaction --
  method draw(ctx: ptr CTXRender) =
    let 
      app = getApp()
      colors = addr app.colors
      border = float32(app.space.line)
      # Menu Fill Region
      rect = rect(self.rect)
    # Fill Menu Container
    ctx.color(colors.panel)
    ctx.fill(rect)
    ctx.color(colors.darker)
    ctx.line(rect, border)

  method event(state: ptr GUIState) =
    let
      top {.cursor.} = self.top
      forward = not isNil(top)
    # Avoid Disturb Submenu Grab
    if forward and top.test(wGrab):
      discard
    # Decide Widget Forward
    elif self.test(wHover):
      send(self.view, wsRedirect)
    elif forward:
      top.send(wsForward)
    # Fallback Outside Click
    else:
      var flags = self.flags
      if state.kind == evCursorClick:
        getWindow().send(wsUnGrab)
        flags.incl(wHold)
      elif state.kind == evCursorRelease and wHold in flags:
        self.send(wsClose)
        flags.excl(wHold)
      # Replace Widget Flags
      self.flags = flags

  method handle(reason: GUIHandle) =
    let slot = addr self.slot
    # Process Handle Reason
    case reason
    of inFrame:
      let obs = getWindow().observers
      obs[].register(self.watchdog)
    of outFrame:
      slot[].reset()
      # Unregister Resize Watchdog
      self.flags.excl(wHold)
      unregister(self.watchdog)
    # Renew Selected Slot
    of inHover: slot.noslot = false
    of outHover: slot[].restore()
    else: discard
