/*
 *
 * This file comes from RFC 3174. Inclusion in gtk-gnutella is:
 */

#ifndef _SHA1_H_
#define _SHA1_H_

#include "os_stubs.h"
#include <stdint.h>

typedef unsigned char uint8;

/*
 * If you do not have the ISO standard stdint.h header file, then you
 * must typdef the following:
 *    name              meaning
 *  guint32         unsigned 32 bit integer
 *  guint8          unsigned 8 bit integer (i.e., unsigned char)
 *  gint    		integer of >= 16 bits
 *
 */

#ifndef _SHA_enum_
#define _SHA_enum_
enum
{
    shaSuccess = 0,
    shaNull,            /* Null pointer parameter */
    shaInputTooLong,    /* input data too long */
    shaStateError       /* called Input after Result */
};
#endif
#define SHA1HashSize 20

/*
 *  This structure will hold context information for the SHA-1
 *  hashing operation
 */
typedef struct SHA1Context
{
    uint32 Intermediate_Hash[SHA1HashSize/4]; /* Message Digest  */

    uint32 Length_Low;            /* Message length in bits      */
    uint32 Length_High;           /* Message length in bits      */

                               /* Index into message block array   */
    int Message_Block_Index;
    uint8 Message_Block[64];      /* 512-bit message blocks      */

    int Computed;               /* Is the digest computed?         */
    int Corrupted;             /* Is the message digest corrupted? */
} SHA1Context;

/*
 *  Function Prototypes
 */

#define SHA1_CTX SHA1Context

int sha1_init(  SHA1Context *);
int sha1_append(  SHA1Context *,
                const uint8 *,
                unsigned int);
int sha1_finish( SHA1Context *,
                uint8 Message_Digest[SHA1HashSize]);

#endif
