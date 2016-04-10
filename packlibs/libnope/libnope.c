/*
  libnope.c
  (c) KoDi studio, 2015
*/

#include <memory.h>
#include "libnope.h"

static int lib_error = UP_OK;
static char* lib_pack_chunk;
static size_t lib_pack_size;
static char* lib_unpack_chunk;
static size_t lib_unpack_size;

/* plugin info functions */

const char* up_info_name() {
  return DLL_NAME;
}

int up_info_version() {
  return DLL_VERSION;
}

bool up_has_error( int* ret_code ) {
  int err = lib_error;
  if (ret_code != NULL) {
    *ret_code = err;
    lib_error = UP_OK;
  }
  return (err != UP_OK);
}

const char* up_error_msg( int err_code ) {
  switch (err_code) {
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

size_t up_pack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {
  if ( (lib_pack_chunk == NULL) || (lib_pack_size == 0) ) {
    lib_error = UP_DATA_ERROR;
    return 0;
  }

  if ( (outbuf_ptr == NULL) || (outbuf_size == 0) ) {
    lib_error = UP_MEMORY_ERROR;
    return 0;
  }

  size_t copy_size = (outbuf_size < lib_pack_size) ? outbuf_size : lib_pack_size;
  memcpy( outbuf_ptr, lib_pack_chunk, copy_size );
  lib_pack_chunk += copy_size;
  lib_pack_size -= copy_size;
  if (data_left != NULL) { *data_left = lib_pack_size; }

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

size_t up_unpack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {
  if ( (lib_unpack_chunk == NULL) || (lib_unpack_size == 0) ) {
    lib_error = UP_DATA_ERROR;
    return 0;
  }

  if ( (outbuf_ptr == NULL) || (outbuf_size == 0) ) {
    lib_error = UP_MEMORY_ERROR;
    return 0;
  }

  size_t copy_size = (outbuf_size < lib_unpack_size) ? outbuf_size : lib_unpack_size;
  memcpy( outbuf_ptr, lib_unpack_chunk, copy_size );
  lib_unpack_chunk += copy_size;
  lib_unpack_size -= copy_size;
  if (data_left != NULL) { *data_left = lib_unpack_size; }

  return copy_size;
}

void up_unpack_end() {
  up_unpack_init(0);
}


