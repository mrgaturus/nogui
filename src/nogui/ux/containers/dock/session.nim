import ../../prelude
from ../../../core/tree import inside
import group, panel, snap

# ------------
# UX Dock Hint
# ------------

widget UXDockHint:
  new dockhint():
    # Show As Tooltip
    result.kind = wkTooltip
  
  proc locate(r: GUIRect) =
    # Locate Hightlight
    let m = addr self.metrics
    m.x = int16 r.x
    m.y = int16 r.y
    m.w = int16 r.w
    m.h = int16 r.h
    # Show Dock Hint
    if self.test(wVisible):
      self.send(wsLayout)
    else: self.send(wsOpen)

  proc show(rect: GUIRect, x, y: int32, side: DockSide) =
    let r = groupHint(rect, side)
    self.locate(r)

  proc show(panel: UXDockPanel, x, y: int32, side: DockSide) =
    var r = groupHint(panel.rect, side)
    # Extend Hightlight to Row
    if panel.grouped and side in {dockLeft, dockRight}:
      let r0 = addr panel.parent.rect
      r.y = r0.y
      r.h = r0.h
    # Show Dock Hint
    self.locate(r)

  method draw(ctx: ptr CTXRender) =
    const mask = 0xE0FFFFFF'u32
    let colors = addr getApp().colors
    ctx.color colors.text and mask
    ctx.fill rect(self.rect)

# -----------------
# UX Dock Container
# -----------------

