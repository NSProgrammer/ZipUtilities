/* unzip.h -- IO for uncompress .zip files using zlib
   Version 1.1, February 14h, 2010
   part of the MiniZip project - ( http://www.winimage.com/zLibDll/minizip.html )

         Copyright (C) 1998-2010 Gilles Vollant (minizip) ( http://www.winimage.com/zLibDll/minizip.html )

         Modifications of Unzip for Zip64
         Copyright (C) 2007-2008 Even Rouault

         Modifications for Zip64 support on both zip and unzip
         Copyright (C) 2009-2010 Mathias Svensson ( http://result42.com )

         For more info read MiniZip_info.txt

         ---------------------------------------------------------------------------------

        Condition of use and distribution are the same than zlib :

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  ---------------------------------------------------------------------------------

        Changes

        See top of unzip.c

*/

#ifndef _unz64_H
#define _unz64_H

#ifdef __cplusplus
extern "C" {
#endif

#include "zlib.h"
#include "ioapi.h"

#ifdef HAVE_BZIP2
#include "bzlib.h"
#endif

#define Z_BZIP2ED (12)

#if defined(STRICTUNZIP) || defined(STRICTZIPUNZIP)
/* like the STRICT of WIN32, we define a pointer that cannot be converted
    from (void*) without cast */
typedef struct TagunzFile__ { int unused; } unzFile__;
typedef unzFile__ *unzFile;
#else
typedef voidp unzFile;
#endif

typedef enum {

    UNZ_OK = 0,

    UNZ_ERRNO   = Z_ERRNO,
    UNZ_EOF     = 0,

    UNZ_END_OF_LIST_OF_FILE     = -100,
    UNZ_PARAMERROR              = -102,
    UNZ_BADZIPFILE              = -103,
    UNZ_INTERNALERROR           = -104,
    UNZ_CRCERROR                = -105

} UNZ_ERRCODE;

/* tm_unz contain date/time info */
typedef struct tm_unz_s
{
    uInt tm_sec;    /* seconds after the minute - [0..59] */
    uInt tm_min;    /* minutes after the hour - [0..59] */
    uInt tm_hour;   /* hours since midnight - [0..23] */
    uInt tm_mday;   /* day of the month - [1..31] */
    uInt tm_mon;    /* months since January - [0..11] */
    uInt tm_year;   /* years - [1980..2044] */
} tm_unz;

/* unz_global_info structure contain global data about the ZIPfile
   These data comes from the end of central dir */
typedef struct unz_global_info_s
{
    ZPOS64_T number_entry;  /* total number of entries in the central dir on this disk */
    uLong size_comment;     /* size of the global comment of the zipfile */
} unz_global_info;

/* unz_file_info contain information about a file in the zipfile */
typedef struct unz_file_info_s
{
    ushort version;             /* version made by                 2 bytes */
    ushort version_needed;      /* version needed to extract       2 bytes */
    ushort flag;                /* general purpose bit flag        2 bytes */
    ushort compression_method;  /* compression method              2 bytes */
    uLong dosDate;              /* last mod file date in Dos fmt   4 bytes */
    uLong crc;                  /* crc-32                          4 bytes */
    ZPOS64_T compressed_size;   /* compressed size                 8 bytes */
    ZPOS64_T uncompressed_size; /* uncompressed size               8 bytes */
    ushort size_filename;       /* filename length                 2 bytes */
    ushort size_file_extra;     /* extra field length              2 bytes */
    ushort size_file_comment;   /* file comment length             2 bytes */

    ushort disk_num_start;      /* disk number start               2 bytes */
    ushort internal_fa;         /* internal file attributes        2 bytes */
    uLong external_fa;          /* external file attributes        4 bytes */

    tm_unz tmu_date;            /* timestamp (6 ushorts)          96 bytes */
} unz_file_info;

extern int unzStringFileNameCompare(const char* fileName1, const char* fileName2, int iCaseSensitivity);
/*
   Compare two filename (fileName1,fileName2).
   If iCaseSenisivity = 1, comparision is case sensitivity (like strcmp)
   If iCaseSenisivity = 2, comparision is not case sensitivity (like strcmpi
                                or strcasecmp)
   If iCaseSenisivity = 0, case sensitivity is defaut of your operating system
    (like 1 on Unix)
*/


extern unzFile unzOpen(const char *path);
/*
  Open a Zip file. path contain the full pathname (by example,
     on an Unix computer "zlib/zlib113.zip").
  If the zipfile cannot be opened (file don't exist or in not valid), the
       return value is NULL.
  Else, the return value is a unzFile Handle, usable with other function
       of this unzip package.
*/


extern int unzClose(unzFile file);
/*
  Close a ZipFile opened with unzipOpen.
  If there is files inside the .Zip opened with unzOpenCurrentFile (see later),
    these files MUST be closed with unzipCloseCurrentFile before call unzipClose.
  return UNZ_OK if there is no problem. */

extern int unzGetGlobalInfo(unzFile file, unz_global_info *pglobal_info);

/*
  Write info about the ZipFile in the *pglobal_info structure.
  No preparation of the structure is needed
  return UNZ_OK if there is no problem. */


extern int unzGetGlobalComment(unzFile file, char *szComment, uLong uSizeBuf);
/*
  Get the global comment string of the ZipFile, in the szComment buffer.
  uSizeBuf is the size of the szComment buffer.
  return the number of byte copied or an error code <0
*/


/***************************************************************************/
/* Unzip package allow you browse the directory of the zipfile */

extern int unzGoToFirstFile(unzFile file);
/*
  Set the current file of the zipfile to the first file.
  return UNZ_OK if there is no problem
*/

extern int unzGoToNextFile(unzFile file);
/*
  Set the current file of the zipfile to the next file.
  return UNZ_OK if there is no problem
  return UNZ_END_OF_LIST_OF_FILE if the actual file was the latest.
*/

extern int unzLocateFile(unzFile file, const char *szFileName, int iCaseSensitivity);
/*
  Try locate the file szFileName in the zipfile.
  For the iCaseSensitivity signification, see unzStringFileNameCompare

  return value :
  UNZ_OK if the file is found. It becomes the current file.
  UNZ_END_OF_LIST_OF_FILE if the file is not found
*/


/* ****************************************** */
/* Ryan supplied functions */
/* unz_file_info contain information about a file in the zipfile */

typedef struct unz_file_pos_s
{
    ZPOS64_T pos_in_zip_directory;   /* offset in zip file directory */
    ZPOS64_T num_of_file;            /* # of file */
} unz_file_pos;

extern int unzGetFilePos(unzFile file, unz_file_pos* file_pos);

extern int unzGoToFilePos(unzFile file, const unz_file_pos* file_pos);

/* ****************************************** */

extern int unzGetCurrentFileInfo(unzFile file,
                                 unz_file_info* pfile_info,
                                 char *szFileName,
                                 uLong fileNameBufferSize,
                                 void *extraField,
                                 uLong extraFieldBufferSize,
                                 char *szComment,
                                 uLong commentBufferSize);
/*
  Get Info about the current file
  if pfile_info!=NULL, the *pfile_info structure will contain somes info about
        the current file
  if szFileName!=NULL, the filemane string will be copied in szFileName
            (fileNameBufferSize is the size of the buffer)
  if extraField!=NULL, the extra field information will be copied in extraField
            (extraFieldBufferSize is the size of the buffer).
            This is the Central-header version of the extra field
  if szComment!=NULL, the comment string of the file will be copied in szComment
            (commentBufferSize is the size of the buffer)
*/


/** Addition for GDAL : START */

extern ZPOS64_T unzGetCurrentFileZStreamPos(unzFile file);

/** Addition for GDAL : END */


/***************************************************************************/
/* for reading the content of the current zipfile, you can open it, read data
   from it, and close it (you can close it before reading all the file)
   */

extern int unzOpenCurrentFile(unzFile file);
/*
  Open for reading data the current file in the zipfile.
  If there is no error, the return value is UNZ_OK.
*/

extern int unzOpenCurrentFilePassword(unzFile file, const char* password);
/*
  Open for reading data the current file in the zipfile.
  password is a crypting password
  If there is no error, the return value is UNZ_OK.
*/

extern int unzOpenCurrentFile2(unzFile file, int* method, int* level, int raw);
/*
  Same than unzOpenCurrentFile, but open for read raw the file (not uncompress)
    if raw==1
  *method will receive method of compression, *level will receive level of
     compression
  note : you can set level parameter as NULL (if you don't need the leve),
         but you CANNOT set method parameter as NULL
*/

extern int unzOpenCurrentFile3(unzFile file, int* method, int* level, int raw, const char* password);
/*
  Same than unzOpenCurrentFile, but open for read raw the file (not uncompress)
    if raw==1
  *method will receive method of compression, *level will receive level of
     compression
  note : you can set level parameter as NULL (if you did not want known level,
         but you CANNOT set method parameter as NULL
*/


extern int unzCloseCurrentFile(unzFile file);
/*
  Close the file in zip opened with unzOpenCurrentFile
  Return UNZ_CRCERROR if all the file was read but the CRC is not good
*/

extern int unzReadCurrentFile(unzFile file, voidp buf, unsigned int len);
/*
  Read bytes from the current file (opened by unzOpenCurrentFile)
  buf contain buffer where data must be copied
  len the size of buf.

  return the number of byte copied if somes bytes are copied
  return 0 if the end of file was reached
  return <0 with error code if there is an error
    (UNZ_ERRNO for IO error, or zLib error for uncompress error)
*/

extern ZPOS64_T unztell(unzFile file);
/*
  Give the current position in uncompressed data
*/

extern int unzeof(unzFile file);
/*
  return 1 if the end of file was reached, 0 elsewhere
*/

extern int unzGetLocalExtrafield(unzFile file, voidp buf, unsigned int len);
/*
  Read extra field from the current file (opened by unzOpenCurrentFile)
  This is the local-header version of the extra field (sometimes, there is
    more info in the local-header version than in the central-header)

  if buf==NULL, it return the size of the local extra field

  if buf!=NULL, len is the size of the buffer, the extra header is copied in
    buf.
  the return value is the number of bytes copied in buf, or (if <0)
    the error code
*/

/***************************************************************************/

/* Get the current file offset */
extern ZPOS64_T unzGetOffset(unzFile file);

/* Set the current file offset */
extern int unzSetOffset(unzFile file, ZPOS64_T pos);



#ifdef __cplusplus
} // extern "C"
#endif

#endif /* _unz64_H */
