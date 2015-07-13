//
//  Created by Kodi studio (Томак Дмитрий, Николай Глущенко) on 13.07.15.
//  Copyright (c) 2015 Kodi studio. All rights reserved.
//

#ifndef __huff__huff__

    #define __huff__huff__

    #include <stdio.h>

    /* initialization dll property */

    #define DLL_VERSION 1
    #define DLL_NAME 'HUFF'

    /* end initialization */

    #ifndef DLL_EXPORT  /* defined(DLL_EXPORT) */

        #ifdef __WINDOWS__

            #define DLL_EXPORT __cdecl __declspec( dllexport )  /* defined(export for windows) */

        #elif __APPLE__

            #define DLL_EXPORT __cdecl __attribute__(( visibility( "default" )))  /* defined(export for mac os) */

        #else

            #error "OS not supported!"

        #endif

    #endif /* end define DDL_EXPORT */

    /* give information about dll */

    int get_name();
    int get_version();

    /* initialization compress functions */

    void* compress(void* data, int size_data);
    void* decompress(void* data, int size_data, int out_size);

    /* initialization errors defines and functions */

    /* error defines */

    #define E_OK 0
    #define E_BAD_INPUT 1
    #define E_LOST_SIZE 2

    /* error functions */

    int get_err();
    char* err_str(int a_error);

#endif /* defined(____huff__) */