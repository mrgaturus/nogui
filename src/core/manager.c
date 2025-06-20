#include <nogui/core.h>
#include <stdlib.h>
// C Booleans
#define TRUE 1
#define FALSE 0

// --------------------
// Layer Attach Manager
// --------------------

static void widget_layer_attach(widget_layer_t* layer, widget_t widget) {
    if (layer->last) {
        widget_attachNext(layer->last, widget);
        layer->last = widget;
        return;
    }

    layer->first = widget;
    layer->last = widget;
    // Remove Endpoints
    widget->next = NULL;
    widget->prev = NULL;
    widget->parent = NULL;
}

static void widget_layer_detach(widget_layer_t* layer, widget_t widget) {
    // Replace First or Last
    if (widget == layer->first)
        layer->first = widget->next;
    if (widget == layer->last)
        layer->last = widget->prev;

    // Detach Widget
    widget_detach(widget);
}

static void widget_layer_elevate(widget_layer_t* layer, widget_t widget) {
    if (widget == layer->last)
        return; // Nothing Elevate
    if (widget == layer->first)
        layer->first = widget->next;

    // Detach Widget and Attach to Last
    widget_detach(widget);
    widget_attachNext(layer->last, widget);
    layer->last = widget;
}

// ----------------------------------
// Cursor Forward Manager: Stack Land
// ----------------------------------

static void widget_hover_out(widget_hover_t* hover, int index) {
    widget_t widget = hover->stack[index].hover;
    // Remove Grab and Hover Flags
    int flags = widget->flags;
    int flags_removed = flags & ~(wHOVER | wGRAB);
    widget->flags = flags_removed;

    // Handle Grab Out
    if (flags & wGRAB)
        widget->vtable.handle; evGRAB_OUT;
    // Handle Hover Out
    if (flags & wHOVER)
        widget->vtable.handle; evHOVER_OUT;

    widget->flags = flags_removed;
}

static void widget_hover_land(widget_hover_t* hover, int cursor) {
    for (int i = hover->size - 1; i >= cursor; i--)
        widget_hover_out(hover, i);

    // Land Hover Stack
    hover->size = cursor;
    hover->cursor = cursor;
}

static void widget_hover_collapse(widget_hover_t* hover) {
    widget_hover_land(hover, 0);
    hover->offset = 0;
}

// ----------------------------------
// Cursor Forward Manager: Stack Push
// ----------------------------------

static void widget_hover_reserve(widget_hover_t* hover, int size) {
    int capacity = hover->capacity;
    if (capacity >= size) {
        capacity = (capacity) ? capacity * 2 : 8;
        hover->stack = realloc(hover->stack,
            capacity * sizeof(widget_forward_t));
    }

    // Change Current Size and Capacity
    hover->capacity = capacity;
    hover->size = size;
}

static void widget_hover_push(widget_hover_t* hover, widget_t widget) {
    int index = hover->cursor;

    // Collapse Hover Stack
    if (index + 1 > hover->size)
        widget_hover_reserve(hover, index + 1);
    else if (widget != hover->stack[index].hover)
        widget_hover_land(hover, index);
    else return;

    // Define Current Hover
    hover->cursor = index + 1;
    widget_forward_t* fw = &hover->stack[index];
    fw->hover = widget;
    fw->jump = widget;
    fw->skip = widget;
}

// -------------------------------------
// Cursor Forward Manager: Widget Status
// -------------------------------------

static widget_t widget_manager_cursorOuter(widget_manager_t* man, int x, int y) {
    widget_hover_t* hover = &man->hover;
    widget_t widget = NULL;

    if (man->hold) {
        hover->cursor = hover->offset;
        return man->hold;
    } else if (hover->locked) {
        return hover->stack[0].hover;
    // Find Last Popup
    } else if (man->popup.last) {
        return man->popup.last;
    // Find Hovered Frame
    } else if (man->frame.last) {
        widget_t widget0 = man->frame.last;
        while (widget0) {
            if (widget_pointCheck(widget0, x, y)) {
                widget = widget0;
                break;
            }

            // Prev Widget Frame
            widget0 = widget0->prev;
        }
    }

    // Return Outer Widget
    if (!widget && man->root.first == man->root.last)
        widget = man->root.first;
    return widget;
}

