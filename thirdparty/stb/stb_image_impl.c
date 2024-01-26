#define STB_IMAGE_IMPLEMENTATION 1
#define STBI_MALLOC(sz) _stbi_malloc(sz)
#define STBI_FREE(p) _stbi_free(p)
#define STBI_REALLOC(p,newsz) _stbi_realloc(p,newsz)

#include "stdint.h"

extern uint8_t *_stbi_malloc(uintptr_t const size);
extern void _stbi_free(uint8_t *const ptr);
extern uint8_t *_stbi_realloc(uint8_t *const ptr, uintptr_t const new_size);

#include "stb_image.h"
