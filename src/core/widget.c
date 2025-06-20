#include <nogui/core.h>
#include <stdlib.h>
#include <string.h>

// --------------------------------
// Widget Tree Manipulation: Attach
// --------------------------------

void widget_add(widget_t self, widget_t widget) {
    widget->parent = self;
    widget->next = NULL;

    // Add Widget to Last to Childrens
    if (!widget->first || !widget->prev) {
        widget->prev = NULL;
        self->first = widget;
    } else {
        widget->prev = self->last;
        self->last->next = widget;
    }

    // Replace Last Widget
    self->last = widget;
}

void widget_attachSwap(widget_t self, widget_t widget) {
    const int bytes = sizeof(widget_t) * 3;
    widget_t nodes[4];

    // Replace Self Endpoints
    if (self->parent) {
        if (self->parent->last == self)
            self->parent->last = widget;
        if (self->parent->first == self)
            self->parent->first = widget;
    }
    // Replace Widget Endpoints
    if (widget->parent) {
        if (widget->parent->last == widget)
            widget->parent->last = self;
        if (widget->parent->first == widget)
            widget->parent->first = self;
    }

    // Swap Parent, Next and Prev
    memcpy(nodes, self->parent, bytes);
    memcpy(self->parent, widget->parent, bytes);
    memcpy(widget->parent, nodes, bytes);
}

void widget_attachNext(widget_t self, widget_t widget) {
    widget->parent = self->parent;
    widget->next = self->next;
    widget->prev = self;
    // Replace Self Next
    self->next = widget;
    if (widget->next)
        widget->next->prev = widget;
    // Replace Self Parent Last
    if (self->parent && self->parent->last == self)
        self->parent->last = widget;
}

void widget_attachPrev(widget_t self, widget_t widget) {
    widget->parent = self->parent;
    widget->prev = self->prev;
    widget->next = self;
    // Replace Self Prev
    self->prev = widget;
    if (widget->prev)
        widget->prev->next = widget;
    // Replace Self Parent First
    if (self->parent && self->parent->first == self)
        self->parent->first = widget;
}

// --------------------------------------
// Widget Tree Manipulation: Update Check
// --------------------------------------

static void widget_update_applyCull(widget_t self, widget_rectstack_t* cull) {
    widget_rect_t scope = widget_rectstack_peek(cull);
    int check0 = (self->flags & wIGNORE) == 0;
    int check1 = widget_rect_inside(self->rect, scope);

    // Check Culling Visibility
    self->flags &= ~wVISIBLE;
    if (check0 && check1)
        self->flags |= wVISIBLE;
}

static void widget_update_applyAbsolute(widget_t self) {
    memcpy(&self->rect, &self->metrics, sizeof(widget_rect_t));

    // Calculate Absolute Position
    widget_t parent = self->parent;
    if (parent) {
        self->rect.x += parent->rect.x;
        self->rect.y += parent->rect.y;
    }
}

// --------------------------------
// Widget Tree Manipulation: Update
// --------------------------------

static void widget_update_prepare(widget_t self) {
    widget_t widget = self;
    for(;;) {
        // Traverse Inside
        if (!widget->first) {
            widget->vtable.update;
        } else {
            widget = widget->first;
            continue;
        }

        // Traverse Parents?
        while (!widget->next && widget != self) {
            widget = widget->parent;
            widget->vtable.update;
        }

        // Traverse Slibings?
        if (widget == self) break;
        else widget = widget->next;
    }
}

static void widget_update_layout(widget_t self) {
    widget_rectstack_t cull = widget_rectstact_create();
    widget_rectstack_push(&cull, (widget_rect_t) {
        .x = 0, .y = 0,
        .w = 2147483647,
        .h = 2147483647
    });

    // Accumulate Parents Culling
    widget_t widget = self->parent;
    while (widget) {
        if (widget->flags & wCULL)
            widget_rectstack_push(&cull, widget->rect);
        widget = widget->parent;
    }

    // Traverse Children
    for(widget = self ;;) {
        widget_update_applyAbsolute(widget);
        widget_update_applyCull(widget, &cull);

        // Arrange Widget if Visible
        if (widget->flags & wVISIBLE) {
            widget_flags_t flags = widget->flags;
            widget->vtable.layout;
            widget->flags = flags;
            // Traverse Children?
            if (widget->first) {
                if (widget->flags & wCULL)
                    widget_rectstack_push(&cull, widget->rect);
                widget = widget->first;
                continue;
            }
        }

        // Traverse Parents?
        while(!widget->next && widget != self) {
            widget = widget->parent;
            if (widget->flags & wCULL)
                widget_rectstack_pop(&cull);
        }

        // Traverse Slibings?
        if (widget == self) break;
        else widget = widget->next;
    }

    // Dealloc Culling Stack
    widget_rectstack_destroy(&cull);
}

void widget_update(widget_t self) {
    widget_metrics_t metrics = self->metrics;
    widget_update_prepare(self);

    // Propagate Metrics Changes to Parents
    const int bytes = sizeof(widget_metrics_t);
    while (memcmp(&self->metrics, &metrics, bytes) && self->parent) {
        self = self->parent;
        metrics = self->metrics;
        self->vtable.update;
    }

    // Dispatch Widget Layout
    widget_update_layout(self);
}

// --------------------------------
// Widget Tree Manipulation: Detach
// --------------------------------

void widget_detach(widget_t self) {
    if (self->prev) self->prev->next = self->next;
    if (self->next) self->next->prev = self->prev;

    // Change Parent Endpoints
    if (self->parent) {
        if (self->parent->first == self)
            self->parent->first = self->next;
        if (self->parent->last == self)
            self->parent->last = self->prev;
    }

    // Remove Attachment
    self->parent = NULL;
    self->prev = NULL;
    self->next = NULL;
}