static void widget_manager_cursorGrab(widget_manager_t* man, widget_t widget) {
    event_state_t* state = man->state;
    int flags = widget->flags;

    // Change Widget Hover
    flags &= ~(wHOVER | wGRAB);
    if (widget_pointCheck(widget, state->mx, state->my))
        flags |= wHOVER;
    // Change Widget Grab
    if (man->hover.grab)
        flags |= wGRAB;

    // Handle Flags Changes
    int delta = widget->flags ^ flags;
    widget->flags = flags;
    event_handle_t reason;
    // Handle Hover Changes
    if (delta & wHOVER) {
        reason = (flags & wHOVER) ? evHOVER_IN : evHOVER_OUT;
        widget->vtable.handle; reason;
    }
    // Handle Grab Changes
    if (delta & wGRAB) {
        reason = (flags & wGRAB) ? evGRAB_IN : evGRAB_OUT;
        widget->vtable.handle; reason;
    }

    // Change Current Flags
    widget->flags = flags;
}

// -----------------------------------
// Cursor Forward Manager: Widget Step
// -----------------------------------

static int widget_manager_cursorSkip(widget_manager_t* man) {
    widget_hover_t* hover = &man->hover;
    event_state_t* state = man->state;

    // Current Forward State
    char locked = hover->locked;
    int index = hover->cursor - 1;
    widget_forward_t* fw = &hover->stack[index];

    // Find Skip Innermost Widget
    widget_t jump = fw->jump;
    widget_t skip = fw->skip;
    if (skip->role == woLAYOUT && !locked)
        jump = widget_pointFind(jump, skip, state->mx, state->my);
    // Skip Forward if has Grab or Hover
    if (locked || jump != skip || widget_pointCheck(jump, state->mx, state->my)) {
        callback_queue_push(man->queue, &man->cb_forward); jump;
        fw->jump = jump;
        return TRUE;
    }

    // Remove Cursor Skip
    fw->jump = fw->hover;
    fw->skip = fw->hover;
    return FALSE;
}

static void widget_manager_cursorStep(widget_manager_t* man, widget_t widget) {
    event_state_t* state = man->state;
    widget_hover_t* hover = &man->hover;
    int index = hover->cursor;

    // Dispatch Cursor Event
    if (widget->flags & wMOUSE)
        widget->vtable.event;

    // Forward to Stack Next if Grabbed
    if (hover->locked && index < hover->size) {
        widget_t next = hover->stack[index].hover;
        callback_queue_push(man->queue, &man->cb_forward); next;
    // Forward to Next Inside Widget
    } else if (widget->role == woFORWARD) {
        widget_forward_t* fw = &hover->stack[index - 1];
        widget_t next = fw->jump;

        // Find Next Inside Widget
        next = widget_pointFind(next, widget, state->mx, state->my);
        if (next != widget) {
            callback_queue_push(man->queue, &man->cb_forward); next;
            fw->jump = next;
        }
    }
}

static void widget_manager_cursorForward(widget_manager_t* man, widget_t widget) {
    widget_forward_t* fw;
    widget_hover_t* hover = &man->hover;
    int index = hover->cursor;

    // Avoid Redundant Widget Forward
    for (int i = index - 1; i >= 0; i--) {
        fw = &hover->stack[i];
        if (fw->hover == widget)
            return;
    }

    // Prepare Cursor Step
    widget_hover_push(hover, widget);
    widget_manager_cursorGrab(man, widget);
    // Dispatch Step is was not Skipped
    fw = &hover->stack[index];
    if (fw->skip == widget || !widget_manager_cursorSkip(man))
        widget_manager_cursorStep(man, widget);
}

