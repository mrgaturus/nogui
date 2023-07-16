// nogui icon packer
// pre-rasterize on building time
// to avoid heavy dependencies

// -------------------------
// Pre-rasterized Icon Chunk
// -------------------------

typedef struct {
  unsigned int bytes;
  short w, h, fit;
  short channels;
  // Padding For Check
  unsigned int pad0;
  unsigned char buffer[0];
} image_chunk_t;

// ------------
// Image Chunks
// ------------

image_chunk_t* nopack_load_svg(const char* filename, int fit, int isRGBA);
image_chunk_t* nopack_load_bitmap(const char* filename, int fit, int isRGBA);
// Free Chunk After Written to File
void nopack_load_dealloc(image_chunk_t* chunk);
