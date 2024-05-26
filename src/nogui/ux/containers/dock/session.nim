import ../../prelude

# ------------
# UX Dock Hint
# ------------

widget UXDockHint:
  new dockhint():
    result.kind = wkTooltip

# ---------------
# UX Dock Session
# ---------------

widget UXDockSession:
  attributes:
    hint: UXDockHint
    # Wrapper Widget
    {.cursor.}:
      root: GUIWidget

  new docksession(root: GUIWidget):
    result.add root
    result.root = root
    # Define Hint Tooltip
    result.hint = dockhint()
    result.kind = wkContainer

  proc elevate*(panel: GUIWidget) =
    assert panel.parent == self
    assert panel != self.root
    # Reattach to Last Widget
    GC_ref(panel)
    panel.detach()
    attachNext(self.last, panel)
    GC_unref(panel)

  method update =
    let
      m0 = addr self.metrics
      m1 = addr self.root.metrics
    # Copy Root Min Size
    m0[].minfit m1[]

  method layout =
    let
      m0 = addr self.metrics
      m1 = addr self.root.metrics
    # Copy Root Min Size
    m1[].fit m0[]
