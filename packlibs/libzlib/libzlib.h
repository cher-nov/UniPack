/*
  libzlib.h
  (c) KoDi studio, 2015
*/

#ifndef __LIBZLIB_H__
#define __LIBZLIB_H__

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

#define DLL_NAME 'ZLIB'
#define DLL_VERSION 128

DLL_EXPORT int get_name();
DLL_EXPORT int get_version();

DLL_EXPORT void* up_pack( void*, int );
DLL_EXPORT void* up_unpack( void*, int, int );

DLL_EXPORT int get_err();
DLL_EXPORT const char* err_str( int );
DLL_EXPORT void free_mem( void* ptr );

#endif // __LIBZLIB_H__
