/* ioapi.h -- IO base function header for compress/uncompress .zip
   part of the MiniZip project - ( http://www.winimage.com/zLibDll/minizip.html )

         Copyright (C) 1998-2010 Gilles Vollant (minizip) ( http://www.winimage.com/zLibDll/minizip.html )

         Modifications for Zip64 support
         Copyright (C) 2009-2010 Mathias Svensson ( http://result42.com )
 
         Modifications for modernization of code
         Copyright (C) 2015 Nolan O'Brien ( http://www.nsprogrammer.com )

         For more info read MiniZip_info.txt

*/

#if (defined(_WIN32))
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "ioapi.h"

voidpf call_zopen64(const zlib_filefunc64_32_def* pfilefunc, const void* filename, int mode)
{
    if (pfilefunc->zfile_func64.zopen64_file != NULL) {
        return (*(pfilefunc->zfile_func64.zopen64_file)) (pfilefunc->zfile_func64.opaque, filename, mode);
    } else {
        return (*(pfilefunc->zopen32_file))(pfilefunc->zfile_func64.opaque, (const char*)filename, mode);
    }
}

long call_zseek64(const zlib_filefunc64_32_def* pfilefunc, voidpf filestream, ZPOS64_T offset, int origin)
{
    if (pfilefunc->zfile_func64.zseek64_file != NULL) {
        return (*(pfilefunc->zfile_func64.zseek64_file)) (pfilefunc->zfile_func64.opaque, filestream, offset, origin);
    } else {
        uLong offsetTruncated = (uLong)offset;
        if (offsetTruncated != offset) {
            return -1;
        } else {
            return (*(pfilefunc->zseek32_file))(pfilefunc->zfile_func64.opaque, filestream, offsetTruncated, origin);
        }
    }
}

ZPOS64_T call_ztell64(const zlib_filefunc64_32_def* pfilefunc, voidpf filestream)
{
    if (pfilefunc->zfile_func64.zseek64_file != NULL) {
        return (*(pfilefunc->zfile_func64.ztell64_file)) (pfilefunc->zfile_func64.opaque, filestream);
    } else {
        long tell_long = (*(pfilefunc->ztell32_file))(pfilefunc->zfile_func64.opaque, filestream);
        return (ZPOS64_T)tell_long;
    }
}

void fill_zlib_filefunc64_32_def_from_filefunc32(zlib_filefunc64_32_def* p_filefunc64_32, const zlib_filefunc_def* p_filefunc32)
{
    p_filefunc64_32->zfile_func64.zopen64_file = NULL;
    p_filefunc64_32->zopen32_file = p_filefunc32->zopen_file;
    p_filefunc64_32->zfile_func64.zerror_file = p_filefunc32->zerror_file;
    p_filefunc64_32->zfile_func64.zread_file = p_filefunc32->zread_file;
    p_filefunc64_32->zfile_func64.zwrite_file = p_filefunc32->zwrite_file;
    p_filefunc64_32->zfile_func64.ztell64_file = NULL;
    p_filefunc64_32->zfile_func64.zseek64_file = NULL;
    p_filefunc64_32->zfile_func64.zclose_file = p_filefunc32->zclose_file;
    p_filefunc64_32->zfile_func64.zerror_file = p_filefunc32->zerror_file;
    p_filefunc64_32->zfile_func64.opaque = p_filefunc32->opaque;
    p_filefunc64_32->zseek32_file = p_filefunc32->zseek_file;
    p_filefunc64_32->ztell32_file = p_filefunc32->ztell_file;
}



static voidpf   ZCALLBACK fopen_file_func       OF((voidpf opaque, const char* filename, int mode));
static uLong    ZCALLBACK fread_file_func       OF((voidpf opaque, voidpf stream, void* buf, uLong size));
static uLong    ZCALLBACK fwrite_file_func      OF((voidpf opaque, voidpf stream, const void* buf, uLong size));
static ZPOS64_T ZCALLBACK ftell64_file_func     OF((voidpf opaque, voidpf stream));
static long     ZCALLBACK fseek64_file_func     OF((voidpf opaque, voidpf stream, ZPOS64_T offset, int origin));
static int      ZCALLBACK fclose_file_func      OF((voidpf opaque, voidpf stream));
static int      ZCALLBACK ferror_file_func      OF((voidpf opaque, voidpf stream));

static voidpf ZCALLBACK fopen_file_func(voidpf opaque, const char* filename, int m)
{
    FILE* file = NULL;
    const char* mode_fopen = NULL;
    zlib_filefunc_mode mode = (zlib_filefunc_mode)m;
    if ((mode & zlib_filefunc_mode_readwritefilter) == zlib_filefunc_mode_read) {
        mode_fopen = "rb";
    } else if (mode & zlib_filefunc_mode_existing) {
        mode_fopen = "r+b";
    } else if (mode & zlib_filefunc_mode_create) {
        mode_fopen = "wb";
    }

    if ((filename!=NULL) && (mode_fopen != NULL)) {
        file = fopen(filename, mode_fopen);
    }
    return file;
}

