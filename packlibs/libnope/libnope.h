/*
  libnope.h
  (c) KoDi studio, 2015
*/

#ifndef __LIBNOPE_H__
#define __LIBNOPE_H__

#include <stdio.h>

#ifndef DLL_EXPORT
  #if defined(_WIN32)
    #define DLL_EXPORT __cdecl __declspec( dllexport )
  #endif
  #if defined(__APPLE__) && defined(__MACH__)
    #define DLL_EXPORT __cdecl __attribute__(( visibility( "default" )))
  #endif
  #ifndef DLL_EXPORT
    #error "OS not supported!"
  #endif
#endif

#define DLL_NAME 'NOPE'
#define DLL_VERSION 1

#define E_OK 0
#define E_BAD_INPUT 1
#define E_LOST_SIZE 2

DLL_EXPORT unsigned int get_name();
DLL_EXPORT int get_version();

DLL_EXPORT void* compress( void*, size_t );
DLL_EXPORT void* decompress( void*, size_t, size_t );
DLL_EXPORT size_t compsize();

DLL_EXPORT int get_err();
DLL_EXPORT const char* err_str( int );
DLL_EXPORT void free_mem( void* );

#endif // __LIBNOPE_H__