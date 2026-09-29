#include <stdio.h>
#include <string.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/ssl.h>
#include <zlib/zlib.h>

int main(void)
{
    static const unsigned char expected_sha256[32] = {
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad
    };
    static const unsigned char input[] = "abc";
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_length = 0;
    unsigned char compressed[128];
    unsigned char restored[sizeof(input)];
    uLongf compressed_length = sizeof(compressed);
    uLongf restored_length = sizeof(restored);
    SSL_CTX *context;

    if (OpenSSL_version_num() != OPENSSL_VERSION_NUMBER ||
        strcmp(zlibVersion(), ZLIB_VERSION) != 0)
    {
        fprintf(stderr, "Dependency versions do not match the repository headers.\n");
        return 1;
    }
    /* No external configuration, sockets, services, or driver operations. */
    if (!OPENSSL_init_ssl(OPENSSL_INIT_NO_LOAD_CONFIG, NULL))
    {
        return 2;
    }
    context = SSL_CTX_new(TLS_method());
    if (context == NULL)
    {
        return 3;
    }
    SSL_CTX_free(context);
    if (!EVP_Digest(input, sizeof(input) - 1, digest, &digest_length, EVP_sha256(), NULL) ||
        digest_length != sizeof(expected_sha256) ||
        memcmp(digest, expected_sha256, sizeof(expected_sha256)) != 0)
    {
        return 4;
    }
    if (compress2(compressed, &compressed_length, input, sizeof(input), Z_BEST_COMPRESSION) != Z_OK ||
        uncompress(restored, &restored_length, compressed, compressed_length) != Z_OK ||
        restored_length != sizeof(input) || memcmp(restored, input, sizeof(input)) != 0)
    {
        return 5;
    }
    printf("%s; zlib %s; TLS context, SHA-256 and compression checks passed.\n",
        OpenSSL_version(OPENSSL_VERSION), zlibVersion());
    OPENSSL_cleanup();
    return 0;
}
