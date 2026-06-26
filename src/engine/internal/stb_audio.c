#include <stddef.h>
#include <stdlib.h>

extern void* stb_alloc(size_t len);
extern void* stb_realloc(void* ptr, size_t len);
extern void stb_free(void* ptr);

#define malloc(len) stb_alloc(len)
#define realloc(ptr, len) stb_realloc(ptr, len)
#define free(ptr) stb_free(ptr)

#define STB_VORBIS_NO_PUSHDATA_API
#define STB_VORBIS_NO_INTEGER_CONVERSION
#define STB_VORBIS_NO_STDIO

#include "stb_vorbis.c"
