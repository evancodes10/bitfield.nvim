#include <stdio.h>
#include <stdlib.h>
#include <clang-c/Index.h>
#include "parser.h"

int main(int argc, char **argv)
{
    /*
    * Argv[1] is the source file path
    * Argv[2] is the 1-based line
    * Argv[3] is the 1-based column
    * Argv[4] is extra compiler flags
    */

    if (argc < 4)
    {
        fprintf(stderr, "usage: %s <file> <line> <col> [cflags...]\n", argv[0]);
        return 1;
    }

    const char *filepath = argv[1];

    unsigned target_line = (unsigned)atoi(argv[2]);
    unsigned target_col = (unsigned)atoi(argv[3]);

    const char **clang_args = NULL;
    int clang_argc = argc - 4;

    if (clang_argc > 0)
    {
        clang_args = (const char **)&argv[4];
    }

    CXIndex idx = clang_createIndex(0, 0);

    CXTranslationUnit tu = clang_parseTranslationUnit(idx, filepath, clang_args, clang_argc, NULL, 0, CXTranslationUnit_None);

    if (!tu)
    {
        fprintf(stderr, "bitfield-parse: Failed to Parse %s\n", filepath);
        clang_disposeIndex(idx);
        return 1;
    }

    SearchState ss = {.target_line = target_line, .target_col = target_col, .found = 0};

    CXCursor root = clang_getTranslationUnitCursor(tu);
    clang_visitChildren(root, search_visitor, &ss);

    if (!ss.found)
    {
        printf("[]\n");
        clang_disposeTranslationUnit(tu);
        clang_disposeIndex(idx);
        return 0;
    }

    FieldState fs = {.count = 0, .tu = tu};
    clang_visitChildren(ss.found_struct, field_visitor, &fs);

    CXString cx_name = clang_getCursorSpelling(ss.found_struct);
    const char *struct_name = clang_getCString(cx_name);

    emit_json(&fs, struct_name);

    clang_disposeString(cx_name);
    clang_disposeTranslationUnit(tu);
    clang_disposeIndex(idx);

    return 0;
}