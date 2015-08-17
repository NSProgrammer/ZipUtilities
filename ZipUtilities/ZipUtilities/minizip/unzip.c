/* unzip.c -- IO for uncompress .zip files using zlib
   Version 1.1, February 14h, 2010
   part of the MiniZip project - ( http://www.winimage.com/zLibDll/minizip.html )

         Copyright (C) 1998-2010 Gilles Vollant (minizip) ( http://www.winimage.com/zLibDll/minizip.html )

         Modifications of Unzip for Zip64
         Copyright (C) 2007-2008 Even Rouault

         Modifications for Zip64 support on both zip and unzip
         Copyright (C) 2009-2010 Mathias Svensson ( http://result42.com )

         For more info read MiniZip_info.txt


  ------------------------------------------------------------------------------------
  Decryption code comes from crypt.c by Info-ZIP but has been greatly reduced in terms of
  compatibility with older software. The following is from the original crypt.c.
  Code woven in by Terry Thorsen 1/2003.

  Copyright (c) 1990-2000 Info-ZIP.  All rights reserved.

  See the accompanying file LICENSE, version 2000-Apr-09 or later
  (the contents of which are also included in zip.h) for terms of use.
  If, for some reason, all these files are missing, the Info-ZIP license
  also may be found at:  ftp://ftp.info-zip.org/pub/infozip/license.html

        crypt.c (full version) by Info-ZIP.      Last revised:  [see crypt.h]

  The encryption/decryption parts of this source code (as opposed to the
  non-echoing password parts) were originally written in Europe.  The
  whole source package can be freely distributed, including from the USA.
  (Prior to January 2000, re-export from the US was a violation of US law.)

        This encryption code is a direct transcription of the algorithm from
  Roger Schlafly, described by Phil Katz in the file appnote.txt.  This
  file (appnote.txt) is distributed with the PKZIP program (even in the
  version without encryption capabilities).

        ------------------------------------------------------------------------------------

        Changes in unzip.c

        2007-2008 - Even Rouault - Addition of cpl_unzGetCurrentFileZStreamPos
        2007-2008 - Even Rouault - Decoration of symbol names unz* -> cpl_unz*
        2007-2008 - Even Rouault - Remove old C style function prototypes
        2007-2008 - Even Rouault - Add unzip support for ZIP64

        Copyright (C) 2007-2008 Even Rouault


        Oct-2009 - Mathias Svensson - Removed cpl_* from symbol names (Even Rouault added them but since this is now moved to a new project (minizip64) I renamed them again).
        Oct-2009 - Mathias Svensson - Fixed problem if uncompressed size was > 4G and compressed size was <4G
                                        should only read the compressed/uncompressed size from the Zip64 format if
                                        the size from normal header was 0xFFFFFFFF
        Oct-2009 - Mathias Svensson - Applied some bug fixes from paches recived from Gilles Vollant
        Oct-2009 - Mathias Svensson - Applied support to unzip files with compression mathod BZIP2 (bzip2 lib is required)
                                        Patch created by Daniel Borca

        Jan-2010 - back to unzip and minizip 1.0 name scheme, with compatibility layer

        Copyright (C) 1998 - 2010 Gilles Vollant, Even Rouault, Mathias Svensson
 
 
        Aug-2015 - Nolan O'Brien - Fix compiler warnings and static analysis warnings
        Aug-2015 - Nolan O'Brien - Code clean and style cleanup
        Aug-2015 - Nolan O'Brien - remove 64-bit indirections and remove some crufty attributes (no longer supports all platforms)
 
        Copyright (C) 2015 - Nolan O'Brien

*/


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Matt Connolly 2013-09-12: this was defined in minizip 1.1.
// @see http://www.winimage.com/zLibDll/minizip.html
// Defining it defeats the ability to unzip password protected zip files, so this
// is commented out so that existing tests pass.

//#ifndef NOUNCRYPT
// #define NOUNCRYPT
//#endif

#include "zlib.h"
#include "unzip.h"

#include <stddef.h>
#include <string.h>
#include <stdlib.h>

#include <errno.h>


#ifndef CASESENSITIVITYDEFAULT_NO
 #if !defined(unix) && !defined(CASESENSITIVITYDEFAULT_YES)
  #define CASESENSITIVITYDEFAULT_NO
 #endif
#endif


#ifndef UNZ_BUFSIZE
#define UNZ_BUFSIZE (16 * 1024)
#endif

#ifndef UNZ_MAXFILENAMEINZIP
#define UNZ_MAXFILENAMEINZIP (256)
#endif

#ifndef ALLOC
# define ALLOC(size) (malloc(size))
#endif

#ifndef TRYFREE
# define TRYFREE(p) {if (p) free(p);}
#endif

#define SIZECENTRALDIRITEM (0x2e)
#define SIZEZIPLOCALHEADER (0x1e)

/* unz_file_info_interntal contain internal info about a file in zipfile*/
typedef struct unz_file_info_internal_s
{
    ZPOS64_T offset_curfile;/* relative offset of local header 8 bytes */
} unz_file_info_internal;


/* file_in_zip_read_info_s contain internal information about a file in zipfile,
    when reading and decompress it */
typedef struct
{
    char  *read_buffer;         /* internal buffer for compressed data */
    z_stream stream;            /* zLib stream structure for inflate */

#ifdef HAVE_BZIP2
    bz_stream bstream;          /* bzLib stream structure for bziped */
#endif

    ZPOS64_T pos_in_zipfile;       /* position in byte on the zipfile, for fseek*/
    uLong stream_initialised;   /* flag set if stream structure is initialised*/

    ZPOS64_T offset_local_extrafield;/* offset of the local extra field */
    uInt  size_local_extrafield;/* size of the local extra field */
    ZPOS64_T pos_local_extrafield;   /* position in the local extra field in read*/
    ZPOS64_T total_out_64;

    uLong crc32;                /* crc32 of all data uncompressed */
    uLong crc32_wait;           /* crc32 we must obtain after decompress all */
    ZPOS64_T rest_read_compressed; /* number of byte to be decompressed */
    ZPOS64_T rest_read_uncompressed;/*number of byte to be obtained after decomp*/
    voidpf filestream;        /* io structore of the zipfile */
    uLong compression_method;   /* compression method (0==store) */
    ZPOS64_T byte_before_the_zipfile;/* byte before the zipfile, (>0 for sfx)*/
    int   raw;
} file_in_zip_read_info_s;


/* unz_s contain internal information about the zipfile
*/
typedef struct
{
    voidpf filestream;        /* io structore of the zipfile */
    unz_global_info gi;       /* public global information */
    ZPOS64_T byte_before_the_zipfile;/* byte before the zipfile, (>0 for sfx)*/
    ZPOS64_T num_file;             /* number of the current file in the zipfile*/
    ZPOS64_T pos_in_central_dir;   /* pos of the current file in the central dir*/
    ZPOS64_T current_file_ok;      /* flag about the usability of the current file*/
    ZPOS64_T central_pos;          /* position of the beginning of the central dir*/

    ZPOS64_T size_central_dir;     /* size of the central directory  */
    ZPOS64_T offset_central_dir;   /* offset of start of central directory with
                                   respect to the starting disk number */

    unz_file_info cur_file_info; /* public info about the current file in zip*/
    unz_file_info_internal cur_file_info_internal; /* private info about it*/
    file_in_zip_read_info_s* pfile_in_zip_read; /* structure about the current
                                        file if we are decompressing it */
    int encrypted;

    int isZip64;

#    ifndef NOUNCRYPT
    unsigned long keys[3];     /* keys defining the pseudo-random sequence */
    const unsigned long* pcrc_32_tab;
#    endif
} unz_s;


#ifndef NOUNCRYPT
 #include "crypt.h"
#endif

