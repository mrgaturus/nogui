#include <nogui/core.h>
#include <stdlib.h>
#include <string.h>

// ---------------------
// Native Queue Callback
// ---------------------

callback_t* callback_create(int bytes) {
    // Allocate new Callback with Custom Data
    const long size = sizeof(callback_t) + bytes;
    callback_t* cb = malloc(size);
    // Zero Fill Callback
    memset(cb, 0, size);
    cb->bytes = size;

    // Return New Callback
    return cb;
}

int callback_equal(callback_t* a, callback_t* b) {
    // Skip Next Pointer
    void* a0 = &a->self;
    void* b0 = &b->self;
    // Adjust Callback Bytes
    long bytes0 = a->bytes - sizeof(callback_t*);
    long bytes1 = b->bytes - sizeof(callback_t*);

    // Compare if is the same Callback
    return (bytes0 != bytes1) || memcmp(a0, b0, bytes0);
}

void* callback_data(callback_t* cb) {
    void* data = (void*) 0;

    // Check if there is Data Allocated
    const long bytes = sizeof(callback_t);
    if (cb->bytes > bytes)
        data = (char*) cb + bytes;

    // Return Callback Extra
    return data;
}

void callback_call(callback_t* cb) {
    void* data = callback_data(cb);
    // Native Callback Dispatch
    cb->fn(cb->self, data);
}

// --------------------
// Native Queue Pushing
// --------------------

void callback_queue_push(callback_queue_t* queue, callback_t* cb) {
    // Initialize Queue if Empty
    if (!queue->stack) {
        queue->first = cb;
        queue->stack = cb;
        return;
    }

    callback_t* stack = queue->stack;
    // Insert Callback
    cb->next = stack->next;
    stack->next = cb;
    // Replace Last Stack
    queue->stack = cb;
}

void callback_queue_relax(callback_queue_t* queue, callback_t* cb) {
    // Initialize Queue if Empty
    if (!queue->once) {
        queue->once = cb;
        return;
    }

    // Avoid Callback Repeat
    callback_t* last;
    callback_t* c = queue->once;

    while (c) {
        // Compare if is already Relaxed
        if (callback_equal(c, cb) == 0) {
            free(cb);
            return;
        }

        // Next Relaxed
        last = c;
        c = c->next;
    }

    // Replace Last Relaxed
    last->next = cb;
}

// ---------------------
// Native Queue Dispatch
// ---------------------

int callback_queue_poll(callback_queue_t* queue) {
    callback_t* cb = queue->first;

    // Check if there is a Callback
    CALLBACK_POLL:
    if (cb) {
        queue->stack = cb;
        callback_call(cb);
        // Step Callback
        queue->first = cb->next;
        free(cb);

        // Callback was found
        return !! cb;
    }

    // Check if there is a pending
    if (queue->once) {
        cb = queue->once;
        queue->once = NULL;
        // Consume Relaxed Queue
        goto CALLBACK_POLL;
    }

    // Poll Finalized
    queue->stack = cb;
    return !! cb;
}

// --------------------
// Native Queue Destroy
// --------------------

static void callback_queue_free(callback_t* pivot) {
    callback_t* cb = pivot;
    // Dealloc Queue
    while (cb) {
        pivot = cb;
        cb = cb->next;
        // Dealloc Pivot
        free(pivot);
    }
}

void callback_queue_destroy(callback_queue_t* queue) {
    if (queue->first) callback_queue_free(queue->first);
    if (queue->once) callback_queue_free(queue->once);

    // Clear Queue Pointers
    queue->first = NULL;
    queue->stack = NULL;
    queue->once = NULL;
}
