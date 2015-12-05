/*
  libnope.h
  (c) KoDi studio, 2015
*/

#ifndef __LIBNOPE_H__
#define __LIBNOPE_H__

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
#define DLL_VERSION 1

#define UP_OK 0
#define UP_UNKNOWN_ERROR (-1)
#define UP_INTERNAL_ERROR (-2)
#define UP_DATA_ERROR (-3)
#define UP_MEMORY_ERROR (-4)

typedef unsigned long long int up_datasize_t;

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORT char* up_info_name();
DLL_EXPORT int up_info_version();
DLL_EXPORT char* up_last_error();

DLL_EXPORT void up_pack_init( up_datasize_t );
DLL_EXPORT size_t up_pack_chunk( void*, size_t, void*, size_t );
DLL_EXPORT void up_pack_end();

DLL_EXPORT void up_unpack_init( up_datasize_t );
DLL_EXPORT size_t up_unpack_chunk( void*, size_t, void*, size_t );
DLL_EXPORT void up_unpack_end();

#ifdef __cplusplus
}
#endif

#endif // __LIBNOPE_H__
