/*
  libhuff.h
  (c) KoDi studio, 2015
*/

#ifndef __LIBHUFF_H__
#define __LIBHUFF_H__

#include <stdio.h>

#ifndef DLL_EXPORT
  #if defined(_WIN32)
    #define DLL_EXPORT extern "C" __declspec( dllexport )
    #include <malloc.h>
  #endif
  #if defined(__APPLE__) && defined(__MACH__)
    #define DLL_EXPORT __attribute__(( visibility( "default" )))
    #include <malloc>
  #endif
  #ifndef DLL_EXPORT
    #error "OS not supported!"
  #endif
#endif

#define DLL_NAME 'HUFF'
#define DLL_VERSION 1

#define E_OK 0
#define E_BAD_INPUT 1
#define E_LOST_SIZE 2

DLL_EXPORT unsigned int __cdecl get_name();
DLL_EXPORT int __cdecl get_version();

DLL_EXPORT void* __cdecl compress( void*, size_t );
DLL_EXPORT void* __cdecl decompress( void*, size_t, size_t );
DLL_EXPORT size_t __cdecl compsize();

DLL_EXPORT int __cdecl get_err();
DLL_EXPORT const char* __cdecl err_str( int );

DLL_EXPORT void* __cdecl realloc_mem( void*, size_t );
DLL_EXPORT void __cdecl free_mem( void* );

#endif // __LIBHUFF_H__
