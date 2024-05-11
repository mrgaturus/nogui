import ../../../core/shortcut
import ../../containers/scroll
import base, items

# dear imgui: imgui.cpp: ImTriangleContainsPoint
proc inside(a, b, c, p: CTXPoint): bool =
  let
    b1 = ((p.x - b.x) * (a.y - b.y) - (p.y - b.y) * (a.x - b.x)) < 0.0
    b2 = ((p.x - c.x) * (b.y - c.y) - (p.y - c.y) * (b.x - c.x)) < 0.0
    b3 = ((p.x - a.x) * (c.y - a.y) - (p.y - a.y) * (c.x - a.x)) < 0.0
  # Check Point Inside Triangle
  (b1 == b2) and (b2 == b3)

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
    self.metrics.fit(width, y)

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
    pivot: UXMenuPivot
    watchdog: GUIObserver
    # Triangle Aim
    p0: CTXPoint
    [aim, listed]: bool
    # Menu List
    {.cursor.}:
      list: UXMenuList
      view: UXScrollview

  callback cbNear:
    self.aim = false

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

  new menu(label: string):
    result.kind = wkPopup
    result.flags = {wMouse, wKeyboard}
    result.label = label
    # Define Slot Done Callback
    result.slot.ondone = result.cbClose
    let obs = observer(result.cbWatchResize, {evWindowResize})
    result.watchdog = obs

  # -- Menu Configure --
  proc map*: UXMenuMapper =
    result.menu = self
    result.cb = self.cbPivot

  proc warp(w0: GUIWidget) =
    # Warp menu into a menuitem
    var w {.cursor.} = w0
    if w.vtable == self.vtable:
      let 
        w0 = cast[UXMenu](w)
        item = menuitem(w0.label, w0.map)
      # Warp into Item
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
    self.apply(self.pivot)
    # Adjust to Minimum Scrollview Size
    if h0 != m0.h and w0 == m0.w:
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

  proc nearly(state: ptr GUIState): bool =
    let
      top {.cursor.} = self.top
      r = rect(self.rect)
      # Nearly Triangle
      a = point(r.x0, r.y0)
      b = point(r.x0, r.y1)
      p = point(state.px, state.py)
    # Check Point Inside Top Menu
    let area = top.pointOnArea(state.mx, state.my)
    if not area or self.vtable != top.vtable:
      self.aim = false
    # Calculate Current Point
    elif not inside(a, b, self.p0, p):
      result = true
    # Reduce Nearly
    self.p0 = p

  method event(state: ptr GUIState) =
    let
      top {.cursor.} = self.top
      outside = not self.test(wHover)
    # Handle Outside Click
    if isNil(top) and outside:
      var flags = self.flags
      if state.kind == evCursorClick:
        getWindow().send(wsUnGrab)
        flags.incl(wHold)
      elif state.kind == evCursorRelease and wHold in flags:
        self.send(wsClose)
        flags.excl(wHold)
      # Replace Flags
      self.flags = flags
    # Avoid Stole Grabbed
    elif self.test(wGrab):
      return
    # Propagate Event to Outside
    elif outside and not isNil(top):
      if self.nearly(state) or not self.aim:
        top.send(wsForward)
        # Renew Nearout Timer
        timestop(self.cbNear)
        timeout(self.cbNear, 250)

  method handle(reason: GUIHandle) =
    if reason == inFrame:
      let
        state = getApp().state
        obs = getWindow().observers
      # Configure Menu Triangle Point
      self.p0 = point(state.px, state.py)
      self.aim = true
      # Register Resize Watchdog
      obs[].register(self.watchdog)
    elif reason == outFrame:
      timestop(self.cbNear)
      self.slot.unselect()
      self.aim = false
      # Unregister Resize Watchdog
      self.flags.excl(wHold)
      unregister(self.watchdog)
