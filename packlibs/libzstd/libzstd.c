/*
  libzstd.c
  (c) KoDi studio, 2016
*/

#include "zstd/zbuff_static.h"
#include "zstd/error_public.h"
#include "libzstd.h"

static int lib_error = ZSTD_error_no_error;

static ZBUFF_CCtx* lib_pack_ctx;
static char* lib_pack_chunk;
static size_t lib_pack_chunk_sz;
static up_datasize_t lib_pack_left_sz = 0;
static bool lib_pack_data_end;
static size_t lib_pack_flush_sz = 0;

static ZBUFF_DCtx* lib_unpack_ctx;
static char* lib_unpack_chunk;
static size_t lib_unpack_chunk_sz;
static up_datasize_t lib_unpack_left_sz;

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
    lib_error = ZSTD_error_no_error;
  }
  return (err != ZSTD_error_no_error);
}

const char* up_error_msg( int err_code ) {
  if (err_code == ZSTD_error_no_error) {
    return NULL;
  } else {
    return ZSTD_getErrorName(err_code);
  }
}

/* compression functions */

void up_pack_init( up_datasize_t pack_size ) {
  lib_pack_ctx = ZBUFF_createCCtx();
  size_t init_code = ZBUFF_compressInit( lib_pack_ctx, ZSTD_maxCLevel() );
  if ( ZBUFF_isError( init_code ) ) {
    lib_error = (int)init_code;
  } else {
    lib_pack_data_end = false;
    lib_pack_left_sz = pack_size;
    lib_pack_flush_sz = 0;
  }
}

void up_pack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_pack_chunk = chunk_ptr;
  lib_pack_chunk_sz = chunk_size;
}

size_t up_pack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {

  size_t result, done_size, read_size, chunk_left;
  done_size = outbuf_size;

  if (lib_pack_left_sz > 0) {
    read_size = lib_pack_chunk_sz;
    result = ZBUFF_compressContinue( lib_pack_ctx,
      outbuf_ptr, &done_size, lib_pack_chunk, &read_size );
  } else {
    if (lib_pack_flush_sz == 0) {
      result = ZBUFF_compressEnd( lib_pack_ctx, outbuf_ptr, &done_size );
    } else {
      result = ZBUFF_compressFlush( lib_pack_ctx, outbuf_ptr, &done_size );
    }
  }

  if ( !ZBUFF_isError( result ) ) {
    if (lib_pack_left_sz > 0) {
      lib_pack_chunk += read_size;
      lib_pack_chunk_sz -= read_size;
      lib_pack_left_sz -= read_size;
      chunk_left = lib_pack_chunk_sz;
    } else {
      lib_pack_data_end = true;
      lib_pack_flush_sz = result;
      chunk_left = 0;
    }
    if (data_left != NULL) { *data_left = chunk_left; }
  } else {
    lib_error = (int)result;
  }

  return done_size;
}

up_datasize_t up_pack_left() {
  return lib_pack_left_sz;
}

bool up_pack_done() {
  // we don't use (lib_pack_left_sz > 0) to determine if all data were
  // processed because ZStandard can accumulate data, so if it will
  // accumulate whole file before first flush, this function will
  // return TRUE once
  return ( lib_pack_data_end && (lib_pack_flush_sz == 0) );
}

void up_pack_end() {
  ZBUFF_freeCCtx( lib_pack_ctx );
}

/* decompression functions */

void up_unpack_init( up_datasize_t unpack_size ) {
  lib_unpack_ctx = ZBUFF_createDCtx();
  size_t init_code = ZBUFF_decompressInit( lib_unpack_ctx );
  if ( ZBUFF_isError( init_code ) ) {
    lib_error = (int)init_code;
  } else {
    lib_unpack_left_sz = unpack_size;
  }
}

void up_unpack_chunk( void* chunk_ptr, size_t chunk_size ) {
  lib_unpack_chunk = chunk_ptr;
  lib_unpack_chunk_sz = chunk_size;
}

size_t up_unpack_step( void* outbuf_ptr, size_t outbuf_size, size_t* data_left ) {

  size_t result, done_size, read_size;
  done_size = outbuf_size;
  read_size = lib_unpack_chunk_sz;
  result = ZBUFF_decompressContinue( lib_unpack_ctx,
    outbuf_ptr, &done_size, lib_unpack_chunk, &read_size );

  if ( !ZBUFF_isError( result ) ) {
    lib_unpack_chunk += read_size;
    lib_unpack_chunk_sz -= read_size;
    lib_unpack_left_sz -= read_size;
    if (data_left != NULL) { *data_left = lib_unpack_chunk_sz; }
  } else {
    lib_error = (int)result;
  }

  return done_size;
}

up_datasize_t up_unpack_left() {
  return lib_unpack_left_sz;
}

bool up_unpack_done() {
  return (lib_unpack_left_sz == 0);
}

void up_unpack_end() {
  ZBUFF_freeDCtx( lib_unpack_ctx );
}


