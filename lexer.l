%{
    #include <stdlib.h>
    #include <string.h>
    #include "parser.tab.h"
%}

%x MODULE_NAME

%%

[ \t\r\n]+ {
}

[0-9]+ {
    yylval.digit = atoi(yytext);
    return DIGIT;
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

"RUN" {
    return RUN;
}

"MEM" {
    return PRINT_MEMORY;
}

"MODULE" {
    BEGIN(MODULE_NAME);
    return MODULE;
}

"GOTO" {
    BEGIN(MODULE_NAME);
    return GOTO;
}

"END" {
    return END;
}

"COMPARE" {
    return COMPARE;
}

"NOTEQUAL:" {
    return NOTEQUAL;
}

"EQUAL:" {
    return EQUAL;
}

"GREATER:" {
    return GREATER;
}

"LESS:" {
    return LESS;
}

<MODULE_NAME>[ \t\r\n]+ {
}

<MODULE_NAME>[a-zA-Z_][a-zA-Z0-9_]* {
    strncpy(yylval.string, yytext, sizeof(yylval.string) - 1);
    yylval.string[sizeof(yylval.string) - 1] = '\0';
    BEGIN(INITIAL);
    return STRING;
}

%%

int yywrap() {
    return 0; // Scanner soll fortfahren
}