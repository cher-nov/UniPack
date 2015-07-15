/*
 HUFF.H
 (c) KoDi studio, 2015
 */

#ifndef __HUFF_H__
#define __HUFF_H__

#include <stdio.h>

#ifndef DLL_EXPORT
    #if defined(_WIN32)
        #define DLL_EXPORT __declspec( dllexport )
    #endif
    #if defined(__APPLE__) && defined(__MACH__)
        #define DLL_EXPORT __attribute__(( visibility( "default" )))
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

DLL_EXPORT int __cdecl get_name();
DLL_EXPORT int __cdecl get_version();

DLL_EXPORT void* __cdecl compress( void*, int );
DLL_EXPORT void* __cdecl decompress( void*, int, int );

DLL_EXPORT int __cdecl get_err();
DLL_EXPORT char* __cdecl err_str( int );

#endif // __HUFF_H__