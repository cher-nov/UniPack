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
static up_datasize_t lib_pack_left = 0;
static z_stream lib_zstream_pack;
static z_stream lib_zstream_unpack;

const char* up_info_name() {
  return DLL_NAME;
}

int up_info_version() {
  return DLL_VERSION;
}

const char* up_last_error() {
  if (lib_error == Z_OK) {
    return NULL;
  } else {
    int err = lib_error;
    lib_error = Z_OK;
    return z_zError(err);
  }
}

/* compression functions */

void up_pack_init( up_datasize_t pack_size ) {
  lib_pack_left = pack_size;
  lib_zstream_pack.zalloc = Z_NULL;
  lib_zstream_pack.zfree = Z_NULL;
  lib_zstream_pack.opaque = Z_NULL;
  z_deflateInit( &lib_zstream_pack, Z_BEST_COMPRESSION );
}

void up_pack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_zstream_pack.next_in = chunk_ptr;
  lib_zstream_pack.avail_in = chunk_size;
}

size_t up_pack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {
  lib_zstream_pack.next_out = outbuf_ptr;
  lib_zstream_pack.avail_out = outbuf_size;

  int result, flush;
  size_t input_size = lib_zstream_pack.avail_in;
  flush = (lib_pack_left > input_size) ? Z_NO_FLUSH : Z_FINISH;
  result = z_deflate( &lib_zstream_pack, flush );

  switch (result) {
    case Z_OK:
    case Z_STREAM_END:
      lib_pack_left -= input_size - lib_zstream_pack.avail_in;
      if (data_left != NULL) { *data_left = lib_zstream_pack.avail_in; }
      return outbuf_size - lib_zstream_pack.avail_out;
    break;

    default:
      lib_error = result;
      return 0;
  }
}

void up_pack_end() {
  z_deflateEnd( &lib_zstream_pack );
  lib_pack_left = 0;
}

/* decompression functions */

void up_unpack_init( up_datasize_t unpack_size ) {
  lib_zstream_unpack.zalloc = Z_NULL;
  lib_zstream_unpack.zfree = Z_NULL;
  lib_zstream_unpack.opaque = Z_NULL;
  lib_zstream_unpack.avail_in = 0;
  lib_zstream_unpack.next_in = Z_NULL;
  z_inflateInit( &lib_zstream_unpack );
}

void up_unpack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_zstream_unpack.next_in = chunk_ptr;
  lib_zstream_unpack.avail_in = chunk_size;
}

size_t up_unpack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {
  lib_zstream_unpack.next_out = outbuf_ptr;
  lib_zstream_unpack.avail_out = outbuf_size;

  int result;
  result = z_inflate( &lib_zstream_unpack, Z_NO_FLUSH );

  switch (result) {
    case Z_OK:
    case Z_STREAM_END:
      if (data_left != NULL) { *data_left = lib_zstream_unpack.avail_in; }
      return outbuf_size - lib_zstream_unpack.avail_out;
    break;

    default:
      lib_error = result;
      return 0;
  }
}

void up_unpack_end() {
  z_inflateEnd( &lib_zstream_unpack );
}


