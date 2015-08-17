/* ioapi.h -- IO base function header for compress/uncompress .zip
   part of the MiniZip project - ( http://www.winimage.com/zLibDll/minizip.html )

         Copyright (C) 1998-2010 Gilles Vollant (minizip) ( http://www.winimage.com/zLibDll/minizip.html )

         Modifications for Zip64 support
         Copyright (C) 2009-2010 Mathias Svensson ( http://result42.com )
 
         Modifications for modernization of code
         Copyright (C) 2015 Nolan O'Brien ( http://www.nsprogrammer.com )

         For more info read MiniZip_info.txt

*/

#include "ioapi.h"

const char * mz_fopen_mode_to_str(mz_fopen_mode mode)
{
    const char* mode_fopen = NULL;
    if ((mode & mz_fopen_mode_readwritefilter) == mz_fopen_mode_read) {
        mode_fopen = "rb";
    } else if (mode & mz_fopen_mode_existing) {
        mode_fopen = "r+b";
    } else if (mode & mz_fopen_mode_create) {
        mode_fopen = "wb";
    }
    return mode_fopen;
}

int mz_getByte(FILE *filestream, unsigned char* pi)
{
    unsigned char c;
    size_t bytesRead = fread(&c, 1, 1, filestream);
    if (bytesRead == 1) {
        *pi = c;
    } else {
        if (ferror(filestream)) {
            return Z_ERRNO;
        }
    }

    return Z_OK;
}

int mz_getShort(FILE *filestream, unsigned short* pX)
{
    unsigned short x = 0;
    unsigned char c = 0;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x = (unsigned short)c;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((unsigned short)c) << 8;

    *pX = x;
    return Z_OK;
}

int mz_getLong(FILE* filestream, unsigned long* pX)
{
    unsigned long x = 0;
    unsigned char c = 0;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x = (unsigned long)c;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((unsigned long)c) << 8;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((unsigned long)c) << 16;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((unsigned long)c) << 24;

    *pX = x;
    return Z_OK;
}

int mz_getLongLong(FILE* filestream, ZPOS64_T* pX)
{
    ZPOS64_T x = 0;
    unsigned char c = 0;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x = (ZPOS64_T)c;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 8;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 16;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 24;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 32;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 40;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 48;

    if (Z_OK != mz_getByte(filestream, &c)) {
        *pX = 0;
        return Z_ERRNO;
    }
    x |= ((ZPOS64_T)c) << 56;

    *pX = x;
    return Z_OK;
}