static voidpf ZCALLBACK fopen64_file_func (voidpf opaque, const void* filename, int m)
{
    FILE* file = NULL;
    const char* mode_fopen = NULL;
    zlib_filefunc_mode mode = (zlib_filefunc_mode)m;
    if ((mode & zlib_filefunc_mode_readwritefilter) == zlib_filefunc_mode_read) {
        mode_fopen = "rb";
    } else if (mode & zlib_filefunc_mode_existing) {
        mode_fopen = "r+b";
    } else if (mode & zlib_filefunc_mode_create) {
        mode_fopen = "wb";
    }

    if ((filename != NULL) && (mode_fopen != NULL)) {
        file = fopen((const char*)filename, mode_fopen);
    }
    return file;
}


static uLong ZCALLBACK fread_file_func(voidpf opaque, voidpf stream, void* buf, uLong size)
{
    uLong ret = (uLong)fread(buf, 1, (size_t)size, (FILE *)stream);
    return ret;
}

static uLong ZCALLBACK fwrite_file_func(voidpf opaque, voidpf stream, const void* buf, uLong size)
{
    uLong ret = (uLong)fwrite(buf, 1, (size_t)size, (FILE *)stream);
    return ret;
}

static long ZCALLBACK ftell_file_func(voidpf opaque, voidpf stream)
{
    long ret = ftell((FILE *)stream);
    return ret;
}


static ZPOS64_T ZCALLBACK ftell64_file_func(voidpf opaque, voidpf stream)
{
    ZPOS64_T ret = (ZPOS64_T)ftello((FILE *)stream);
    return ret;
}

static long ZCALLBACK fseek_file_func(voidpf  opaque, voidpf stream, uLong offset, int origin)
{
    int fseek_origin = 0;
    zlib_filefunc_seek seek = (zlib_filefunc_seek)origin;
    switch (seek)
    {
        case zlib_filefunc_seek_cur:
            fseek_origin = SEEK_CUR;
            break;
        case zlib_filefunc_seek_end:
            fseek_origin = SEEK_END;
            break;
        case zlib_filefunc_seek_set:
            fseek_origin = SEEK_SET;
            break;
        default:
            return -1;
    }

    if (fseek((FILE *)stream, (long)offset, fseek_origin) != 0) {
        return -1;
    }

    return 0;
}

static long ZCALLBACK fseek64_file_func(voidpf  opaque, voidpf stream, ZPOS64_T offset, int origin)
{
    int fseek_origin = 0;
    zlib_filefunc_seek seek = (zlib_filefunc_seek)origin;
    switch (seek)
    {
        case zlib_filefunc_seek_cur:
            fseek_origin = SEEK_CUR;
            break;
        case zlib_filefunc_seek_end:
            fseek_origin = SEEK_END;
            break;
        case zlib_filefunc_seek_set:
            fseek_origin = SEEK_SET;
            break;
        default:
            return -1;
    }

    if(fseeko((FILE *)stream, (long)offset, fseek_origin) != 0) {
        return -1;
    }

    return 0;
}


static int ZCALLBACK fclose_file_func(voidpf opaque, voidpf stream)
{
    int ret = fclose((FILE *)stream);
    return ret;
}

static int ZCALLBACK ferror_file_func(voidpf opaque, voidpf stream)
{
    int ret = ferror((FILE *)stream);
    return ret;
}

void fill_fopen_filefunc(zlib_filefunc_def* pzlib_filefunc_def)
{
    pzlib_filefunc_def->zopen_file = fopen_file_func;
    pzlib_filefunc_def->zread_file = fread_file_func;
    pzlib_filefunc_def->zwrite_file = fwrite_file_func;
    pzlib_filefunc_def->ztell_file = ftell_file_func;
    pzlib_filefunc_def->zseek_file = fseek_file_func;
    pzlib_filefunc_def->zclose_file = fclose_file_func;
    pzlib_filefunc_def->zerror_file = ferror_file_func;
    pzlib_filefunc_def->opaque = NULL;
}

void fill_fopen64_filefunc(zlib_filefunc64_def*  pzlib_filefunc_def)
{
    pzlib_filefunc_def->zopen64_file = fopen64_file_func;
    pzlib_filefunc_def->zread_file = fread_file_func;
    pzlib_filefunc_def->zwrite_file = fwrite_file_func;
    pzlib_filefunc_def->ztell64_file = ftell64_file_func;
    pzlib_filefunc_def->zseek64_file = fseek64_file_func;
    pzlib_filefunc_def->zclose_file = fclose_file_func;
    pzlib_filefunc_def->zerror_file = ferror_file_func;
    pzlib_filefunc_def->opaque = NULL;
}
