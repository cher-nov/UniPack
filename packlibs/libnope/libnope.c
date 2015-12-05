/*
  libnope.c
  (c) KoDi studio, 2015
*/

#include <memory.h>
#include "libnope.h"

static int lib_error = UP_OK;
static up_datasize_t lib_pack_size = 0;
static up_datasize_t lib_unpack_size = 0;

/* plugin info functions */

const char* up_info_name() {
  return DLL_NAME;
}

int up_info_version() {
  return DLL_VERSION;
}

const char* up_last_error() {
  int err = lib_error;
  lib_error = UP_OK;

  switch (err) {
    case UP_OK:
      return NULL;
    break;
    case UP_INTERNAL_ERROR:
      return "internal plugin error";
    break;
    case UP_DATA_ERROR:
      return "invalid data";
    break;
    case UP_MEMORY_ERROR:
      return "plugin memory error";
    break;
  }

  return "unknown error";
}

/* compression functions */

void up_pack_init( up_datasize_t pack_size ) {
  lib_pack_size = pack_size;
}

size_t up_pack_chunk(
  void* chunk_ptr, size_t chunk_size, void* outbuf_ptr, size_t outbuf_size
) {
  if ( (chunk_ptr == NULL) || (lib_pack_size < chunk_size) ) {
    lib_error = UP_DATA_ERROR;
    return 0;
  }

  if ( (outbuf_ptr == NULL) || (outbuf_size < 1) ) {
    lib_error = UP_MEMORY_ERROR;
    return 0;
  }

  size_t copy_size = (outbuf_size < chunk_size) ? outbuf_size : chunk_size;
  lib_pack_size -= copy_size;
  memcpy( outbuf_ptr, chunk_ptr, copy_size );
  return copy_size;
}

void up_pack_end() {
  lib_pack_size = 0;
}

/* decompression functions */

void up_unpack_init( up_datasize_t unpack_size ) {
  lib_unpack_size = unpack_size;
}

size_t up_unpack_chunk(
  void* chunk_ptr, size_t chunk_size, void* outbuf_ptr, size_t outbuf_size
) {
  if ( (chunk_ptr == NULL) || (lib_unpack_size < chunk_size) ) {
    lib_error = UP_DATA_ERROR;
    return 0;
  }

  if ( (outbuf_ptr == NULL) || (outbuf_size < 1) ) {
    lib_error = UP_MEMORY_ERROR;
    return 0;
  }

  size_t copy_size = (outbuf_size < chunk_size) ? outbuf_size : chunk_size;
  lib_unpack_size -= copy_size;
  memcpy( outbuf_ptr, chunk_ptr, copy_size );
  return copy_size;
}

void up_unpack_end() {
  lib_unpack_size = 0;
}