/* My own strcmpi / strcasecmp */
static int strcmpcasenosensitive_internal(const char* fileName1, const char* fileName2)
{
    do
    {
        char c1 = *(fileName1++);
        char c2 = *(fileName2++);
        if ((c1 >= 'a') && (c1 <= 'z')) {
            c1 -= 0x20;
        }
        if ((c2 >= 'a') && (c2 <= 'z')) {
            c2 -= 0x20;
        }
        if (c1 == '\0') {
            return ((c2 == '\0') ? 0 : -1);
        }
        if (c2 == '\0') {
            return 1;
        }
        if (c1 < c2) {
            return -1;
        }
        if (c1 > c2) {
            return 1;
        }
    } while (1);
}


#ifdef  CASESENSITIVITYDEFAULT_NO
#define CASESENSITIVITYDEFAULTVALUE 2
#else
#define CASESENSITIVITYDEFAULTVALUE 1
#endif

#ifndef STRCMPCASENOSENTIVEFUNCTION
#define STRCMPCASENOSENTIVEFUNCTION strcmpcasenosensitive_internal
#endif

/*
   Compare two filename (fileName1,fileName2).
   If iCaseSenisivity = 1, comparision is case sensitivity (like strcmp)
   If iCaseSenisivity = 2, comparision is not case sensitivity (like strcmpi
                                                                or strcasecmp)
   If iCaseSenisivity = 0, case sensitivity is defaut of your operating system
        (like 1 on Unix, 2 on Windows)

*/
extern int unzStringFileNameCompare(const char*  fileName1,
                                            const char*  fileName2,
                                            int iCaseSensitivity)
{
    if (iCaseSensitivity == 0) {
        iCaseSensitivity = CASESENSITIVITYDEFAULTVALUE;
    }

    if (iCaseSensitivity == 1) {
        return strcmp(fileName1, fileName2);
    }

    return STRCMPCASENOSENTIVEFUNCTION(fileName1 ,fileName2);
}

#ifndef BUFREADCOMMENT
#define BUFREADCOMMENT (0x400)
#endif

/*
  Locate the Central directory of a zipfile (at the end, just before
    the global comment)
*/
static ZPOS64_T unz64local_SearchCentralDir OF((voidpf filestream));
static ZPOS64_T unz64local_SearchCentralDir(voidpf filestream)
{
    unsigned char* buf;
    ZPOS64_T uSizeFile;
    ZPOS64_T uBackRead;
    ZPOS64_T uMaxBack = 0xffff; /* maximum size of global comment */
    ZPOS64_T uPosFound = 0;

    if (fseeko(filestream, 0, SEEK_END) != 0) {
        return 0;
    }

    uSizeFile = (ZPOS64_T)ftello(filestream);

    if (uMaxBack > uSizeFile) {
        uMaxBack = uSizeFile;
    }

    buf = (unsigned char*)ALLOC(BUFREADCOMMENT + 4);
    if (buf == NULL) {
        return 0;
    }

    uBackRead = 4;
    while (uBackRead < uMaxBack) {
        uLong uReadSize;
        ZPOS64_T uReadPos;

        if ((uBackRead + BUFREADCOMMENT) > uMaxBack) {
            uBackRead = uMaxBack;
        } else {
            uBackRead += BUFREADCOMMENT;
        }
        uReadPos = uSizeFile - uBackRead;

        uReadSize = ((BUFREADCOMMENT + 4) < (uSizeFile - uReadPos)) ? (BUFREADCOMMENT + 4) : (uLong)(uSizeFile - uReadPos);
        if (fseeko(filestream, (off_t)uReadPos, SEEK_SET) != 0) {
            break;
        }

        if (fread(buf, 1, uReadSize, filestream) != uReadSize) {
            break;
        }

        for (int i = ((int)uReadSize - 3); (i--) > 0;) {
            if (((*(buf + i + 0)) == 0x50) &&
                ((*(buf + i + 1)) == 0x4b) &&
                ((*(buf + i + 2)) == 0x05) &&
                ((*(buf + i + 3)) == 0x06)) {
                uPosFound = uReadPos + (unsigned int)i;
                break;
            }
        }

        if (uPosFound != 0) {
            break;
        }
    }

    TRYFREE(buf);
    return uPosFound;
}


/*
  Locate the Central directory 64 of a zipfile (at the end, just before
    the global comment)
*/
static ZPOS64_T unz64local_SearchCentralDir64 OF((voidpf filestream));
static ZPOS64_T unz64local_SearchCentralDir64(voidpf filestream)
{
    unsigned char* buf;
    ZPOS64_T uSizeFile;
    ZPOS64_T uBackRead;
    ZPOS64_T uMaxBack = 0xffff; /* maximum size of global comment */
    ZPOS64_T uPosFound = 0;
    uLong uL;
    ZPOS64_T relativeOffset;

    if (fseeko(filestream, 0, SEEK_END) != 0) {
        return 0;
    }

    uSizeFile = (ZPOS64_T)ftello(filestream);

    if (uMaxBack > uSizeFile) {
        uMaxBack = uSizeFile;
    }

    buf = (unsigned char*)ALLOC(BUFREADCOMMENT + 4);
    if (buf == NULL) {
        return 0;
    }

    uBackRead = 4;
    while (uBackRead < uMaxBack) {
        uLong uReadSize;
        ZPOS64_T uReadPos;

        if ((uBackRead + BUFREADCOMMENT) > uMaxBack) {
            uBackRead = uMaxBack;
        } else {
            uBackRead += BUFREADCOMMENT;
        }
        uReadPos = uSizeFile - uBackRead ;

        uReadSize = ((BUFREADCOMMENT + 4) < (uSizeFile - uReadPos)) ?
                     (BUFREADCOMMENT + 4) :
                     (uLong)(uSizeFile - uReadPos);
        if (fseeko(filestream, (off_t)uReadPos, SEEK_SET) != 0) {
            break;
        }

        if (fread(buf, 1, uReadSize, filestream) != uReadSize) {
            break;
        }

        for (int i = ((int)uReadSize - 3); (i--) > 0;) {
            if (((*(buf + i + 0)) == 0x50) &&
                ((*(buf + i + 1)) == 0x4b) &&
                ((*(buf + i + 2)) == 0x06) &&
                ((*(buf + i + 3)) == 0x07)) {
                uPosFound = uReadPos + (unsigned int)i;
                break;
            }
        }

        if (uPosFound!=0)
            break;
    }

    TRYFREE(buf);

    if (uPosFound == 0) {
        return 0;
    }

    /* Zip64 end of central directory locator */
    if (fseeko(filestream, (off_t)uPosFound, SEEK_SET) != 0) {
        return 0;
    }

    /* the signature, already checked */
    if (mz_getLong(filestream, &uL) != UNZ_OK) {
        return 0;
    }

    /* number of the disk with the start of the zip64 end of central directory */
    if (mz_getLong(filestream, &uL) != UNZ_OK) {
        return 0;
    }

    if (uL != 0) {
        return 0;
    }

    /* relative offset of the zip64 end of central directory record */
    if (mz_getLongLong(filestream, &relativeOffset) != UNZ_OK) {
        return 0;
    }

    /* total number of disks */
    if (mz_getLong(filestream, &uL) != UNZ_OK) {
        return 0;
    }
    if (uL != 1) {
        return 0;
    }

    /* Goto end of central directory record */
    if (fseeko(filestream, (off_t)relativeOffset, SEEK_SET) != 0) {
        return 0;
    }

     /* the signature */
    if (mz_getLong(filestream, &uL) != UNZ_OK) {
        return 0;
    }

    if (uL != 0x06064b50)
        return 0;

    return relativeOffset;
}

