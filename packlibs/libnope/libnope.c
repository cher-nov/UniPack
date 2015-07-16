/*
  libnope.c
  (c) KoDi studio, 2015
*/

#include <stdlib.h>
#include <memory.h>
#include "libnope.h"

int lib_error = E_OK;
size_t lib_compsize = 0;

/* initialization functions */

unsigned int get_name() {
  return DLL_NAME;
}

int get_version() {
  return DLL_VERSION;
}

/* compress functions */

void* compress( void* data, size_t size_data ) {
  if (data == NULL)  {
    lib_error = E_BAD_INPUT;
    return NULL;
  }

  if (lib_compsize != 0) {
    lib_error = E_LOST_SIZE;
    return NULL;
  }

  lib_compsize = size_data;
  return memcpy( malloc(size_data), data, size_data );
}

void* decompress( void* data, size_t size_data, size_t out_size ) {
  if (data == NULL) {
    lib_error = E_BAD_INPUT;
    return NULL;
  }

  return memcpy( malloc(out_size), data, size_data );
}

size_t compsize() {
  size_t retsz = lib_compsize;
  lib_compsize = 0;
  return retsz;
}

/* errors functions */

int get_err() {
  int errlev = lib_error;
  lib_error = E_OK;
  return errlev;
}

const char* err_str( int errlev ) {
  switch (errlev) {
    case E_OK:
      return "no errors";
    case E_BAD_INPUT:
      return "wrong input data";
    case E_LOST_SIZE:
      return "take off your data size";
  }
  return "unknown error";
}

/* memory management */

void* realloc_mem( void* ptr, size_t size_new ) {
  return realloc( ptr, size_new );
}

void free_mem( void* ptr ) {
  free( ptr );
}
