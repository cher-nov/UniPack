/*
  libzlib.c
  (c) KoDi studio, 2015
*/

#define Z_PREFIX

#include "zlib/zlib.h"
#include "libzlib.h"

// amazing zlib build bug workaround
#ifndef z_deflateInit
  #define z_deflateInit deflateInit
#endif
#ifndef z_inflateInit
  #define z_inflateInit inflateInit
#endif

static int lib_error = Z_OK;

static up_datasize_t lib_pack_left;
static z_stream lib_zstream_pack;
static bool lib_pack_flushed;

static up_datasize_t lib_unpack_left;
static z_stream lib_zstream_unpack;

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
    lib_error = Z_OK;
  }
  return (err != Z_OK);
}

const char* up_error_msg( int err_code ) {
  if (err_code == Z_OK) {
    return NULL;
  } else {
    return z_zError(err_code);
  }
}

/* compression functions */

void up_pack_init( up_datasize_t pack_size ) {
  lib_zstream_pack.zalloc = Z_NULL;
  lib_zstream_pack.zfree = Z_NULL;
  lib_zstream_pack.opaque = Z_NULL;
  z_deflateInit( &lib_zstream_pack, Z_BEST_COMPRESSION );
  lib_pack_left = pack_size;
  lib_pack_flushed = false;
}

void up_pack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_zstream_pack.next_in = chunk_ptr;
  lib_zstream_pack.avail_in = chunk_size;
}

size_t up_pack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {
  lib_zstream_pack.next_out = outbuf_ptr;
  lib_zstream_pack.avail_out = outbuf_size;

  size_t input_size, chunk_left;
  int flush, result;

  input_size = lib_zstream_pack.avail_in;
  flush = (lib_pack_left > 0) ? Z_NO_FLUSH : Z_FINISH;
  result = z_deflate( &lib_zstream_pack, flush );

  switch (result) {
    case Z_OK:
      chunk_left = lib_zstream_pack.avail_in;
      lib_pack_left -= input_size - chunk_left;
    break;
    case Z_STREAM_END:
      chunk_left = 0;
      lib_pack_flushed = true;
    break;

    default:
      lib_error = result;
      return 0;
  }

  if (data_left != NULL) { *data_left = chunk_left; }
  return outbuf_size - lib_zstream_pack.avail_out;
}

up_datasize_t up_pack_left() {
  return lib_pack_left;
}

bool up_pack_done() {
  return ( (lib_pack_left == 0) && lib_pack_flushed );
}

void up_pack_end() {
  z_deflateEnd( &lib_zstream_pack );
}

/* decompression functions */

void up_unpack_init( up_datasize_t unpack_size ) {
  lib_zstream_unpack.zalloc = Z_NULL;
  lib_zstream_unpack.zfree = Z_NULL;
  lib_zstream_unpack.opaque = Z_NULL;
  lib_zstream_unpack.avail_in = 0;
  lib_zstream_unpack.next_in = Z_NULL;
  z_inflateInit( &lib_zstream_unpack );
  lib_unpack_left = unpack_size;
}

void up_unpack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_zstream_unpack.next_in = chunk_ptr;
  lib_zstream_unpack.avail_in = chunk_size;
}

size_t up_unpack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {
  lib_zstream_unpack.next_out = outbuf_ptr;
  lib_zstream_unpack.avail_out = outbuf_size;

  int result;
  size_t input_size = lib_zstream_unpack.avail_in;
  result = z_inflate( &lib_zstream_unpack, Z_NO_FLUSH );

  switch (result) {
    case Z_OK:
    case Z_STREAM_END:
      lib_unpack_left -= input_size - lib_zstream_unpack.avail_in;
      if (data_left != NULL) { *data_left = lib_zstream_unpack.avail_in; }
      return outbuf_size - lib_zstream_unpack.avail_out;
    break;

    default:
      lib_error = result;
      return 0;
  }
}

up_datasize_t up_unpack_left() {
  return lib_unpack_left;
}

bool up_unpack_done() {
  return (lib_unpack_left == 0);
}

void up_unpack_end() {
  z_inflateEnd( &lib_zstream_unpack );
}


