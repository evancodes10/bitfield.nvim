#ifndef PARSER_H
#define PARSER_H

#include <clang-c/Index.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define MAX_FIELDS 256
#define MAX_NAME 128
#define MAX_TYPE 128

typedef struct
{
    char name[MAX_NAME];
    char type[MAX_TYPE];
    int bit_width;
    int64_t bit_offset;
    int64_t byte_size;
    int is_bitfield;
} Field;

typedef struct
{
    unsigned target_line;
    unsigned target_col;
    CXCursor found_struct;
    int found;
} SearchState;

typedef struct
{
    Field fields[MAX_FIELDS];
    int count;
    CXTranslationUnit tu;
} FieldState;

#endif