widget UXDockContainer:
  attributes:
    hint: UXDockHint
    {.cursor.}:
      [l0, r0]: GUIWidget
    # Container Sticky
    {.public, cursor.}:
      left: GUIWidget
      right: GUIWidget

  new dockcontainer():
    result.kind = wkContainer
    result.hint = dockhint()

  # -- Dock Panel Grouper --
  proc tabAppend(target, panel: UXDockPanel) =
    privateAccess(UXDockPanel)
    if not panel.unique: return
    # Destroy Panel
    panel.detach()
    panel.flags.excl(wVisible)
    # Append Content to Target
    target.add(panel.content)
    self.relax(wsLayout)

  proc groupAppend(target, panel: UXDockPanel, side: DockSide) =
    let row {.cursor.} = target.parent
    panel.detach()
    # Attach Panel to Group
    case side
    of dockTop: target.attachPrev(panel)
    of dockDown: target.attachNext(panel)
    of dockLeft, dockRight:
      let row0 = dockrow()
      row0.metrics = panel.metrics
      row0.add(panel)
      # Attach Created Row
      if side == dockLeft:
        row.attachPrev(row0)
      else: row.attachNext(row0)
    else: discard
    # Relayout Container
    self.relax(wsLayout)

  proc groupCreate(target, panel: UXDockPanel, side: DockSide) =
    let
      row = dockrow()
      columns = dockcolumns()
      group = dockgroup(columns)
      bar {.cursor.} = group.last
      # Group Metrics
      m0 = addr group.metrics
      m1 = addr target.metrics
    # Calculate Group Metrics
    self.add(group)
    bar.vtable.update(bar)
    group.vtable.update(group)
    row.metrics = m1[]
    # Assemble Dock Group
    target.detach()
    row.add(target)
    columns.add(row)
    # Append Panel to Group
    m0.x = m1.x; m0.w = m1.w
    m0.y = max(m1.y - m0.h, 0)
    self.groupAppend(target, panel, side)
    # Change Current Sticky
    let widget {.cursor.} = cast[GUIWidget](target)
    if widget == self.left:
      self.left = group
    elif widget == self.right:
      self.right = group

  proc groupExit(panel: UXDockPanel) =
    let
      row {.cursor.} = panel.parent
      columns {.cursor.} = row.parent
      group {.cursor.} = columns.parent
    # Detach Dock Panel
    panel.detach()
    if panel.test(wMouse):
      self.add(panel)
    # Detach Dock Row if Empty
    if isNil(row.first) and isNil(row.last):
      row.detach()
    # Detach Dock Group if is Dangling
    let row0 {.cursor.} = columns.first
    if not isNil(row0) and row0.next == row0.prev and row0.first == row0.last:
      let dangle = cast[UXDockPanel](row0.first)
      columns.vtable.update(columns)
      group.vtable.update(group)
      # Detach Dangle Panel
      if not isNil(dangle):
        let rect = addr dangle.rect
        rect.x = self.rect.x + group.metrics.x
        rect.y = columns.rect.y
        self.groupExit(dangle)
      # Detach Group
      group.detach()
      if group == self.left:
        self.left = dangle
        self.l0 = nil
      elif group == self.right:
        self.right = dangle
        self.r0 = nil
    # Adjust Panel Metrics
    let
      m = addr panel.metrics
      r1 = addr panel.rect
      r0 = addr self.rect
    # Exit Position from Row
    m.x = int16(r1.x - r0.x)
    m.y = int16(r1.y - r0.y)
    # Update Pivot Metrics
    privateAccess(UXDockPanel)
    panel.pivot.metrics = m[]
    self.relax(wsLayout)

  # -- Dock Panel Snapping --
  proc snap(panel: GUIWidget) =
    let m = addr panel.metrics
    # Apply Widget Snapping
    for dock in reverse(self.last):
      if dock == panel: continue
      let s = snap(panel, dock)
      m.x = s.x
      m.y = s.y

  proc group(target, panel: UXDockPanel, state: ptr GUIState) =
    let
      x = state.mx
      y = state.my
      hint {.cursor.} = self.hint
      side = groupSide(target.rect, x, y)
    # Hightlight Dock Hint
    if side == dockNothing and not panel.unique: discard
    elif state.kind != evCursorRelease:
      hint.show(target, x, y, side)
      return
    # Attach Dock to Tab
    elif side == dockNothing:
      self.tabAppend(target, panel)
    # Attach Dock to Group
    elif target.grouped:
      self.groupAppend(target, panel, side)
    else: self.groupCreate(target, panel, side)
    # Close Watch Hint
    hint.send(wsClose)

  proc stick(panel: GUIWidget, state: ptr GUIState) =
    let
      x = state.mx
      y = state.my
      hint {.cursor.} = self.hint
      side = groupSide(self.rect, x, y)
    # Check if Side is Inside and not Already Attached
    if side == dockRight and not isNil(self.right): discard
    elif side == dockLeft and not isNil(self.left): discard
    elif side in {dockLeft, dockRight}:
      if state.kind != evCursorRelease:
        hint.show(self.rect, x, y, side)
        return
      # Stick on Container Side
      if side == dockRight: self.right = panel
      elif side == dockLeft: self.left = panel
      self.relax(wsLayout)
    # Close Watch Hint
    hint.send(wsClose)

  # -- Dock Panel Watcher --
  callback watchDock(dog: UXDockPanel):
    let
      dock = dog[]
      state = getApp().state
      widget {.cursor.} = cast[GUIWidget](dock)
      # Cursor Position
      x = state.mx
      y = state.my
    # Remove From Group
    if dock.grouped:
      self.groupExit(dock)
      return
    elif widget == self.left:
      self.left = nil
      self.relax(wsLayout)
    elif widget == self.right:
      self.right = nil
      self.relax(wsLayout)
    # Apply Snapping
    self.snap(dock)
    # Find Candidate Dock
    dock.flags.excl(wVisible)
    let found = self.inside(x, y)
    dock.flags.incl(wVisible)
    # Attach to Any Side
    if found.vtable == dock.vtable:
      let target {.cursor.} = cast[UXDockPanel](found)
      self.group(target, dock, state)
    elif found == self:
      self.stick(dock, state)
    # Close Hint Otherwise
    else: send(self.hint, wsClose)

  callback watchGroup(dog: UXDockGroup):
    let
      group {.cursor.} = dog[]
      widget {.cursor.} = cast[GUIWidget](group)
      state = getApp().state
    # Remove Current Sticky
    if widget == self.left:
      self.left = nil
      self.relax(wsLayout)
    elif widget == self.right:
      self.right = nil
      self.relax(wsLayout)
    # Apply Group Snapping
    self.snap(group)
    self.stick(group, state)

  # -- Dock Panel Watching --
  proc watch(panel: GUIWidget) =
    if isNil(panel): return
    # Access Private Pivot
    privateAccess(UXDockPanel)
    privateAccess(UXDockGroup)
    # Configure Sticky
    let stick =
      if panel == self.left: dockLeft
      elif panel == self.right: dockRight
      else: dockNothing
    # Configure Panel
    if panel of UXDockPanel:
      let p {.cursor.} = cast[UXDockPanel](panel)
      p.onwatch = self.watchDock
      p.pivot.clip = addr self.metrics
      p.pivot.stick = stick
    # Configure Group Watcher
    elif panel of UXDockGroup:
      let g {.cursor.} = cast[UXDockGroup](panel)
      g.onwatch = self.watchGroup
      g.pivot.clip = addr self.metrics
      g.pivot.stick = stick

  proc elevate(panel: GUIWidget) =
    assert panel.parent == self
    # Watch Elevated Widget
    self.watch(panel)
    if self.last == panel:
      return
    # Reattach to Last Widget
    GC_ref(panel)
    panel.detach()
    attachNext(self.last, panel)
    GC_unref(panel)

  method update =
    let
      left {.cursor.} = self.left
      right {.cursor.} = self.right
      # Previous Sticky
      l0 {.cursor.} = self.l0
      r0 {.cursor.} = self.r0
    # Configure New Left
    if left != l0:
      self.l0 = left
      self.watch(left)
      self.watch(l0)
    # Configure New Right
    if right != r0:
      self.r0 = right
      self.watch(right)
      self.watch(r0)

  method layout =
    let
      left {.cursor.} = self.left
      right {.cursor.} = self.right
    # Locate Left Sticky
    if not isNil(left):
      assert left.parent == self
      let m = addr left.metrics
      m.x = 0
      m.y = 0
    # Locate Right
    if not isNil(right):
      assert right.parent == self
      let m = addr right.metrics
      m.x = self.metrics.w - m.w
      m.y = 0

