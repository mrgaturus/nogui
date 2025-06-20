#include <nogui/core.h>

// ---------------------------
// Widget Tree Manager: Status
// ---------------------------

widget_t widget_outside(widget_t self) {
    while(self->parent)
        self = self->parent;
    // Return Outermost
    return self;
}

int widget_isVisible(widget_t self) {
    int check; do {
        check = self->flags & wVISIBLE;
        // Check Parents Visibility
        self = self->parent;
        if (!self) break;
    } while (check);

    // Return Visible Check
    return check;
}

int widget_isFocusable(widget_t self) {
    const int mask = (wVISIBLE | wKEYBOARD);
    // Check if is Focusable and actually Visible
    int check0 = (self->flags & mask) == mask;
    return check0 && widget_isVisible(self);
}

// --------------------------
// Widget Tree Manager: Point
// --------------------------

int widget_pointCheck(widget_t self, int x, int y) {
    widget_rect_t rect = self->rect;
    return (self->flags & wVISIBLE) &&
        x >= rect.x && x <= rect.x + rect.w &&
        y >= rect.y && y <= rect.y + rect.h;
}

widget_t widget_pointInside(widget_t self, int x, int y) {
    widget_t widget = self->last;
    if (!widget) return self;

    // Find Children
    for(;;) {
        // Enter Inside Layout Widget
        if (widget_pointCheck(widget, x, y)) {
            if (!widget->last || widget->role < woLAYOUT)
                return widget;
            else widget = widget->last;
        // Check Previous Widget
        } else if (!widget->prev) {
            return widget->parent;
        } else { widget = widget->prev; }
    }

    // Return Found Widget
    return widget;
}

widget_t widget_pointFind(widget_t self, widget_t outer, int x, int y) {
    widget_t aux = self;

    // Point Inside All Parents?
    while (aux != outer) {
        if (!widget_pointCheck(aux, x, y))
            self = aux->parent;
        aux = aux->parent;
    }

    // Find Inside of Outside Pivot
    if (self->role == woLAYOUT)
        self = widget_pointInside(self, x, y);
    // Return Found Widget
    return self;
}

// --------------------------
// Widget Tree Manager: Focus
// --------------------------

static widget_t widget_focusOuter(widget_t self) {
    widget_t widget = self->parent;
    while (widget && widget->role != woWIDGET)
        widget = widget->parent;

    // Return Focus Container
    if (!widget) widget = self;
    return widget;
}

widget_t widget_focusNext(widget_t self) {
    const int mask = (wVISIBLE | wKEYBOARD);
    widget_t outer = widget_focusOuter(self);
    if (outer == self && self->role == woWIDGET)
        return self;

    // Find Next Focus
    widget_t widget = self;
    for(;;) {
        if (widget->role != woWIDGET && widget->first) {
            widget = widget->first;
        } else if (widget->next) {
            widget = widget->next;
        // Exit from Scope
        } else {
            widget_t aux = widget->parent;
            while (!aux->next && aux != outer)
                aux = aux->parent;
            // Repeat Outer Cycle
            if (!aux->next)
                widget = outer->first;
            else widget = aux->next;
        }

        // Select Focus if Focusable or is Same
        if (((widget->flags & mask) == mask) || widget == self)
            break;
    }

    // Return Next Focus
    return widget;
}

widget_t widget_focusPrev(widget_t self) {
    const int mask = (wVISIBLE | wKEYBOARD);
    widget_t outer = widget_focusOuter(self);
    if (outer == self && self->role == woWIDGET)
        return self;

    // Find Prev Focus
    widget_t widget = self;
    for(;;) {
        if (widget->role != woWIDGET && widget->last) {
            widget = widget->last;
        } else if (widget->prev) {
            widget = widget->prev;
        // Exit from Scope
        } else {
            widget_t aux = widget->parent;
            while (!aux->prev && aux != outer)
                aux = aux->parent;
            // Repeat Outer Cycle
            if (!aux->prev)
                widget = outer->last;
            else widget = aux->prev;
        }

        // Select Focus if Focusable or is Same
        if (((widget->flags & mask) == mask) || widget == self)
            break;
    }

    // Return Prev Focus
    return widget;
}
