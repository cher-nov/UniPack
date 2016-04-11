/*
  libnope.h
  (c) KoDi studio, 2015
*/

#ifndef __LIBNOPE_H__
#define __LIBNOPE_H__

#include <stdbool.h>

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

#define DLL_NAME "NOPE"
#define DLL_VERSION 0x1000

#define UP_OK 0
#define UP_UNKNOWN_ERROR (-1)
#define UP_INTERNAL_ERROR (-2)
#define UP_DATA_ERROR (-3)
#define UP_MEMORY_ERROR (-4)

typedef unsigned long long int up_datasize_t;

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORT const char* up_info_name();
DLL_EXPORT int up_info_version();
DLL_EXPORT bool up_has_error( int* );
DLL_EXPORT const char* up_error_msg( int );

DLL_EXPORT void up_pack_init( up_datasize_t );
DLL_EXPORT void up_pack_chunk( void*, size_t );
DLL_EXPORT size_t up_pack_step( void*, size_t, size_t* );
DLL_EXPORT up_datasize_t up_pack_left();
DLL_EXPORT bool up_pack_done();
DLL_EXPORT void up_pack_end();

DLL_EXPORT void up_unpack_init( up_datasize_t );
DLL_EXPORT void up_unpack_chunk( void*, size_t );
DLL_EXPORT size_t up_unpack_step( void*, size_t, size_t* );
DLL_EXPORT up_datasize_t up_unpack_left();
DLL_EXPORT bool up_unpack_done();
DLL_EXPORT void up_unpack_end();

#ifdef __cplusplus
}
#endif

#endif // __LIBNOPE_H__