# ---------------
# UX Dock Session
# ---------------

widget UXDockSession:
  attributes:
    {.cursor.}:
      root: GUIWidget
    {.cursor, public.}:
      docks: UXDockContainer

  new docksession(root: GUIWidget):
    let docks = dockcontainer()
    # Define Session Widgets
    result.add(root)
    result.add(docks)
    result.root = root
    result.docks = docks
    # Define Session Hint
    result.flags = {wMouse}

  method update =
    let
      m0 = addr self.metrics
      m1 = addr self.root.metrics
    # Copy Root Min Size
    self.kind = wkWidget
    m0[].minfit m1[]

  method layout =
    let
      m = addr self.metrics
      # Dock Session Widgets
      m1 = addr self.root.metrics
      m2 = addr self.docks.metrics
    # Fit Widgets to Dock Session
    m1[].fit m[]
    m2[].fit m[]

  method event(state: ptr GUIState) =
    let
      docks = self.docks
      clicked = state.kind == evCursorClick
      grab = self.test(wGrab) or state.kind == evCursorRelease
    # Escape from Widget Grab
    if grab and not clicked:
      return
    # Find Container Widgets
    for dock in reverse(docks.last):
      if dock.pointOnArea(state.mx, state.my):
        if not (dock of UXDockGroup):
          if clicked: docks.elevate(dock)
          dock.send(wsForward)
          return
        # Forward Dock Group
        let
          group {.cursor.} = cast[UXDockGroup](dock)
          w = group.inside(state.mx, state.my)
        # Forward if Found Something
        if w.vtable != group.vtable:
          if clicked:
            docks.elevate(group)
            docks.watch(w)
          w.send(wsForward)
          return
    # Forward Root Widget
    send(self.root, wsForward)
