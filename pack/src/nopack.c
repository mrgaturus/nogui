#define NANOSVG_IMPLEMENTATION
#define NANOSVGRAST_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_RESIZE_IMPLEMENTATION

#include "libs/nanosvgrast.h"
#include "libs/stb_image.h"
#include "libs/stb_image_resize.h"
// Export FFI Include
#include "nopack.h"

// ---------------
// Packing Helpers
// ---------------

static float nopack__scaler(float width, float height, int fit) {
  float max = (width > height) ? width : height;
  // Return Scaling Factor
  return (float) fit / max;
}

static void nopack__bytes(image_chunk_t* chunk) {
  unsigned int w = chunk->w;
  unsigned int h = chunk->h;
  unsigned int channels = chunk->channels;

  chunk->bytes = w * h * channels;
  // Set Padding Check
  chunk->pad0 = 0;
}

// ----------------
// Image Converters
// ----------------

static void nopack__to_alpha(image_chunk_t* chunk) {
  int bytes = chunk->w * chunk->h;

  unsigned char* dst = &chunk->buffer;
  unsigned char* src = &chunk->buffer;
  // Copy alpha to destination
  for (int i = 0; i < bytes; i++, src += 4, dst++)
    *dst = src[3];

  // Set grayscale channel count
  chunk->channels = 1;
}

static void nopack__to_rgba(image_chunk_t* chunk) {
  float r, g, b, a;
  int bytes = chunk->w * chunk->h;

  unsigned char* buffer = &chunk->buffer;
  // Premultiply each color by Alpha
  for (int i = 0; i < bytes; i++, buffer += 4)
    a = (float) buffer[3] / 255.0;
    r = (float) buffer[0] * a;
    g = (float) buffer[1] * a;
    b = (float) buffer[2] * a;
    // Premultiply Alpha
    buffer[0] = (unsigned char) r;
    buffer[1] = (unsigned char) g;
    buffer[2] = (unsigned char) b;

  // Set rgba channel count
  chunk->channels = 4;
}

// ----------------
// SVG Image Loader
// ----------------

image_chunk_t* nopack_load_svg(const char* filename, int fit, int isRGBA) {
  NSVGrasterizer* ctx = nsvgCreateRasterizer();
  NSVGimage* image = nsvgParseFromFile(filename, "px", 96);

  // Calculate SVG Scaling Fit
  float scaler = nopack__scaler(image->width, image->height, fit);
  int w = (int) (image->width * scaler);
  int h = (int) (image->height * scaler);

  // Alloc Image Chunk
  const int bytes = sizeof(image_chunk_t) + (w * h << 2);
  image_chunk_t* chunk = (image_chunk_t*) malloc(bytes);

  // Define Dimensions
  chunk->w = w;
  chunk->h = h;
  chunk->fit = fit;
  // Rasterize SVG to Buffer and Define Data
  nsvgRasterize(ctx, image, 0, 0, scaler, &chunk->buffer, w, h, w << 2);
  if (isRGBA) nopack__to_rgba(chunk);
  else nopack__to_alpha(chunk);
  // Calculate Chunk Size
  nopack__bytes(chunk);

  // Free up rasterizer
  nsvgDeleteRasterizer(ctx);
  // Return New Chunk
  return chunk;
}

image_chunk_t* nopack_load_bitmap(const char* filename, int fit, int isRGBA) {
  int ow, oh, w, h;
  unsigned char* buffer;
  // Load Current Bitmap Buffer
  buffer = stbi_load(filename, &ow, &oh, NULL, STBI_rgb_alpha);

  // Calculate SVG Scaling Fit
  float scaler = nopack__scaler(ow, oh, fit);
  w = (int) (ow * scaler);
  h = (int) (oh * scaler);

  // Alloc Image Chunk
  const int bytes = sizeof(image_chunk_t) + (w * h << 2);
  image_chunk_t* chunk = (image_chunk_t*) malloc(bytes);

  // Define Dimensions
  chunk->w = w;
  chunk->h = h;
  chunk->fit = fit;
  // Resize Image to Fit
  stbir_resize_uint8(buffer, 
    ow, oh, ow << 2, &chunk->buffer, 
    w, h, w << 2, STBI_rgb_alpha);
  // Define Data Format
  if (isRGBA) nopack__to_rgba(chunk);
  else nopack__to_alpha(chunk);
  // Calculate Chunk Size
  nopack__bytes(chunk);

  // Free up image
  stbi_image_free(buffer);
  // Return New Chunk
  return chunk;
}

void nopack_load_dealloc(image_chunk_t* chunk) {
  free(chunk);
}
