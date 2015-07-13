/*
 HUFF.H
 (c) KoDi studio, 2015
 */

#include "huff.h"
#include <memory.h>
#include <stdlib.h>

int lib_error = E_OK;
int lib_compsize = 0;

/* initialization functions */

int get_name()  {
    return DLL_NAME;
}

int get_version()  {
    return DLL_VERSION;
}

/* compress functions */

void* compress(void* data, int size_data)  {
    /* check errors */
    if (data == NULL)  {
        lib_error = E_BAD_INPUT;
        return NULL;
    }
    if (lib_compsize != 0) {
        lib_error = E_LOST_SIZE;
        return NULL;
    }
    
    /* compress alogorithm Huffman by Dima */
    
    /* code here */
    lib_compsize = size_data;
    return 0;
}

void* decompress(void* data, int size_data, int out_size)  {
    /*check errors */
    if (data == NULL)  {
        lib_error = E_BAD_INPUT;
        return NULL;
    }
    
    /* decompress algorithm Huffman by Dima */
    
    /* code here */
    
    return 0;
    
}

/* errors functions */

int get_err() {
    int err = lib_error;
    lib_error = E_OK;
    return err;
}

char* err_str(int a_error)  {
    switch (a_error)  {
        case E_OK:
            return "no errors";
        case E_BAD_INPUT:
            return "wrong input data";
        case E_LOST_SIZE:
            return "take off your data size";
    }
    return "unknown error";
}