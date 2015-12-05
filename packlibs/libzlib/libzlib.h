/*
  libzlib.h
  (c) KoDi studio, 2015
*/

#ifndef __LIBZLIB_H__
#define __LIBZLIB_H__

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

#define DLL_NAME "ZLIB"
#define DLL_VERSION 128

typedef unsigned long long int up_datasize_t;

#ifdef __cplusplus
extern "C" {
#endif

DLL_EXPORT const char* up_info_name();
DLL_EXPORT int up_info_version();
DLL_EXPORT const char* up_last_error();

DLL_EXPORT void up_pack_init( up_datasize_t );
DLL_EXPORT size_t up_pack_chunk( void*, size_t, void*, size_t );
DLL_EXPORT void up_pack_end();

DLL_EXPORT void up_unpack_init( up_datasize_t );
DLL_EXPORT size_t up_unpack_chunk( void*, size_t, void*, size_t );
DLL_EXPORT void up_unpack_end();

#ifdef __cplusplus
}
#endif

#endif // __LIBZLIB_H__
