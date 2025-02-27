#include <stdatomic.h>

typedef void (*green_vmproc_t)(void*);
typedef __attribute__((aligned(16))) struct {
  unsigned char buffer[128];
} green_vmstack_t;

typedef __attribute__((aligned(16))) struct {
  unsigned long long buffer[32];
} green_vmstate_t;

extern void green_callctx(green_vmproc_t proc, void* data, void* stack);
extern void green_jumpctx(green_vmstate_t* state, int signal);
extern int green_setctx(green_vmstate_t* state);

// --------------------
// Thread Pool: Structs
// --------------------

typedef _Atomic long long pool_status_t;
typedef void (*pool_fn_t)(void*);

__attribute__ ((aligned (16)))
typedef struct {
  void* data;
  pool_fn_t fn;
} pool_task_t;

typedef struct pool_ring_t {
  struct pool_ring_t* prev;
  long long len;
  // Unchecked Array Tasks
  pool_task_t tasks[];
} pool_ring_t;

typedef struct {
  void* opaque;
  unsigned long rng;
  // Thread Ring Lock Free
  _Alignas(64) _Atomic long long bottom;
  _Alignas(64) _Atomic long long top;
  _Alignas(64) pool_ring_t* _Atomic ring;
} pool_lane_t;

// ----------------------
// Thread Pool: Functions
// ----------------------

void pool_lane_init(pool_lane_t* lane, void* opaque);
void pool_lane_reset(pool_lane_t* lane);
void pool_lane_destroy(pool_lane_t* lane);
void pool_lane_push(pool_lane_t* lane, pool_task_t task);
pool_task_t pool_lane_steal(pool_lane_t* lane);

inline void pool_status_inc(pool_status_t* s);
inline void pool_status_dec(pool_status_t* s);
inline void pool_status_reset(pool_status_t* s);
inline void pool_status_set(pool_status_t* s, long long value);
inline long long pool_status_get(pool_status_t* s);
