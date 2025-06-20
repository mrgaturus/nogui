#include <stdlib.h>
#include <nogui/core.h>
#define RECT_MAX(x, y) ((x > y) ? x : y)
#define RECT_MIN(x, y) ((x < y) ? x : y)

// --------------------------
// Widget Rect: Intersections
// --------------------------

int widget_rect_inside(widget_rect_t rect, widget_rect_t clip) {
    return rect.x <= clip.x + clip.w &&
        rect.y <= clip.y + clip.h &&
        rect.x + rect.w >= clip.x &&
        rect.y + rect.h >= clip.y;
}

int widget_rect_pointInside(widget_rect_t rect, int x, int y) {
    return x >= rect.x && x <= rect.x + rect.w &&
        y >= rect.y && y <= rect.y + rect.h;
}

widget_rect_t widget_rect_intersect(widget_rect_t a, widget_rect_t b) {
    widget_rect_t rect;
    rect.x = RECT_MAX(a.x, b.x);
    rect.y = RECT_MAX(a.y, b.y);
    rect.w = RECT_MIN(a.x + a.w, b.x + b.w) - rect.x;
    rect.h = RECT_MIN(a.y + a.h, b.y + b.h) - rect.y;
    // Clamp Dimensions to 0
    if (rect.w <= 0 || rect.h <= 0) {
        rect.w = 0;
        rect.h = 0;
    }

    return rect;
}

// ---------------------------
// Widget Rect: Clipping Stack
// ---------------------------

widget_rectstack_t widget_rectstact_create() {
    return (widget_rectstack_t) {
        .levels = malloc(sizeof(widget_rect_t) * 4),
        .count = 0, .capacity = 4,
    };
}

widget_rect_t widget_rectstack_peek(widget_rectstack_t* stack) {
    if (stack->levels && stack->count > 0)
        return stack->levels[stack->count - 1];
    else return (widget_rect_t) {};
}

void widget_rectstack_push(widget_rectstack_t* stack, widget_rect_t rect) {
    // Expand stack capacity twice it's size
    if (stack->capacity <= 0) *stack = widget_rectstact_create();
    else if (stack->count + 1 >= stack->capacity) {
        stack->capacity *= 2;
        stack->levels = realloc(stack->levels,
            stack->capacity * sizeof(widget_rect_t));
    }

    // Intersect rect with previous
    if (stack->count > 0)
        rect = widget_rect_intersect(rect,
            stack->levels[stack->count]);
    // Push rect clipping level
    stack->levels[stack->count] = rect;
    stack->count++;
}

void widget_rectstack_pop(widget_rectstack_t* stack) {
    if (stack->count <= 0) return;
    stack->count--;
}

void widget_rectstack_clear(widget_rectstack_t* stack) {
    widget_rectstack_destroy(stack);
}

void widget_rectstack_destroy(widget_rectstack_t* stack) {
    if (stack->levels) free(stack->levels);
    *stack = (widget_rectstack_t) {};
}

// --------------------------
// Widget Metrics: Operations
// --------------------------

widget_metrics_t widget_metrics_inset(widget_metrics_t m, int inset) {
    return (widget_metrics_t) {
        .x = m.x + inset,
        .y = m.y + inset,
        .w = m.w - (inset << 1),
        .h = m.h - (inset << 1),
    };
}

widget_metrics_t widget_metrics_intersect(widget_metrics_t m, widget_metrics_t m0) {
    widget_metrics_t metrics = m;
    widget_rect_t rect =
        widget_rect_intersect(
            *(widget_rect_t*) &m,
            *(widget_rect_t*) &m0);
    // Return Intersected Rect
    *(widget_rect_t*) &metrics = rect;
    return metrics;
}

widget_metrics_t widget_metrics_clip(widget_metrics_t m, widget_metrics_t m0) {
    widget_metrics_t metrics = m;
    m.w += m.x; m.h += m.y;
    // Clip Metrics Region
    metrics.x = RECT_MAX(m.x, m0.x);
    metrics.y = RECT_MAX(m.y, m0.y);
    metrics.w = RECT_MIN(m.w, m0.x + m0.w) - m.x;
    metrics.h = RECT_MIN(m.h, m0.y + m0.h) - m.y;
    return metrics;
}

widget_metrics_t widget_metrics_fit(widget_metrics_t m, widget_metrics_t m0) {
    widget_metrics_t metrics = m;
    // Fit Parent Space
    metrics.x = 0;
    metrics.y = 0;
    metrics.w = m0.w;
    metrics.h = m0.h;
    return metrics;
}

widget_metrics_t widget_metrics_hints(widget_metrics_t m, widget_metrics_t m0) {
    widget_metrics_t metrics = m;
    metrics.min_w = m0.min_w;
    metrics.min_h = m0.min_h;
    metrics.max_w = m0.max_w;
    metrics.max_h = m0.max_h;
    return metrics;
}

widget_metrics_t widget_metrics_rect(widget_metrics_t m, widget_metrics_t m0) {
    widget_metrics_t metrics = m;
    metrics.x = m0.x;
    metrics.y = m0.y;
    metrics.w = m0.w;
    metrics.h = m0.h;
    return metrics;
}

widget_metrics_t widget_metrics_clamp(widget_metrics_t m) {
    widget_metrics_t metrics;
    metrics.w = RECT_MAX(metrics.w, metrics.min_w);
    metrics.w = RECT_MIN(metrics.w, metrics.max_w);
    metrics.h = RECT_MAX(metrics.h, metrics.min_h);
    metrics.h = RECT_MIN(metrics.h, metrics.max_h);
    return metrics;
}
