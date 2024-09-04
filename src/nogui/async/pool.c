// Correct and Efficient Work-Stealing for Weak Memory Models
// https://www.di.ens.fr/~zappa/readings/ppopp13.pdf
#include "pool.h"
#include <stdlib.h>

// -------------------------
// Thread Pool Lane Creation
// -------------------------

void pool_lane_init(pool_lane_t* lane, void* opaque) {
  const int bytes = sizeof(pool_ring_t) + sizeof(pool_task_t) * 32;
  pool_ring_t* ring = calloc(1, bytes);
  ring->len = 32;
  ring->prev = NULL;

  // Initialize Atomic Attributes
  atomic_store_explicit(&lane->ring, ring, memory_order_relaxed);
  atomic_init(&lane->bottom, 0);
  atomic_init(&lane->top, 0);
  // Initialize Common State
  lane->rng = (unsigned long) ring;
  lane->opaque = opaque;
}

void pool_lane_reset(pool_lane_t* lane) {
  pool_ring_t* ring = atomic_load_explicit(&lane->ring, memory_order_relaxed);
  long long len = ring->len;

  // Clear Ring Data
  for (int i = 0; i < len; i++)
    ring->tasks[i] = (pool_task_t) {};

  // Reset Ring Endpoints
  atomic_init(&lane->bottom, 0);
  atomic_init(&lane->top, 0);
}

void pool_lane_destroy(pool_lane_t* lane) {
  pool_ring_t* ring = atomic_load_explicit(&lane->ring, memory_order_relaxed);

  // Free Phantom Rings
  pool_ring_t* prev;
  while (ring) {
    prev = ring;
    ring = ring->prev;
    // Dealloc Ring
    free(prev);
  }
}

// ---------------------
// Thread Pool Lane Grow
// ---------------------

static pool_ring_t* pool_lane_grow(pool_ring_t* ring0, long long b, long long t) {
  long long l0 = ring0->len;
  long long l1 = l0 * 2;
  // Lane Buffer Size
  long long b0 = sizeof(pool_task_t) * l1;
  long long bytes = sizeof(pool_ring_t) + b0;

  // Create New Ring Buffer
  pool_ring_t* ring = calloc(1, bytes);
  ring->len = l1;
  ring->prev = ring0;

  // Copy Previous Tasks
  for (int i = t; i < b; i++) {
    pool_task_t* p0 = ring0->tasks + (i % l0);
    pool_task_t* p1 = ring->tasks + (i % l1);
    // Copy Task Data
    *p1 = *p0;
  }

  // Return Growed Ring
  return ring;
}

// ---------------------------
// Thread Pool Lane Operations
// ---------------------------

void pool_lane_push(pool_lane_t* lane, pool_task_t task) {
  long long b = atomic_load_explicit(&lane->bottom, memory_order_relaxed);
  long long t = atomic_load_explicit(&lane->top, memory_order_acquire);
  pool_ring_t* ring = atomic_load_explicit(&lane->ring, memory_order_relaxed);

  // Expand Ring Buffer if not Enough
  if (b - t > ring->len - 1) {
    ring = pool_lane_grow(ring, b, t);
    atomic_store_explicit(&lane->ring, ring, memory_order_relaxed);
  }

  // Store New Task to Ring Buffer
  ring->tasks[b % ring->len] = task;
  // Store Next Bottom Endpoint
  atomic_thread_fence(memory_order_release);
  atomic_store_explicit(&lane->bottom, b + 1, memory_order_relaxed);
}

pool_task_t pool_lane_steal(pool_lane_t* lane) {
  long long t = atomic_load_explicit(&lane->top, memory_order_acquire);
  atomic_thread_fence(memory_order_seq_cst);
  long long b = atomic_load_explicit(&lane->bottom, memory_order_acquire);

  pool_task_t task = {};
  if (t < b) {
    pool_ring_t* ring = atomic_load_explicit(&lane->ring, memory_order_consume);
    task = ring->tasks[t % ring->len];
    // Check if Task was Successfuly Stolen
    if (!atomic_compare_exchange_strong_explicit(
        &lane->top, &t, t + 1, memory_order_seq_cst, memory_order_relaxed))
      task = (pool_task_t) {};
  }

  // Return Stolen Task
  return task;
}

// -----------------------
// Thread Pool Lane Status
// -----------------------

extern inline void pool_status_inc(pool_status_t* s) {
  atomic_fetch_add_explicit(s, 1, memory_order_seq_cst);
}

extern inline void pool_status_dec(pool_status_t* s) {
  atomic_fetch_sub_explicit(s, 1, memory_order_seq_cst);
}

extern inline void pool_status_reset(pool_status_t* s) {
  atomic_store_explicit(s, 0, memory_order_seq_cst);
}

extern inline void pool_status_set(pool_status_t* s, long long value) {
  atomic_store_explicit(s, value, memory_order_seq_cst);
}

extern inline long long pool_status_get(pool_status_t* s) {
  return atomic_load_explicit(s, memory_order_relaxed);
}
