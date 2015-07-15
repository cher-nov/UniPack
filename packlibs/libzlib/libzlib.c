/*
  libzlib.c
  (c) KoDi studio, 2015
*/

#define Z_PREFIX

#include <stdlib.h>
#include <memory.h>
#include "zlib/zlib.h"
#include "libzlib.h"

int lib_error = Z_OK;
unsigned int lib_compsize = 0;

/* initialization functions */

int get_name() {
  return DLL_NAME;
}

int get_version() {
  return DLL_VERSION;
}

/* compress functions */

void* up_pack( void* data, int size_data ) {
  if (lib_compsize > 0) {
    lib_error = Z_ERRNO;
    return NULL;
  }

  uLongf outlen = z_compressBound( size_data );
  Bytef* outbuf = malloc( outlen );
  lib_error = z_compress2( outbuf, &outlen, (Bytef*)data, size_data,
                           Z_BEST_COMPRESSION );

  if ( lib_error == Z_OK ) {
    lib_compsize = outlen;
    return realloc( outbuf, outlen );
  } else {
    lib_compsize = 0;
    free( outbuf );
    return NULL;
  }
}

void* up_unpack( void* data, int size_data, int out_size ) {
  Bytef* outbuf = malloc( out_size );
  uLongf outlen = out_size;
  lib_error = z_uncompress( outbuf, &outlen, (Bytef*)data, size_data );

  if ( lib_error == Z_OK ) {
    return (void*)outbuf;
  } else {
    free( outbuf );
    return NULL;
  }
}

/* errors functions */

int get_err() {
  int err = lib_error;
  lib_error = Z_OK;
  return err;
}

const char* err_str( int a_error ) {
  return z_zError( a_error );
}

/* additional */

void free_mem( void* ptr ) {
  free( ptr );
}
