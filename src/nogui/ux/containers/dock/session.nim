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
  
  proc show(panel: UXDockPanel, x, y: int32, side: DockSide) =
    let r = groupHint(panel.rect, side)
    # Locate Hightlight
    let m = addr self.metrics
    m.x = int16 r.x
    m.y = int16 r.y
    m.w = int16 r.w
    m.h = int16 r.h
    # Extend Hightlight to Row
    if panel.grouped and side in {dockLeft, dockRight}:
      let r0 = addr panel.parent.rect
      m.y = int16 r0.y
      m.h = int16 r0.h
    # Show Dock Hint
    if self.test(wVisible):
      self.send(wsLayout)
    else: self.send(wsOpen)

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

  new dockcontainer():
    result.kind = wkContainer
    result.hint = dockhint()

  # -- Dock Panel Snapping --
  proc snap(panel: GUIWidget) =
    let m = addr panel.metrics
    # Apply Widget Snapping
    for dock in reverse(self.last):
      if dock == panel: continue
      let s = snap(panel, dock)
      m.x = s.x
      m.y = s.y

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
    # Detach Target
    target.detach()
    # Assemble Dock Group
    row.add(target)
    columns.add(row)
    self.add(group)
    # Append Panel to Group
    group.metrics.x = target.metrics.x
    group.metrics.y = target.metrics.y
    self.groupAppend(target, panel, side)

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
      if not isNil(dangle):
        dangle.rect.x = columns.rect.x
        dangle.rect.y = columns.rect.y
        self.groupExit(dangle)
      # Detach Group
      group.detach()
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

  # -- Dock Panel Watcher --
  callback watchDock(dog: UXDockPanel):
    let
      dock = dog[]
      hint = self.hint
      state = getApp().state
      # Cursor Position
      x = state.mx
      y = state.my
    # Remove From Group
    if dock.grouped:
      self.groupExit(dock)
      return
    # Apply Panel Snapping
    self.snap(dock)
    # Find Candidate Dock
    dock.flags.excl(wVisible)
    let found = self.inside(x, y)
    dock.flags.incl(wVisible)
    # Check Hint Sides
    if found.vtable == dock.vtable:
      let
        fo {.cursor.} = cast[UXDockPanel](found)
        side = groupSide(fo.rect, x, y)
      # Hightlight Dock Hint
      if side == dockNothing and not dock.unique: discard
      elif state.kind != evCursorRelease:
        hint.show(fo, x, y, side)
        return
      # Attach Dock to Tab/Group
      elif side == dockNothing:
        self.tabAppend(fo, dock)
      elif fo.grouped:
        self.groupAppend(fo, dock, side)
      else: self.groupCreate(fo, dock, side)
    # Close Watch Hint
    hint.send(wsClose)

  callback watchGroup(dog: UXDockGroup):
    let group {.cursor.} = dog[]
    # Apply Group Snapping
    self.snap(group)

  proc watch(panel: GUIWidget) =
    privateAccess(UXDockPanel)
    privateAccess(UXDockGroup)
    # Configure Panel
    if panel of UXDockPanel:
      let p {.cursor.} = cast[UXDockPanel](panel)
      p.onwatch = self.watchDock
      p.pivot.clip = addr self.metrics
    # Configure Group Watcher
    elif panel of UXDockGroup:
      let g {.cursor.} = cast[UXDockGroup](panel)
      g.onwatch = self.watchGroup
      g.pivot.clip = addr self.metrics

  # -- Dock Panel Elevation --
  proc elevate(panel: GUIWidget) =
    assert panel.parent == self
    # Watch Dock Panel
    self.watch(panel)
    if self.last == panel: return
    # Reattach to Last Widget
    GC_ref(panel)
    panel.detach()
    attachNext(self.last, panel)
    GC_unref(panel)

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
