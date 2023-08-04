import base

# -----------------
# GUI Menu Callback
# -----------------

widget GUIMenuItemCB of GUIMenuItem:
  attributes:
    cb: GUICallback

  new menuitem(label: string, cb: GUICallback):
    result.init0(label)
    result.cb = cb

  method event(state: ptr GUIState) =
    if self.event0(state) and valid(self.cb):
      push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

# ---------------
# GUI Menu Option
# ---------------

widget GUIMenuItemOption of GUIMenuItem:
  attributes:
    option: ptr int32
    expected: int32
    # Optional Callback
    @public:
      cb: GUICallback

  new menuoption(label: string, option: ptr int32, expected: int32):
    result.init0(label)
    result.option = option

  method event(state: ptr GUIState) =
    if self.event0(state):
      self.option[] = self.expected
      # Execute Callback
      if valid(self.cb):
        push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

# -----------------
# GUI Menu Checkbox
# -----------------

widget GUIMenuItemCheck of GUIMenuItem:
  attributes:
    check: ptr bool
    # Optional Callback
    @public:
      cb: GUICallback

  new menucheck(label: string, check: ptr bool):
    result.init0(label)
    result.check = check

  method event(state: ptr GUIState) =
    if self.event0(state):
      self.check[] = not self.check[]
      # Execute Callback
      if valid(self.cb):
        push(self.cb)

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)

# ----------------
# GUI Menu Popover
# ----------------

widget GUIMenuItemPopover of GUIMenuItem:
  attributes:
    popover: GUIWidget

  new menuitem(label: string, popover: GUIWidget):
    result.init0(label)
    result.popover = popover

  method event(state: ptr GUIState) =
    if self.event0(state):
      discard

  method draw(ctx: ptr CTXRender) =
    # Draw Base
    self.draw0(ctx)
    # Draw Submenu Arrow