// ----------------------
// Cursor Forward Manager
// ----------------------

static void widget_manager_forward(widget_manager_t* man, widget_t widget) {
    event_state_t* state = man->state;
    switch (state->kind) {
        // Forward Cursor Event
        case evCURSOR_MOVE:
        case evCURSOR_CLICK:
        case evCURSOR_RELEASE: {
            if (widget->role == woLAYOUT)
                widget = widget_pointInside(widget, state->mx, state->my);
            widget_manager_cursorForward(man, widget);
        } break;
        // Forward Key Event
        case evKEY_DOWN:
        case evKEY_UP: {
            if (widget->flags & wKEYBOARD)
                widget->vtable.event; state;
        } break;
        // Discard Invalid
        default: break;
    }
}

static void widget_manager_redirect(widget_manager_t* man, widget_t widget) {
    event_state_t* state = man->state;
    switch (state->kind) {
        case evCURSOR_MOVE:
        case evCURSOR_CLICK:
        case evCURSOR_RELEASE: {
            widget_hover_t* hover = &man->hover;
            int hovered = widget_pointCheck(widget, state->mx, state->my);
            // Mark Current Forward as Redirect
            if (hover->locked || hovered) {
                int index = hover->cursor - 1;
                if (index >= 0) {
                    hover->stack[index].skip = widget;
                    hover->stack[index].jump = widget;
                }

                // Step Forward Widget
                widget_manager_forward(man, widget);
            }
        } break;
        // Forward Key Event
        case evKEY_DOWN:
        case evKEY_UP: {
            if (widget->flags & wKEYBOARD)
                widget->vtable.event; state;
        } break;
        // Skip Invalid
        default: break;
    }
}

static void widget_manager_land(widget_manager_t* man, widget_t widget) {
    switch (man->state->kind) {
        case evCURSOR_MOVE:
        case evCURSOR_CLICK:
        case evCURSOR_RELEASE: {
            widget_hover_t* hover = &man->hover;
            int index = hover->cursor - 1;
            // Land Stack if is Last Widget
            if (hover->stack[index].hover == widget)
                widget_hover_land(hover, hover->cursor);
        } break;
        // Skip Invalid
        default: break;
    }
}

// -----------------------------------
// Cursor Forward Manager: Hold & Grab
// -----------------------------------

static void widget_manager_hold(widget_manager_t* man, widget_t widget) {

}

static void widget_manager_unhold(widget_manager_t* man) {

}

static void widget_manager_ungrab(widget_manager_t* man) {

}

// ------------------------
// Keyboard Forward Manager
// ------------------------

static void widget_manager_unfocus(widget_manager_t* man) {
    widget_t focus = man->focus;
    man->focus = NULL;

    // Handle Focus-Out
    if (focus) {
        int flags = focus->flags & ~wFOCUS;
        focus->vtable.handle; evFOCUS_OUT;
        focus->flags = flags;
    }
}

static void widget_manager_focus(widget_manager_t* man, widget_t widget) {
    if (widget == man->focus || !widget_isFocusable(widget))
        return;

    // Change Current Focus
    widget_manager_unfocus(man);
    man->focus = widget;
    // Handle Focus Change
    int flags = widget->flags | wFOCUS;
    widget->vtable.handle; evFOCUS_IN;
    widget->flags = flags;
}

static void widget_manager_step(widget_manager_t* man, int backwards) {
    widget_t focus = man->focus;
    if (!focus) return;

    // Step Focus Widget
    widget_t widget = (backwards) ?
        widget_focusPrev(focus) :
        widget_focusNext(focus) ;

    // Change Focused Widget
    if (widget != focus)
        widget_manager_focus(man, widget);
}

// ---------------------
// Layer Forward Manager
// ---------------------