extern unzFile unzOpen(const char *path)
{
    unz_s us;
    unz_s *s;
    ZPOS64_T central_pos;
    uLong   tempUnsignedLong;
    ushort  tempUnsignedShort;

    uLong number_disk;          /* number of the current dist, used for spaning ZIP, unsupported, always 0 */
    uLong number_disk_with_CD;  /* number the the disk with central dir, used for spaning ZIP, unsupported, always 0 */
    ZPOS64_T number_entry_CD;   /* total number of entries in the central dir (same than number_entry on nospan) */

    int err = UNZ_OK;

    const char *mode = mz_fopen_mode_to_str(mz_fopen_mode_read | mz_fopen_mode_existing);
    us.filestream = mode ? fopen(path, mode) : NULL;
    if (us.filestream == NULL) {
        return NULL;
    }

    central_pos = unz64local_SearchCentralDir64(us.filestream);
    if (central_pos) {
        ZPOS64_T uL64;

        us.isZip64 = 1;

        if (fseeko(us.filestream, (off_t)central_pos, SEEK_SET) != 0) {
            err = UNZ_ERRNO;
        }

        /* the signature, already checked */
        if (mz_getLong(us.filestream, &tempUnsignedLong) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* size of zip64 end of central directory record */
        if (mz_getLongLong(us.filestream, &uL64) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* version made by */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* version needed to extract */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* number of this disk */
        if (mz_getLong(us.filestream, &number_disk) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* number of the disk with the start of the central directory */
        if (mz_getLong(us.filestream, &number_disk_with_CD) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* total number of entries in the central directory on this disk */
        if (mz_getLongLong(us.filestream, &us.gi.number_entry) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* total number of entries in the central directory */
        if (mz_getLongLong(us.filestream, &number_entry_CD) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        if ((number_entry_CD != us.gi.number_entry) ||
            (number_disk_with_CD != 0) ||
            (number_disk != 0)) {
            err = UNZ_BADZIPFILE;
        }

        /* size of the central directory */
        if (mz_getLongLong(us.filestream, &us.size_central_dir) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* offset of start of central directory with respect to the
          starting disk number */
        if (mz_getLongLong(us.filestream, &us.offset_central_dir) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        us.gi.size_comment = 0;
    }
    else
    {
        central_pos = unz64local_SearchCentralDir(us.filestream);
        if (central_pos == 0) {
            err = UNZ_ERRNO;
        }

        us.isZip64 = 0;

        if (fseeko(us.filestream, (off_t)central_pos, SEEK_SET) != 0) {
            err = UNZ_ERRNO;
        }

        /* the signature, already checked */
        if (mz_getLong(us.filestream, &tempUnsignedLong) != UNZ_OK) {
            err = UNZ_ERRNO;
        }

        /* number of this disk */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        number_disk = tempUnsignedShort;

        /* number of the disk with the start of the central directory */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        number_disk_with_CD = tempUnsignedShort;

        /* total number of entries in the central dir on this disk */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        us.gi.number_entry = tempUnsignedShort;

        /* total number of entries in the central dir */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        number_entry_CD = tempUnsignedShort;

        if ((number_entry_CD!=us.gi.number_entry) ||
            (number_disk_with_CD!=0) ||
            (number_disk!=0)) {
            err = UNZ_BADZIPFILE;
        }

        /* size of the central directory */
        if (mz_getLong(us.filestream, &tempUnsignedLong) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        us.size_central_dir = tempUnsignedLong;

        /* offset of start of central directory with respect to the starting disk number */
        if (mz_getLong(us.filestream, &tempUnsignedLong) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        us.offset_central_dir = tempUnsignedLong;

        /* zipfile comment length */
        if (mz_getShort(us.filestream, &tempUnsignedShort) != UNZ_OK) {
            err = UNZ_ERRNO;
        }
        us.gi.size_comment = tempUnsignedShort;
    }

    if ((central_pos < (us.offset_central_dir + us.size_central_dir)) && (err == UNZ_OK)) {
        err = UNZ_BADZIPFILE;
    }

    if (err != UNZ_OK) {
        fclose(us.filestream);
        return NULL;
    }

    us.byte_before_the_zipfile = central_pos - (us.offset_central_dir + us.size_central_dir);
    us.central_pos = central_pos;
    us.pfile_in_zip_read = NULL;
    us.encrypted = 0;

    s = (unz_s*)ALLOC(sizeof(unz_s));
    if(s != NULL) {
        *s = us;
        unzGoToFirstFile((unzFile)s);
    }

    return (unzFile)s;
}

/*
  Close a ZipFile opened with unzipOpen.
  If there is files inside the .Zip opened with unzipOpenCurrentFile (see later),
    these files MUST be closed with unzipCloseCurrentFile before call unzipClose.
  return UNZ_OK if there is no problem. */
extern int unzClose(unzFile file)
{
    unz_s* s;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;

    if (s->pfile_in_zip_read != NULL) {
        unzCloseCurrentFile(file);
    }

    fclose(s->filestream);
    TRYFREE(s);

    return UNZ_OK;
}


/*
  Write info about the ZipFile in the *pglobal_info structure.
  No preparation of the structure is needed
  return UNZ_OK if there is no problem. */
extern int unzGetGlobalInfo(unzFile file, unz_global_info* pglobal_info)
{
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }

    unz_s* s = (unz_s*)file;
    *pglobal_info = s->gi;

    return UNZ_OK;
}

/*
   Translate date/time from Dos format to tm_unz (readable more easilty)
*/
static void unz64local_DosDateToTmuDate(ZPOS64_T ulDosDate, tm_unz* ptm)
{
    ZPOS64_T uDate;
    uDate = (ZPOS64_T)(ulDosDate >> 16);
    ptm->tm_mday = (uInt)(uDate & 0x1f);
    ptm->tm_mon =  (uInt)(((uDate & 0x1E0) / 0x20) - 1);
    ptm->tm_year = (uInt)(((uDate & 0x0FE00) / 0x0200) + 1980);

    ptm->tm_hour = (uInt)((ulDosDate & 0xF800) / 0x800);
    ptm->tm_min =  (uInt)((ulDosDate & 0x7E0) / 0x20);
    ptm->tm_sec =  (uInt)(2 * (ulDosDate & 0x1f));
}

/*
  Get Info about the current file in the zipfile, with internal only info
*/
static int unz64local_GetCurrentFileInfoInternal OF((unzFile file,
                                                    unz_file_info* pfile_info,
                                                    unz_file_info_internal* pfile_info_internal,
                                                    char *szFileName,
                                                    uLong fileNameBufferSize,
                                                    void *extraField,
                                                    uLong extraFieldBufferSize,
                                                    char *szComment,
                                                    uLong commentBufferSize));

static int unz64local_GetCurrentFileInfoInternal(unzFile file,
                                                unz_file_info* pfile_info,
                                                unz_file_info_internal* pfile_info_internal,
                                                char *szFileName,
                                                uLong fileNameBufferSize,
                                                void *extraField,
                                                uLong extraFieldBufferSize,
                                                char *szComment,
                                                uLong commentBufferSize)
{
    unz_s* s;
    unz_file_info file_info;
    unz_file_info_internal file_info_internal;
    int err = UNZ_OK;
    uLong uMagic;
    long lSeek = 0;
    uLong tempUnsignedLong;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }

    s = (unz_s*)file;
    if (fseeko(s->filestream, (off_t)(s->pos_in_central_dir + s->byte_before_the_zipfile), SEEK_SET) != 0) {
        err = UNZ_ERRNO;
    }

    /* we check the magic */
    if (err == UNZ_OK) {
        if (mz_getLong(s->filestream, &uMagic) != UNZ_OK) {
            err = UNZ_ERRNO;
        } else if (uMagic != 0x02014b50) {
            err = UNZ_BADZIPFILE;
        }
    }

    if (mz_getShort(s->filestream, &file_info.version) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.version_needed) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.flag) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.compression_method) != UNZ_OK)
        err = UNZ_ERRNO;

    if (mz_getLong(s->filestream, &file_info.dosDate) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    unz64local_DosDateToTmuDate(file_info.dosDate, &file_info.tmu_date);

    if (mz_getLong(s->filestream, &file_info.crc) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    file_info.compressed_size = tempUnsignedLong;

    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    file_info.uncompressed_size = tempUnsignedLong;

    if (mz_getShort(s->filestream, &file_info.size_filename) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.size_file_extra) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.size_file_comment) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.disk_num_start) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &file_info.internal_fa) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getLong(s->filestream, &file_info.external_fa) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    // relative offset of local header
    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    file_info_internal.offset_curfile = tempUnsignedLong;

    lSeek += file_info.size_filename;
    if ((err == UNZ_OK) && (szFileName != NULL)) {
        uLong uSizeRead;
        if (file_info.size_filename < fileNameBufferSize) {
            *(szFileName + file_info.size_filename) = '\0';
            uSizeRead = file_info.size_filename;
        } else {
            uSizeRead = fileNameBufferSize;
        }

        if ((file_info.size_filename > 0) && (fileNameBufferSize > 0)) {
            if (fread(szFileName, 1, uSizeRead, s->filestream) != uSizeRead) {
                err = UNZ_ERRNO;
            }
        }
        lSeek -= uSizeRead;
    }

    // Read extrafield
    if ((err == UNZ_OK) && (extraField != NULL)) {
        ZPOS64_T uSizeRead;
        if (file_info.size_file_extra < extraFieldBufferSize) {
            uSizeRead = file_info.size_file_extra;
        } else {
            uSizeRead = extraFieldBufferSize;
        }

        if (lSeek != 0) {
            if (fseeko(s->filestream, (off_t)lSeek, SEEK_CUR) == 0) {
                lSeek = 0;
            } else {
                err = UNZ_ERRNO;
            }
        }

        if ((file_info.size_file_extra > 0) && (extraFieldBufferSize > 0)) {
            if (fread(extraField, 1, (size_t)uSizeRead, s->filestream) != (size_t)uSizeRead) {
                err = UNZ_ERRNO;
            }
        }

        lSeek += file_info.size_file_extra - (uLong)uSizeRead;

    } else {
        lSeek += file_info.size_file_extra;
    }


    if ((err == UNZ_OK) && (file_info.size_file_extra != 0)) {
        uLong acc = 0;

        // since lSeek now points to after the extra field we need to move back
        lSeek -= file_info.size_file_extra;

        if (lSeek != 0) {
            if (fseeko(s->filestream, (off_t)lSeek, SEEK_CUR) == 0) {
                lSeek = 0;
            } else {
                err = UNZ_ERRNO;
            }
        }

        while(acc < file_info.size_file_extra) {
            ushort headerId;
            ushort dataSize;

            if (mz_getShort(s->filestream, &headerId) != UNZ_OK) {
                err = UNZ_ERRNO;
            }

            if (mz_getShort(s->filestream, &dataSize) != UNZ_OK) {
                err = UNZ_ERRNO;
            }

            /* ZIP64 extra fields */
            if (headerId == 0x0001) {
                if (file_info.uncompressed_size == (ZPOS64_T)(unsigned long)-1) {
                    if (mz_getLongLong(s->filestream, &file_info.uncompressed_size) != UNZ_OK) {
                        err = UNZ_ERRNO;
                    }
                }

                if (file_info.compressed_size == (ZPOS64_T)(unsigned long)-1) {
                    if (mz_getLongLong(s->filestream, &file_info.compressed_size) != UNZ_OK) {
                        err = UNZ_ERRNO;
                    }
                }

                if(file_info_internal.offset_curfile == (ZPOS64_T)(unsigned long)-1) {
                    /* Relative Header offset */
                    if (mz_getLongLong(s->filestream, &file_info_internal.offset_curfile) != UNZ_OK) {
                        err = UNZ_ERRNO;
                    }
                }

                if(file_info.disk_num_start == (unsigned short)-1) {
                    /* Disk Start Number */
                    uLong tmpUL;
                    if (mz_getLong(s->filestream, &tmpUL) != UNZ_OK) {
                        err = UNZ_ERRNO;
                    }
                }
            } else {
                if (fseeko(s->filestream, (off_t)dataSize, SEEK_CUR) != 0) {
                    err = UNZ_ERRNO;
                }
            }

            acc += 2 + 2 + dataSize;
        }
    }

    if ((err == UNZ_OK) && (szComment != NULL)) {
        uLong uSizeRead;
        if (file_info.size_file_comment < commentBufferSize) {
            *(szComment + file_info.size_file_comment) = '\0';
            uSizeRead = file_info.size_file_comment;
        } else {
            uSizeRead = commentBufferSize;
        }

        if (lSeek != 0) {
            if (fseeko(s->filestream, (off_t)lSeek, SEEK_CUR) == 0) {
                lSeek = 0;
            } else {
                err = UNZ_ERRNO;
            }
        }

        if ((file_info.size_file_comment > 0) && (commentBufferSize > 0)) {
            if (fread(szComment, 1, uSizeRead, s->filestream) != uSizeRead) {
                err = UNZ_ERRNO;
            }
        }
        lSeek += file_info.size_file_comment - uSizeRead;

    } else {
        lSeek += file_info.size_file_comment;
    }


    if ((err == UNZ_OK) && (pfile_info != NULL)) {
        *pfile_info = file_info;
    }

    if ((err == UNZ_OK) && (pfile_info_internal != NULL)) {
        *pfile_info_internal = file_info_internal;
    }
    
    return err;
}



/*
  Write info about the ZipFile in the *pglobal_info structure.
  No preparation of the structure is needed
  return UNZ_OK if there is no problem.
*/
extern int unzGetCurrentFileInfo(unzFile file,
                                 unz_file_info * pfile_info,
                                 char * szFileName,
                                 uLong fileNameBufferSize,
                                 void *extraField,
                                 uLong extraFieldBufferSize,
                                 char* szComment,
                                 uLong commentBufferSize)
{
    return unz64local_GetCurrentFileInfoInternal(file,pfile_info,
                                                 NULL,
                                                 szFileName,
                                                 fileNameBufferSize,
                                                 extraField,
                                                 extraFieldBufferSize,
                                                 szComment,
                                                 commentBufferSize);
}

/*
  Set the current file of the zipfile to the first file.
  return UNZ_OK if there is no problem
*/
extern int unzGoToFirstFile(unzFile file)
{
    int err = UNZ_OK;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    unz_s* s = (unz_s*)file;
    s->pos_in_central_dir = s->offset_central_dir;
    s->num_file = 0;
    err = unz64local_GetCurrentFileInfoInternal(file,&s->cur_file_info,
                                                &s->cur_file_info_internal,
                                                NULL,
                                                0,
                                                NULL,
                                                0,
                                                NULL,
                                                0);
    s->current_file_ok = (err == UNZ_OK);
    return err;
}

/*
  Set the current file of the zipfile to the next file.
  return UNZ_OK if there is no problem
  return UNZ_END_OF_LIST_OF_FILE if the actual file was the latest.
*/
extern int unzGoToNextFile(unzFile file)
{
    unz_s* s;
    int err;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    if (!s->current_file_ok) {
        return UNZ_END_OF_LIST_OF_FILE;
    }
    if (s->gi.number_entry != 0xffff) {    /* 2^16 files overflow hack */
        if (s->num_file+1==s->gi.number_entry) {
            return UNZ_END_OF_LIST_OF_FILE;
        }
    }

    s->pos_in_central_dir +=    SIZECENTRALDIRITEM +
                                s->cur_file_info.size_filename +
                                s->cur_file_info.size_file_extra +
                                s->cur_file_info.size_file_comment;
    s->num_file++;
    err = unz64local_GetCurrentFileInfoInternal(file,
                                                &s->cur_file_info,
                                                &s->cur_file_info_internal,
                                                NULL,
                                                0,
                                                NULL,
                                                0,
                                                NULL,
                                                0);
    s->current_file_ok = (err == UNZ_OK);
    return err;
}


/*
  Try locate the file szFileName in the zipfile.
  For the iCaseSensitivity signification, see unzipStringFileNameCompare

  return value :
  UNZ_OK if the file is found. It becomes the current file.
  UNZ_END_OF_LIST_OF_FILE if the file is not found
*/
extern int unzLocateFile(unzFile file, const char *szFileName, int iCaseSensitivity)
{
    unz_s* s;
    int err;

    /* We remember the 'current' position in the file so that we can jump
     * back there if we fail.
     */
    unz_file_info cur_file_infoSaved;
    unz_file_info_internal cur_file_info_internalSaved;
    ZPOS64_T num_fileSaved;
    ZPOS64_T pos_in_central_dirSaved;


    if (file == NULL) {
        return UNZ_PARAMERROR;
    }

    if (strlen(szFileName) >= UNZ_MAXFILENAMEINZIP) {
        return UNZ_PARAMERROR;
    }

    s = (unz_s*)file;
    if (!s->current_file_ok) {
        return UNZ_END_OF_LIST_OF_FILE;
    }

    /* Save the current state */
    num_fileSaved = s->num_file;
    pos_in_central_dirSaved = s->pos_in_central_dir;
    cur_file_infoSaved = s->cur_file_info;
    cur_file_info_internalSaved = s->cur_file_info_internal;

    err = unzGoToFirstFile(file);

    while (err == UNZ_OK) {
        char szCurrentFileName[UNZ_MAXFILENAMEINZIP + 1];
        err = unzGetCurrentFileInfo(file,
                                    NULL,
                                    szCurrentFileName,
                                    sizeof(szCurrentFileName) - 1,
                                    NULL,
                                    0,
                                    NULL,
                                    0);
        if (err == UNZ_OK) {
            if (0 == unzStringFileNameCompare(szCurrentFileName,
                                              szFileName,
                                              iCaseSensitivity)) {
                return UNZ_OK;
            }
            err = unzGoToNextFile(file);
        }
    }

    /* We failed, so restore the state of the 'current file' to where we
     * were.
     */
    s->num_file = num_fileSaved ;
    s->pos_in_central_dir = pos_in_central_dirSaved ;
    s->cur_file_info = cur_file_infoSaved;
    s->cur_file_info_internal = cur_file_info_internalSaved;

    return err;
}


/*
///////////////////////////////////////////
// Contributed by Ryan Haksi (mailto://cryogen@infoserve.net)
// I need random access
//
// Further optimization could be realized by adding an ability
// to cache the directory in memory. The goal being a single
// comprehensive file read to put the file I need in a memory.
*/

/*
typedef struct unz_file_pos_s
{
    ZPOS64_T pos_in_zip_directory;   // offset in file
    ZPOS64_T num_of_file;            // # of file
} unz_file_pos;
*/

extern int unzGetFilePos(unzFile file, unz_file_pos* file_pos)
{
    unz_s* s;

    if (file == NULL || file_pos == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    if (!s->current_file_ok) {
        return UNZ_END_OF_LIST_OF_FILE;
    }

    file_pos->pos_in_zip_directory  = s->pos_in_central_dir;
    file_pos->num_of_file           = s->num_file;

    return UNZ_OK;
}

extern int unzGoToFilePos(unzFile file, const unz_file_pos* file_pos)
{
    unz_s* s;
    int err;

    if (file == NULL || file_pos == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;

    /* jump to the right spot */
    s->pos_in_central_dir = file_pos->pos_in_zip_directory;
    s->num_file           = file_pos->num_of_file;

    /* set the current file */
    err = unz64local_GetCurrentFileInfoInternal(file,&s->cur_file_info,
                                                &s->cur_file_info_internal,
                                                NULL,
                                                0,
                                                NULL,
                                                0,
                                                NULL,
                                                0);
    /* return results */
    s->current_file_ok = (err == UNZ_OK);

    return err;
}

/*
// Unzip Helper Functions - should be here?
///////////////////////////////////////////
*/

/*
  Read the local header of the current zipfile
  Check the coherency of the local header and info in the end of central
        directory about this file
  store in *piSizeVar the size of extra info in local header
        (filename and size of extra field data)
*/
static int unz64local_CheckCurrentFileCoherencyHeader(unz_s* s,
                                                     uInt* piSizeVar,
                                                     ZPOS64_T* poffset_local_extrafield,
                                                     uInt* psize_local_extrafield)
{
    uLong uMagic;
    ushort uFlags;
    uLong tempUnsignedLong;
    ushort tempUnsignedShort;
    ushort size_filename;
    ushort size_extra_field;
    int err = UNZ_OK;

    *piSizeVar = 0;
    *poffset_local_extrafield = 0;
    *psize_local_extrafield = 0;

    if (0 != fseeko(s->filestream,
                    (off_t)(s->cur_file_info_internal.offset_curfile + s->byte_before_the_zipfile),
                    SEEK_SET)) {
        return UNZ_ERRNO;
    }


    if (err == UNZ_OK) {
        if (mz_getLong(s->filestream, &uMagic) != UNZ_OK) {
            err = UNZ_ERRNO;
        } else if (uMagic != 0x04034b50) {
            err = UNZ_BADZIPFILE;
        }
    }

    if (mz_getShort(s->filestream, &tempUnsignedShort) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
/*
    else if ((err == UNZ_OK) && (tempUnsignedShort != s->cur_file_info.wVersion)) {
        err = UNZ_BADZIPFILE;
    }
*/
    if (mz_getShort(s->filestream, &uFlags) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (mz_getShort(s->filestream, &tempUnsignedShort) != UNZ_OK) {
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (tempUnsignedShort != s->cur_file_info.compression_method)) {
        err = UNZ_BADZIPFILE;
    }

    if ((err == UNZ_OK) &&
        (s->cur_file_info.compression_method != 0) &&
/* #ifdef HAVE_BZIP2 */
        (s->cur_file_info.compression_method != Z_BZIP2ED) &&
/* #endif */
        (s->cur_file_info.compression_method != Z_DEFLATED)) {
        err = UNZ_BADZIPFILE;
    }

    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        /* date/time */
        err = UNZ_ERRNO;
    }

    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        /* crc */
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (tempUnsignedLong != s->cur_file_info.crc) && ((uFlags & 8) == 0)) {
        err = UNZ_BADZIPFILE;
    }

    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        /* size compr */
        err = UNZ_ERRNO;
    } else if (tempUnsignedLong != 0xFFFFFFFF && (err == UNZ_OK) && (tempUnsignedLong != s->cur_file_info.compressed_size) && ((uFlags & 8) == 0)) {
        err = UNZ_BADZIPFILE;
    }

    if (mz_getLong(s->filestream, &tempUnsignedLong) != UNZ_OK) {
        /* size uncompr */
        err = UNZ_ERRNO;
    } else if (tempUnsignedLong != 0xFFFFFFFF && (err == UNZ_OK) && (tempUnsignedLong != s->cur_file_info.uncompressed_size) && ((uFlags & 8) == 0)) {
        err = UNZ_BADZIPFILE;
    }

    if (mz_getShort(s->filestream, &size_filename) != UNZ_OK) {
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (size_filename != s->cur_file_info.size_filename)) {
        err = UNZ_BADZIPFILE;
    }

    *piSizeVar += (uInt)size_filename;

    if (mz_getShort(s->filestream, &size_extra_field) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    *poffset_local_extrafield= s->cur_file_info_internal.offset_curfile + SIZEZIPLOCALHEADER + size_filename;
    *psize_local_extrafield = (uInt)size_extra_field;

    *piSizeVar += (uInt)size_extra_field;

    return err;
}

/*
  Open for reading data the current file in the zipfile.
  If there is no error and the file is opened, the return value is UNZ_OK.
*/
extern int unzOpenCurrentFile3(unzFile file,
                               int* method,
                               int* level,
                               int raw,
                               const char* password)
{
    int err = UNZ_OK;
    uInt iSizeVar;
    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    ZPOS64_T offset_local_extrafield;  /* offset of the local extra field */
    uInt  size_local_extrafield;    /* size of the local extra field */
#ifndef NOUNCRYPT
    char source[12];
#else
    if (password != NULL) {
        return UNZ_PARAMERROR;
    }
#endif

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    if (!s->current_file_ok) {
        return UNZ_PARAMERROR;
    }

    if (s->pfile_in_zip_read != NULL) {
        unzCloseCurrentFile(file);
    }

    if (unz64local_CheckCurrentFileCoherencyHeader(s, &iSizeVar, &offset_local_extrafield, &size_local_extrafield) != UNZ_OK) {
        return UNZ_BADZIPFILE;
    }

    pfile_in_zip_read_info = (file_in_zip_read_info_s*)ALLOC(sizeof(file_in_zip_read_info_s));
    if (pfile_in_zip_read_info == NULL) {
        return UNZ_INTERNALERROR;
    }

    pfile_in_zip_read_info->read_buffer = (char*)ALLOC(UNZ_BUFSIZE);
    pfile_in_zip_read_info->offset_local_extrafield = offset_local_extrafield;
    pfile_in_zip_read_info->size_local_extrafield = size_local_extrafield;
    pfile_in_zip_read_info->pos_local_extrafield = 0;
    pfile_in_zip_read_info->raw = raw;

    if (pfile_in_zip_read_info->read_buffer == NULL) {
        TRYFREE(pfile_in_zip_read_info);
        return UNZ_INTERNALERROR;
    }

    pfile_in_zip_read_info->stream_initialised = 0;

    if (method != NULL) {
        *method = (int)s->cur_file_info.compression_method;
    }

    if (level != NULL){
        *level = 6;
        switch (s->cur_file_info.flag & 0x06)
        {
            case 6:
                *level = 1;
                break;
            case 4:
                *level = 2;
                break;
            case 2:
                *level = 9;
                break;
        }
    }

    if ((s->cur_file_info.compression_method != 0) &&
/* #ifdef HAVE_BZIP2 */
        (s->cur_file_info.compression_method != Z_BZIP2ED) &&
/* #endif */
        (s->cur_file_info.compression_method != Z_DEFLATED)) {
        err = UNZ_BADZIPFILE;
    }

    pfile_in_zip_read_info->crc32_wait = s->cur_file_info.crc;
    pfile_in_zip_read_info->crc32 = 0;
    pfile_in_zip_read_info->total_out_64 = 0;
    pfile_in_zip_read_info->compression_method = s->cur_file_info.compression_method;
    pfile_in_zip_read_info->filestream = s->filestream;
    pfile_in_zip_read_info->byte_before_the_zipfile = s->byte_before_the_zipfile;

    pfile_in_zip_read_info->stream.total_out = 0;

    if ((s->cur_file_info.compression_method == Z_BZIP2ED) && (!raw)) {
#ifdef HAVE_BZIP2
      pfile_in_zip_read_info->bstream.bzalloc = (void *(*) (void *, int, int))0;
      pfile_in_zip_read_info->bstream.bzfree = (free_func)0;
      pfile_in_zip_read_info->bstream.opaque = (voidpf)0;
      pfile_in_zip_read_info->bstream.state = (voidpf)0;

      pfile_in_zip_read_info->stream.zalloc = (alloc_func)0;
      pfile_in_zip_read_info->stream.zfree = (free_func)0;
      pfile_in_zip_read_info->stream.opaque = (voidpf)0;
      pfile_in_zip_read_info->stream.next_in = (voidpf)0;
      pfile_in_zip_read_info->stream.avail_in = 0;

      err=BZ2_bzDecompressInit(&pfile_in_zip_read_info->bstream, 0, 0);
      if (err == Z_OK) {
        pfile_in_zip_read_info->stream_initialised = Z_BZIP2ED;
      } else {
        TRYFREE(pfile_in_zip_read_info);
        return err;
      }
#else
      pfile_in_zip_read_info->raw = 1;
#endif
    } else if ((s->cur_file_info.compression_method == Z_DEFLATED) && (!raw)) {
        pfile_in_zip_read_info->stream.zalloc = (alloc_func)0;
        pfile_in_zip_read_info->stream.zfree = (free_func)0;
        pfile_in_zip_read_info->stream.opaque = (voidpf)0;
        pfile_in_zip_read_info->stream.next_in = 0;
        pfile_in_zip_read_info->stream.avail_in = 0;

        err = inflateInit2(&pfile_in_zip_read_info->stream, -MAX_WBITS);
        if (err == Z_OK) {
            pfile_in_zip_read_info->stream_initialised=Z_DEFLATED;
        } else {
            TRYFREE(pfile_in_zip_read_info);
            return err;
        }
        /* windowBits is passed < 0 to tell that there is no zlib header.
         * Note that in this case inflate *requires* an extra "dummy" byte
         * after the compressed stream in order to complete decompression and
         * return Z_STREAM_END.
         * In unzip, i don't wait absolutely Z_STREAM_END because I known the
         * size of both compressed and uncompressed data
         */
    }

    pfile_in_zip_read_info->rest_read_compressed = s->cur_file_info.compressed_size;
    pfile_in_zip_read_info->rest_read_uncompressed = s->cur_file_info.uncompressed_size;


    pfile_in_zip_read_info->pos_in_zipfile =    s->cur_file_info_internal.offset_curfile +
                                                SIZEZIPLOCALHEADER +
                                                iSizeVar;

    pfile_in_zip_read_info->stream.avail_in = (uInt)0;

    s->pfile_in_zip_read = pfile_in_zip_read_info;
    s->encrypted = 0;

#ifndef NOUNCRYPT
    if (password != NULL) {
        s->pcrc_32_tab = get_crc_table();
        init_keys(password, s->keys, s->pcrc_32_tab);
        if (0 != fseeko(s->filestream,
                        (off_t)(s->pfile_in_zip_read->pos_in_zipfile + s->pfile_in_zip_read->byte_before_the_zipfile),
                        SEEK_SET)) {
            return UNZ_INTERNALERROR;
        }

        if(fread(source, 1, 12, s->filestream) < 12) {
            return UNZ_INTERNALERROR;
        }

        for (int i = 0; i < 12; i++) {
            zdecode(s->keys, s->pcrc_32_tab, source[i]);
        }

        s->pfile_in_zip_read->pos_in_zipfile += 12;
        s->encrypted = 1;
    }
#endif // NOUNCRYPT

    return UNZ_OK;
}

extern int unzOpenCurrentFile(unzFile file)
{
    return unzOpenCurrentFile3(file, NULL, NULL, 0, NULL);
}

extern int unzOpenCurrentFilePassword(unzFile file, const char*  password)
{
    return unzOpenCurrentFile3(file, NULL, NULL, 0, password);
}

extern int unzOpenCurrentFile2(unzFile file, int* method, int* level, int raw)
{
    return unzOpenCurrentFile3(file, method, level, raw, NULL);
}

/** Addition for GDAL : START */

extern ZPOS64_T unzGetCurrentFileZStreamPos(unzFile file)
{
    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    s = (unz_s*)file;
    if (file == NULL) {
        return 0; //UNZ_PARAMERROR;
    }
    pfile_in_zip_read_info=s->pfile_in_zip_read;
    if (pfile_in_zip_read_info == NULL) {
        return 0; //UNZ_PARAMERROR;
    }
    return pfile_in_zip_read_info->pos_in_zipfile + pfile_in_zip_read_info->byte_before_the_zipfile;
}

/** Addition for GDAL : END */

/*
  Read bytes from the current file.
  buf contain buffer where data must be copied
  len the size of buf.

  return the number of byte copied if somes bytes are copied
  return 0 if the end of file was reached
  return <0 with error code if there is an error
    (UNZ_ERRNO for IO error, or zLib error for uncompress error)
*/
extern int unzReadCurrentFile(unzFile file, voidp buf, unsigned int len)
{
    int err = UNZ_OK;
    uInt iRead = 0;
    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return UNZ_PARAMERROR;
    }


    if (pfile_in_zip_read_info->read_buffer == NULL) {
        return UNZ_END_OF_LIST_OF_FILE;
    }
    if (len == 0) {
        return 0;
    }

    pfile_in_zip_read_info->stream.next_out = (Bytef*)buf;

    pfile_in_zip_read_info->stream.avail_out = (uInt)len;

    if ((len > pfile_in_zip_read_info->rest_read_uncompressed) && (!(pfile_in_zip_read_info->raw))) {
        pfile_in_zip_read_info->stream.avail_out = (uInt)pfile_in_zip_read_info->rest_read_uncompressed;
    }

    if ((len > pfile_in_zip_read_info->rest_read_compressed + pfile_in_zip_read_info->stream.avail_in) &&
        (pfile_in_zip_read_info->raw)) {
        pfile_in_zip_read_info->stream.avail_out = (uInt)pfile_in_zip_read_info->rest_read_compressed + pfile_in_zip_read_info->stream.avail_in;
    }

    while (pfile_in_zip_read_info->stream.avail_out > 0) {
        if ((pfile_in_zip_read_info->stream.avail_in == 0) && (pfile_in_zip_read_info->rest_read_compressed > 0)) {
            uInt uReadThis = UNZ_BUFSIZE;
            if (pfile_in_zip_read_info->rest_read_compressed < uReadThis) {
                uReadThis = (uInt)pfile_in_zip_read_info->rest_read_compressed;
            }
            if (uReadThis == 0) {
                return UNZ_EOF;
            }
            if (0 != fseeko(pfile_in_zip_read_info->filestream,
                            (off_t)(pfile_in_zip_read_info->pos_in_zipfile + pfile_in_zip_read_info->byte_before_the_zipfile),
                            SEEK_SET)) {
                return UNZ_ERRNO;
            }
            if (uReadThis != fread(pfile_in_zip_read_info->read_buffer,
                                   1,
                                   uReadThis,
                                   pfile_in_zip_read_info->filestream)) {
                return UNZ_ERRNO;
            }


#ifndef NOUNCRYPT
            if (s->encrypted) {
                for (uInt i = 0; i < uReadThis; i++) {
                    pfile_in_zip_read_info->read_buffer[i] = (char)zdecode(s->keys,
                                                                           s->pcrc_32_tab,
                                                                           pfile_in_zip_read_info->read_buffer[i]);
                }
            }
#endif


            pfile_in_zip_read_info->pos_in_zipfile += uReadThis;

            pfile_in_zip_read_info->rest_read_compressed -= uReadThis;

            pfile_in_zip_read_info->stream.next_in = (Bytef*)pfile_in_zip_read_info->read_buffer;
            pfile_in_zip_read_info->stream.avail_in = (uInt)uReadThis;
        }

        if ((pfile_in_zip_read_info->compression_method == 0) || (pfile_in_zip_read_info->raw)) {
            uInt uDoCopy;

            if ((pfile_in_zip_read_info->stream.avail_in == 0) &&
                (pfile_in_zip_read_info->rest_read_compressed == 0)) {
                return (iRead == 0) ? UNZ_EOF : (int)iRead;
            }

            if (pfile_in_zip_read_info->stream.avail_out < pfile_in_zip_read_info->stream.avail_in) {
                uDoCopy = pfile_in_zip_read_info->stream.avail_out;
            } else {
                uDoCopy = pfile_in_zip_read_info->stream.avail_in;
            }

            for (uInt i = 0; i < uDoCopy; i++) {
                *(pfile_in_zip_read_info->stream.next_out + i) = *(pfile_in_zip_read_info->stream.next_in + i);
            }

            pfile_in_zip_read_info->total_out_64 = pfile_in_zip_read_info->total_out_64 + uDoCopy;

            pfile_in_zip_read_info->crc32 = crc32(pfile_in_zip_read_info->crc32,
                                                  pfile_in_zip_read_info->stream.next_out,
                                                  uDoCopy);
            pfile_in_zip_read_info->rest_read_uncompressed -= uDoCopy;
            pfile_in_zip_read_info->stream.avail_in -= uDoCopy;
            pfile_in_zip_read_info->stream.avail_out -= uDoCopy;
            pfile_in_zip_read_info->stream.next_out += uDoCopy;
            pfile_in_zip_read_info->stream.next_in += uDoCopy;
            pfile_in_zip_read_info->stream.total_out += uDoCopy;
            iRead += uDoCopy;

        } else if (pfile_in_zip_read_info->compression_method == Z_BZIP2ED) {

#ifdef HAVE_BZIP2
            uLong uTotalOutBefore, uTotalOutAfter;
            const Bytef *bufBefore;
            uLong uOutThis;

            pfile_in_zip_read_info->bstream.next_in        = (char*)pfile_in_zip_read_info->stream.next_in;
            pfile_in_zip_read_info->bstream.avail_in       = pfile_in_zip_read_info->stream.avail_in;
            pfile_in_zip_read_info->bstream.total_in_lo32  = pfile_in_zip_read_info->stream.total_in;
            pfile_in_zip_read_info->bstream.total_in_hi32  = 0;
            pfile_in_zip_read_info->bstream.next_out       = (char*)pfile_in_zip_read_info->stream.next_out;
            pfile_in_zip_read_info->bstream.avail_out      = pfile_in_zip_read_info->stream.avail_out;
            pfile_in_zip_read_info->bstream.total_out_lo32 = pfile_in_zip_read_info->stream.total_out;
            pfile_in_zip_read_info->bstream.total_out_hi32 = 0;

            uTotalOutBefore = pfile_in_zip_read_info->bstream.total_out_lo32;
            bufBefore = (const Bytef *)pfile_in_zip_read_info->bstream.next_out;

            err = BZ2_bzDecompress(&pfile_in_zip_read_info->bstream);

            uTotalOutAfter = pfile_in_zip_read_info->bstream.total_out_lo32;
            uOutThis = uTotalOutAfter-uTotalOutBefore;

            pfile_in_zip_read_info->total_out_64 = pfile_in_zip_read_info->total_out_64 + uOutThis;

            pfile_in_zip_read_info->crc32 = crc32(pfile_in_zip_read_info->crc32,bufBefore, (uInt)(uOutThis));
            pfile_in_zip_read_info->rest_read_uncompressed -= uOutThis;
            iRead += (uInt)(uTotalOutAfter - uTotalOutBefore);

            pfile_in_zip_read_info->stream.next_in   = (Bytef*)pfile_in_zip_read_info->bstream.next_in;
            pfile_in_zip_read_info->stream.avail_in  = pfile_in_zip_read_info->bstream.avail_in;
            pfile_in_zip_read_info->stream.total_in  = pfile_in_zip_read_info->bstream.total_in_lo32;
            pfile_in_zip_read_info->stream.next_out  = (Bytef*)pfile_in_zip_read_info->bstream.next_out;
            pfile_in_zip_read_info->stream.avail_out = pfile_in_zip_read_info->bstream.avail_out;
            pfile_in_zip_read_info->stream.total_out = pfile_in_zip_read_info->bstream.total_out_lo32;

            if (err == BZ_STREAM_END) {
              return (iRead==0) ? UNZ_EOF : iRead;
            }
            if (err != BZ_OK) {
              break;
            }
#endif
        } // end Z_BZIP2ED
        else
        {
            ZPOS64_T uTotalOutBefore, uTotalOutAfter;
            const Bytef *bufBefore;
            ZPOS64_T uOutThis;
            int flush=Z_SYNC_FLUSH;

            uTotalOutBefore = pfile_in_zip_read_info->stream.total_out;
            bufBefore = pfile_in_zip_read_info->stream.next_out;

            /*
             if ((pfile_in_zip_read_info->rest_read_uncompressed == pfile_in_zip_read_info->stream.avail_out) && 
                 (pfile_in_zip_read_info->rest_read_compressed == 0)) {
                flush = Z_FINISH;
             }
            */
            err = inflate(&pfile_in_zip_read_info->stream, flush);

            if ((err >= 0) && (pfile_in_zip_read_info->stream.msg != NULL)) {
              err = Z_DATA_ERROR;
            }

            uTotalOutAfter = pfile_in_zip_read_info->stream.total_out;
            uOutThis = uTotalOutAfter-uTotalOutBefore;

            pfile_in_zip_read_info->total_out_64 = pfile_in_zip_read_info->total_out_64 + uOutThis;

            pfile_in_zip_read_info->crc32 = crc32(pfile_in_zip_read_info->crc32, bufBefore, (uInt)(uOutThis));

            pfile_in_zip_read_info->rest_read_uncompressed -= uOutThis;

            iRead += (uInt)(uTotalOutAfter - uTotalOutBefore);

            if (err == Z_STREAM_END) {
                return (iRead == 0) ? UNZ_EOF : (int)iRead;
            }
            if (err != Z_OK) {
                break;
            }
        }
    }

    if (err == Z_OK) {
        return (int)iRead;
    }

    return err;
}


/*
  Give the current position in uncompressed data
*/
extern ZPOS64_T unztell(unzFile file)
{
    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    if (file == NULL) {
        return (ZPOS64_T)UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return (ZPOS64_T)UNZ_PARAMERROR;
    }

    return pfile_in_zip_read_info->total_out_64;
}


/*
  return 1 if the end of file was reached, 0 elsewhere
*/
extern int unzeof(unzFile file)
{
    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return UNZ_PARAMERROR;
    }

    if (pfile_in_zip_read_info->rest_read_uncompressed == 0) {
        return 1;
    } else {
        return 0;
    }
}



/*
Read extra field from the current file (opened by unzOpenCurrentFile)
This is the local-header version of the extra field (sometimes, there is
more info in the local-header version than in the central-header)

  if buf==NULL, it return the size of the local extra field that can be read

  if buf!=NULL, len is the size of the buffer, the extra header is copied in
    buf.
  the return value is the number of bytes copied in buf, or (if <0)
    the error code
*/
extern int unzGetLocalExtrafield(unzFile file, voidp buf, unsigned len)
{
    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    uInt read_now;
    ZPOS64_T size_to_read;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return UNZ_PARAMERROR;
    }

    size_to_read = (pfile_in_zip_read_info->size_local_extrafield - pfile_in_zip_read_info->pos_local_extrafield);

    if (buf == NULL) {
        return (int)size_to_read;
    }

    if (len > size_to_read) {
        read_now = (uInt)size_to_read;
    } else {
        read_now = (uInt)len;
    }

    if (read_now == 0) {
        return 0;
    }

    if (0 != fseeko(pfile_in_zip_read_info->filestream,
                    (off_t)(pfile_in_zip_read_info->offset_local_extrafield + pfile_in_zip_read_info->pos_local_extrafield),
                    SEEK_SET)) {
        return UNZ_ERRNO;
    }

    if (read_now != fread(buf, 1, read_now, pfile_in_zip_read_info->filestream)) {
        return UNZ_ERRNO;
    }

    return (int)read_now;
}

/*
  Close the file in zip opened with unzipOpenCurrentFile
  Return UNZ_CRCERROR if all the file was read but the CRC is not good
*/
extern int unzCloseCurrentFile(unzFile file)
{
    int err = UNZ_OK;

    unz_s* s;
    file_in_zip_read_info_s* pfile_in_zip_read_info;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return UNZ_PARAMERROR;
    }


    if ((pfile_in_zip_read_info->rest_read_uncompressed == 0) && (!pfile_in_zip_read_info->raw)) {
        if (pfile_in_zip_read_info->crc32 != pfile_in_zip_read_info->crc32_wait) {
            err = UNZ_CRCERROR;
        }
    }

    TRYFREE(pfile_in_zip_read_info->read_buffer);
    pfile_in_zip_read_info->read_buffer = NULL;
    if (pfile_in_zip_read_info->stream_initialised == Z_DEFLATED) {
        inflateEnd(&pfile_in_zip_read_info->stream);
    }
#ifdef HAVE_BZIP2
    else if (pfile_in_zip_read_info->stream_initialised == Z_BZIP2ED) {
        BZ2_bzDecompressEnd(&pfile_in_zip_read_info->bstream);
    }
#endif


    pfile_in_zip_read_info->stream_initialised = 0;
    TRYFREE(pfile_in_zip_read_info);

    s->pfile_in_zip_read=NULL;

    return err;
}


/*
  Get the global comment string of the ZipFile, in the szComment buffer.
  uSizeBuf is the size of the szComment buffer.
  return the number of byte copied or an error code <0
*/
extern int unzGetGlobalComment(unzFile file, char * szComment, uLong uSizeBuf)
{
    unz_s* s;
    uLong uReadThis;
    if (file == NULL) {
        return (int)UNZ_PARAMERROR;
    }
    s = (unz_s*)file;

    uReadThis = uSizeBuf;
    if (uReadThis > s->gi.size_comment) {
        uReadThis = s->gi.size_comment;
    }

    if (fseeko(s->filestream, (off_t)(s->central_pos + 22), SEEK_SET) != 0) {
        return UNZ_ERRNO;
    }

    if (uReadThis > 0) {
        *szComment = '\0';
        if (fread(szComment, 1, uReadThis, s->filestream) != uReadThis) {
            return UNZ_ERRNO;
        }
    }

    if ((szComment != NULL) && (uSizeBuf > s->gi.size_comment)) {
        *(szComment+s->gi.size_comment) = '\0';
    }
    return (int)uReadThis;
}

/* Additions by RX '2004 */
extern ZPOS64_T unzGetOffset(unzFile file)
{
    unz_s* s;

    if (file == NULL) {
          return 0; //UNZ_PARAMERROR;
    }
    s = (unz_s*)file;
    if (!s->current_file_ok) {
      return 0;
    }
    if (s->gi.number_entry != 0 && s->gi.number_entry != 0xffff) {
        if (s->num_file == s->gi.number_entry) {
            return 0;
        }
    }
    return s->pos_in_central_dir;
}

extern int unzSetOffset(unzFile file, ZPOS64_T pos)
{
    unz_s* s;
    int err;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s*)file;

    s->pos_in_central_dir = pos;
    s->num_file = s->gi.number_entry; /* hack */
    err = unz64local_GetCurrentFileInfoInternal(file,
                                                &s->cur_file_info,
                                                &s->cur_file_info_internal,
                                                NULL,
                                                0,
                                                NULL,
                                                0,
                                                NULL,
                                                0);
    s->current_file_ok = (err == UNZ_OK);
    return err;
}
