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
static up_datasize_t lib_pack_size = 0;
static up_datasize_t lib_unpack_size = 0;
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
  lib_pack_size = pack_size;
  lib_zstream_pack.zalloc = Z_NULL;
  lib_zstream_pack.zfree = Z_NULL;
  lib_zstream_pack.opaque = Z_NULL;
  z_deflateInit( &lib_zstream_pack, Z_BEST_COMPRESSION );
}

size_t up_pack_chunk(
  void* chunk_ptr, size_t chunk_size, void* outbuf_ptr, size_t outbuf_size
) {
  lib_zstream_pack.next_in = chunk_ptr;
  lib_zstream_pack.avail_in = chunk_size;
  lib_zstream_pack.next_out = outbuf_ptr;
  lib_zstream_pack.avail_out = outbuf_size;

  int result, flush;
  flush = (chunk_size < lib_pack_size) ? Z_NO_FLUSH : Z_FINISH;
  result = z_deflate( &lib_zstream_pack, flush );
  size_t packed_size;

  switch (result) {
    case Z_OK:
    case Z_STREAM_END:
      packed_size = chunk_size - lib_zstream_pack.avail_in;
      lib_pack_size -= packed_size;
      return packed_size;
    break;

    default:
      lib_error = result;
      return 0;
  }
}

void up_pack_end() {
  z_deflateEnd( &lib_zstream_pack );
  lib_pack_size = 0;
}

/* decompression functions */

void up_unpack_init( up_datasize_t unpack_size ) {
  lib_unpack_size = unpack_size;
  lib_zstream_unpack.zalloc = Z_NULL;
  lib_zstream_unpack.zfree = Z_NULL;
  lib_zstream_unpack.opaque = Z_NULL;
  lib_zstream_unpack.avail_in = 0;
  lib_zstream_unpack.next_in = Z_NULL;
  z_inflateInit( &lib_zstream_unpack );
}

size_t up_unpack_chunk(
  void* chunk_ptr, size_t chunk_size, void* outbuf_ptr, size_t outbuf_size
) {
  lib_zstream_unpack.next_in = chunk_ptr;
  lib_zstream_unpack.avail_in = chunk_size;
  lib_zstream_unpack.next_out = outbuf_ptr;
  lib_zstream_unpack.avail_out = outbuf_size;

  int result;
  result = z_inflate( &lib_zstream_unpack, Z_NO_FLUSH );
  size_t unpacked_size;

  switch (result) {
    case Z_OK:
    case Z_STREAM_END:
      unpacked_size = outbuf_size - lib_zstream_unpack.avail_out;
      lib_unpack_size -= unpacked_size;
      return unpacked_size;
    break;

    default:
      lib_error = result;
      return 0;
  }
}

void up_unpack_end() {
  z_inflateEnd( &lib_zstream_unpack );
  lib_unpack_size = 0;
}