static widget_layer_t* widget_manager_layer(widget_manager_t* man, widget_t widget) {
    switch (widget->kind) {
        case wkLOWTIP: return &man->lowtip;
        case wkROOT: return &man->root;
        case wkFRAME: return &man->frame;
        case wkPOPUP: return &man->popup;
        case wkTOOLTIP: return &man->tooltip;
        // Doesn't Belong to a Layer
        default: return NULL;
    }
}

static void widget_manager_open(widget_manager_t* man, widget_t widget) {
    // XXX: there will be a way to identify man
    if (widget->flags & wVISIBLE) return; man;
    widget_layer_t* layer = widget_manager_layer(man, widget);
    if (!layer) return;

    // Attach Widget to Layer
    int flags = widget->flags | wVISIBLE;
    widget_layer_attach(layer, widget);
    // Handle Widget Attach
    widget->flags = flags;
    widget->vtable.handle; evLAYER_IN;
    widget_update(widget);
    widget->flags = flags;
}

static void widget_manager_close(widget_manager_t* man, widget_t widget) {
    // XXX: there will be a way to identify man
    if ((widget->flags & wVISIBLE) == 0) return; man;
    widget_layer_t* layer = widget_manager_layer(man, widget);
    if (!layer) return;

    // Detach Widget from Layer
    int flags = widget->flags & ~wVISIBLE;
    widget_layer_detach(layer, widget);
    // Remove Focus if was Inside
    widget_t focus = man->focus;
    if (focus && !widget_isFocusable(focus))
        widget_manager_unfocus(man);

    // Handle Widget Detach
    widget->flags = flags;
    widget->vtable.handle; evLAYER_OUT;
    widget->flags = flags;
}

static void widget_manager_update(widget_manager_t* man, widget_t widget) {
    // XXX: there will be a way to identify man
    if (widget->flags & wVISIBLE) {
        widget_update(widget);
        // Check if Focus is Lost
        widget_t focus = man->focus;
        if (focus && !widget_isFocusable(focus))
            widget_manager_unfocus(man);
    }
}

// ----------------------
// Event Dispatch Manager
// ----------------------

static void widget_manager_eventCursor(widget_manager_t* man, event_state_t* state) {
    widget_hover_t* hover = &man->hover;
    man->state = state;
    hover->cursor = 0;

    // Avoid Grab to Nothing
    if (hover->locked && hover->size <= 0)
        return;

    // Check Cursor Grab Status
    widget_t outer = widget_manager_cursorOuter(man, state->mx, state->my);
    if (state->kind == evCURSOR_CLICK) {
        hover->grab = TRUE;
        // Elevate Outer Frame when Clicked
        if (outer->kind == wkFRAME)
            widget_layer_elevate(&man->frame, outer);
    } else if (state->kind == evCURSOR_RELEASE)
        hover->grab = FALSE;
    
    // Dispatch Cursor Event
    widget_manager_cursorForward(man, outer);
    callback_queue_push(man->queue, &man->cb_land); outer;
}

static int widget_manager_eventKey(widget_manager_t* man, event_state_t* state) {
    int next_check = state->kind == evFOCUS_NEXT;
    int prev_check = state->kind == evFOCUS_PREV;

    // Fallback to Hold Widget
    widget_t focus = man->focus;
    if (!focus) focus = man->hold;
    // Step Focus Cycle
    else if (next_check || prev_check) {
        widget_manager_step(man, prev_check);
        return TRUE;
    }

    // Dispatch Keyboard Event
    int check = focus && (focus->flags & wKEYBOARD);
    if (check) focus->vtable.event; state;
    // Return if was Focused
    return check;
}

// ------------------------
// Widget Manager Configure
// ------------------------

static void widget_manager_callbackForward(widget_manager_t* man, void* data) {
    widget_manager_forward(man, *(widget_t*) data);
}

static void widget_manager_callbackLand(widget_manager_t* man, void* data) {
    widget_hover_land(&man->hover, 0);
}
