#include "native.h"
// Memory Allocation
#include <stdlib.h>
#include <string.h>

// ---------------------
// Native Queue Callback
// ---------------------

nogui_cb_t* nogui_cb_create(int bytes) {
  // Allocate new Callback with Custom Data
  const long size = sizeof(nogui_cb_t) + bytes;
  nogui_cb_t* cb = malloc(size);
  // Define Callback Bytes
  cb->bytes = size;
  cb->next = NULL;

  // Return New Callback
  return cb;
}

void* nogui_cb_data(nogui_cb_t* cb) {
  void* data = (void*) 0;

  // Check if there is Data Allocated
  const long bytes = sizeof(nogui_cb_t);
  if (cb->bytes > bytes)
    data = (char*) cb + bytes;

  // Return Callback Extra
  return data;
}

int nogui_cb_equal(nogui_cb_t* a, nogui_cb_t* b) {
  // Skip Next Pointer
  void** a0 = (void**) a + 1;
  void** b0 = (void**) b + 1;
  // Adjust Callback Bytes
  long bytes0 = a->bytes - sizeof(void**);
  long bytes1 = b->bytes - sizeof(void**);

  // Compare if is the same Callback
  return (bytes0 != bytes1) || memcmp(a0, b0, bytes0);
}

// --------------------
// Native Queue Pushing
// --------------------

void nogui_queue_push(nogui_queue_t* queue, nogui_cb_t* cb) {
  // Initialize Queue if Empty
  if (!queue->stack) {
    queue->first = cb;
    queue->stack = cb;
    return;
  }

  nogui_cb_t* stack = queue->stack;
  // Insert Callback
  cb->next = stack->next;
  stack->next = cb;
  // Replace Last Stack
  queue->stack = cb;
}

void nogui_queue_relax(nogui_queue_t* queue, nogui_cb_t* cb) {
  // Initialize Queue if Empty
  if (!queue->once) {
    queue->once = cb;
    return;
  }

  // Avoid Callback Repeat
  nogui_cb_t* last;
  nogui_cb_t* c = queue->once;

  while (c) {
    // Compare if is already Relaxed
    if (nogui_cb_equal(c, cb) == 0) {
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

void nogui_cb_call(nogui_cb_t* cb) {
  void* data = nogui_cb_data(cb);
  // Native Callback Dispatch
  cb->fn(cb->self, data);
}

int nogui_queue_poll(nogui_queue_t* queue) {
  nogui_cb_t* cb = queue->first;

  // Check if there is a Callback
CALLBACK_POLL:
  if (cb) {
    queue->stack = cb;
    nogui_cb_call(cb);
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

static void nogui_queue_free(nogui_cb_t* pivot) {
  nogui_cb_t* cb = pivot;
  // Dealloc Queue
  while (cb) {
    pivot = cb;
    cb = cb->next;
    // Dealloc Pivot
    free(pivot);
  }
}

void nogui_queue_destroy(nogui_queue_t* queue) {
  if (queue->first)
    nogui_queue_free(queue->first);
  if (queue->once)
    nogui_queue_free(queue->once);

  // Clear Queue Pointers
  queue->first = NULL;
  queue->stack = NULL;
  queue->once = NULL;
}
