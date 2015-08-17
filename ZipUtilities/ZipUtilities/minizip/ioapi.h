/* ioapi.h -- IO base function header for compress/uncompress .zip
   part of the MiniZip project - ( http://www.winimage.com/zLibDll/minizip.html )

         Copyright (C) 1998-2010 Gilles Vollant (minizip) ( http://www.winimage.com/zLibDll/minizip.html )

         Modifications for Zip64 support
         Copyright (C) 2009-2010 Mathias Svensson ( http://result42.com )

         For more info read MiniZip_info.txt

         Changes

    Oct-2009 - Defined ZPOS64_T to fpos_t on windows and u_int64_t on linux. (might need to find a better why for this)
    Oct-2009 - Change to fseeko64, ftello64 and fopen64 so large files would work on linux.
               More if/def section may be needed to support other platforms
    Oct-2009 - Defined fxxxx64 calls to normal fopen/ftell/fseek so they would compile on windows.
                          (but you should use iowin32.c for windows instead)
    Aug-2015 - Remove indirection to fread/fwrite/fopen/fclose/fseeko/ftello functions.
                    This will compromise compatibility and should be considered a fork.
                    Windows is no longer supported.
*/

#ifndef _ZLIBIOAPI64_H
#define _ZLIBIOAPI64_H

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "zlib.h"

/* a type choosen by DEFINE */
#ifdef HAVE_64BIT_INT_CUSTOM
 typedef  64BIT_INT_CUSTOM_TYPE ZPOS64_T;
#else
 #ifdef HAS_STDINT_H
 #include "stdint.h"
 typedef uint64_t ZPOS64_T;
 #else
  #if defined(_MSC_VER) || defined(__BORLANDC__)
   typedef unsigned __int64 ZPOS64_T;
  #else
   typedef unsigned long long int ZPOS64_T;
  #endif
 #endif
#endif



#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    mz_fopen_mode_read         = 1 << 0,
    mz_fopen_mode_write        = 1 << 1,
    mz_fopen_mode_existing     = 1 << 2,
    mz_fopen_mode_create       = 1 << 3,
} mz_fopen_mode;

static mz_fopen_mode mz_fopen_mode_readwritefilter = mz_fopen_mode_read | mz_fopen_mode_write;

const char * mz_fopen_mode_to_str(mz_fopen_mode mode);

#ifndef SEEK_SET
#define SEEK_SET    (0)
#endif

#ifndef SEEK_CUR
#define SEEK_CUR    (1)
#endif

#ifndef SEEK_END
#define SEEK_END    (2)
#endif

/* ===========================================================================
    Read a byte from a gz_stream; update next_in and avail_in. Return EOF for end of file.
    IN assertion: the stream s has been sucessfully opened for reading.
*/
int mz_getByte(FILE* filestream, unsigned char* pc);

/* ===========================================================================
 Reads a short, long or long long in LSB order from the given gz_stream.
 */
int mz_getShort(FILE* filestream, unsigned short* pX);
int mz_getLong(FILE* filestream, unsigned long* pX);
int mz_getLongLong(FILE* filestream, ZPOS64_T* pX);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // _ZLIBIOAPI64_H
