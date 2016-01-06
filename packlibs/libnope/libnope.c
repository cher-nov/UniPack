/*
  libnope.c
  (c) KoDi studio, 2015
*/

#include <memory.h>
#include "libnope.h"

static int lib_error = UP_OK;
static void* lib_pack_chunk;
static up_datasize_t lib_pack_size;
static void* lib_unpack_chunk;
static up_datasize_t lib_unpack_size;

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
  up_pack_chunk(NULL, 0);
}

void up_pack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_pack_chunk = chunk_ptr;
  lib_pack_size = chunk_size;
}

size_t up_pack_step( void* outbuf_ptr, size_t outbuf_size ) {
  if ( (lib_pack_chunk == NULL) || (lib_pack_size < 1) ) {
    lib_error = UP_DATA_ERROR;
    return 0;
  }

  if ( (outbuf_ptr == NULL) || (outbuf_size < 1) ) {
    lib_error = UP_MEMORY_ERROR;
    return 0;
  }

  size_t copy_size = (outbuf_size < lib_pack_size) ? outbuf_size : lib_pack_size;
  memcpy( outbuf_ptr, lib_pack_chunk, copy_size );
  return copy_size;
}

void up_pack_end() {
  up_pack_init(0);
}

/* decompression functions */

void up_unpack_init( up_datasize_t unpack_size ) {
  up_unpack_chunk(NULL, 0);
}

void up_unpack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_unpack_chunk = chunk_ptr;
  lib_unpack_size = chunk_size;
}

size_t up_unpack_step( void* outbuf_ptr, size_t outbuf_size ) {
  if ( (lib_unpack_chunk == NULL) || (lib_unpack_size < 1) ) {
    lib_error = UP_DATA_ERROR;
    return 0;
  }

  if ( (outbuf_ptr == NULL) || (outbuf_size < 1) ) {
    lib_error = UP_MEMORY_ERROR;
    return 0;
  }

  size_t copy_size = (outbuf_size < lib_unpack_size) ? outbuf_size : lib_unpack_size;
  memcpy( outbuf_ptr, lib_unpack_chunk, copy_size );
  return copy_size;
}

void up_unpack_end() {
  up_unpack_init(0);
}


