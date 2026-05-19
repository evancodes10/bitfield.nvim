#include <stdio.h>
#include <clang-c/Index.h>
#include "parser.h"

static enum CXChildVisitResult search_visitor(CXCursor c, CXCursor parent, CXClientData data)
{
    (void)parent;

    SearchState *ss = (SearchState *)data;

    enum CXCursorKind kind = clang_getCursorKind(c);

    if (kind != CXCursor_StructDecl && kind != CXCursor_UnionDecl)
    {
        return CXChildVisit_Recurse;
    }

    CXSourceRange range = clang_getCursorExtent(c);
    CXSourceLocation start = clang_getRangeStart(range);
    CXSourceLocation end = clang_getRangeEnd(range);

    unsigned sl, sc, el, ec;

    clang_getSpellingLocation(start, NULL, &sl, &sc, NULL);
    clang_getSpellingLocation(end, NULL, &el, &ec, NULL);

    int inside = (ss->target_line > sl || (ss->target_line == sl && ss->target_col >= sc)) && (ss->target_line < el || (ss->target_line == el && ss->target_col <=ec));

    if (inside)
    {
        ss->found_struct = c;
        ss->found = 1;
        return CXChildVisit_Break;
    }

    return CXChildVisit_Recurse;

}

static enum CXChildVisitResult field_visitor(CXCursor c, CXCursor parent, CXClientData data)
{
    (void)parent;
    
    FieldState *fs = (FieldState *)data;

    if (clang_getCursorKind(c) != CXCursor_FieldDecl)
    {
        return CXChildVisit_Continue;
    }

    if (fs->count >= MAX_FIELDS)
    {
        return CXChildVisit_Break;
    }

    Field *f = &fs->fields[fs->count++];

    CXString cx_name = clang_getCursorSpelling(c);
    
    snprintf(f->name, MAX_NAME, "%s", clang_getCString(cx_name));
    
    clang_disposeString(cx_name);

    CXType typ = clang_getCursorType(c);
    CXString cx_type = clang_getTypeSpelling(typ);

    snprintf(f->type, MAX_TYPE, "%s", clang_getCString(cx_type));

    clang_disposeString(cx_type);

    f->is_bitfield = clang_Cursor_isBitField(c);
    f->bit_width = f->is_bitfield ? (int)clang_getFieldDeclBitWidth(c) : -1;

    CXType parent_type = clang_getCursorType(clang_getCursorSemanticParent(c));

    long long off = clang_Type_getOffsetOf(parent_type, f->name);
    f->bit_offset = (off >= 0) ? off : -1;

    int64_t sz = (int64_t)clang_Type_getSizeOf(typ);
    f->byte_size = (sz >= 0) ? sz : 0;

    return CXChildVisit_Continue;
}

static void emit_json(FieldState *fs, const char *struct_name)
{
    printf("{\"struct\":\"%s\",\"fields\":[\n", struct_name);
    for (int i = 0; i < fs->count; i++)
    {
        Field *f = &fs->fields[i];
        
        printf("{\"name\":\"%s\",\"type\":\"%s\"," "\"is_bitfield\":%s,\"bit_width\":%d," "\"bit_offset\":%ld,\"byte_size\":%ld}%s\n", f->name, f->type, f->is_bitfield ? "true" : "false", f->bit_width, f->bit_offset, f->byte_size, (i < fs->count - 1) ? "," : "");
    }

    printf("]}\n");
}