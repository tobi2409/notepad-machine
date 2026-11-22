%{
    #include <stdlib.h>
    #include <string.h>
    #include "parser.tab.h"

    #define MAX_INCLUDE_DEPTH 20
    YY_BUFFER_STATE includeStack[MAX_INCLUDE_DEPTH];
    int includeStackPointer = 0;

    int includeFile(const char *filename) {
        if (includeStackPointer >= MAX_INCLUDE_DEPTH) {
            fprintf(stderr, "INCLUDE nesting too deep\n");
            return 0;
        }

        FILE *file = fopen(filename, "r");
        if (!file) {
            fprintf(stderr, "Cannot include file: %s\n", filename);
            return 0;
        }

        includeStack[includeStackPointer++] = YY_CURRENT_BUFFER;
        yy_switch_to_buffer(yy_create_buffer(file, YY_BUF_SIZE));
        return 1;
    }
%}

%x LABEL_STATE INCLUDE_STATE

%%

[ \t\r\n]+ {
}

[0-9] {
     yylval.digit = atoi(yytext);
     return DIGIT;
}

[0-9][0-9]+ {
     yylval.coordinateNumber = atoi(yytext);
    return COORDINATE_NUMBER;
}

"h" {
    return HELPER_ADDRESS;
}

[a-zA-Z] {
    yylval.character = yytext[0];
    return CHARACTER;
}

"[" {
    return LBRACKET;
}

"]" {
    return RBRACKET;
}

":=" {
    return ASSIGN;
}

"," {
    return COMMA;
}

"MEMORY" {
    return PRINT_MEMORY;
}

"HELPER_MEMORY" {
    return PRINT_HELPER_MEMORY;
}

"INCLUDE" {
    BEGIN(INCLUDE_STATE);
    return INCLUDE;
}

"LABEL" {
    BEGIN(LABEL_STATE);
    return LABEL;
}

"GOTO" {
    BEGIN(LABEL_STATE);
    return GOTO;
}

"COMPARE" {
    return COMPARE;
}

">=" {
    return GREATER_OR_EQUAL;
}

"<=" {
    return LESS_OR_EQUAL;
}

"<>" {
    return NOT_EQUAL;
}

"=" {
    return EQUAL;
}

">" {
    return GREATER;
}

"<" {
    return LESS;
}

<LABEL_STATE>[ \t\r\n]+ {
}

<LABEL_STATE>[a-zA-Z_][a-zA-Z0-9_]* {
    strncpy(yylval.labelName, yytext, sizeof(yylval.labelName) - 1);
    yylval.labelName[sizeof(yylval.labelName) - 1] = '\0';
    BEGIN(INITIAL);
    return LABEL_NAME;
}

<INCLUDE_STATE>[ \t\r\n]+ {
}

<INCLUDE_STATE>[^ \t\r\n]+ {
    strncpy(yylval.fileName, yytext, sizeof(yylval.fileName) - 1);
    yylval.fileName[sizeof(yylval.fileName) - 1] = '\0';
    BEGIN(INITIAL);
    return FILE_NAME;
}

%%

int yywrap() {
    if (includeStackPointer == 0) {
        return 1;
    }

    yy_delete_buffer(YY_CURRENT_BUFFER);
    yy_switch_to_buffer(includeStack[--includeStackPointer]);
    return 0;
}