#include <stdint.h>
#include <stddef.h>
#include <string.h>

int32_t wasmkit_compare_bytes(const void *left, const void *right, size_t count) {
    const unsigned char *a = left, *b = right;
    while (count >= sizeof(uint64_t)) {
        uint64_t x, y;
        memcpy(&x, a, sizeof(x));
        memcpy(&y, b, sizeof(y));
        if (x != y) break;
        a += sizeof(x); b += sizeof(y); count -= sizeof(x);
    }
    while (count--) {
        int32_t difference = (int32_t)*a++ - (int32_t)*b++;
        if (difference) return difference;
    }
    return 0;
}
