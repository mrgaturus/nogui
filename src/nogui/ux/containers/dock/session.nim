import ../../../core/tree
import ../../prelude
# Import Group
import group

# ------------
# UX Dock Hint
# ------------

widget UXDockHint:
  new dockhint():
    result.kind = wkTooltip

# -----------------
# UX Dock Container
# -----------------

widget UXDockContainer:
  new dockcontainer():
    result.kind = wkContainer

  proc elevate*(panel: GUIWidget) =
    assert panel.parent == self
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
    hint: UXDockHint
    # Wrapper Widget
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
    result.hint = dockhint()
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
    # Escape from Widget Grab
    if self.test(wGrab) and not clicked:
      return
    # Find Container Widgets
    for dock in reverse(docks.last):
      if dock.pointOnArea(state.mx, state.my):
        if not (dock of UXDockGroup):
          if clicked: docks.elevate(dock)
          dock.send(wsForward)
          return
        # Forward Dock Group
        let w = dock.inside(state.mx, state.my)
        if w.vtable != dock.vtable:
          if clicked: docks.elevate(dock)
          w.send(wsForward)
          return
    # Forward Root Widget
    send(self.root, wsForward)
