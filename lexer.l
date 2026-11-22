%{
    #include <stdlib.h>
    #include <string.h>
    #include "parser.tab.h"
%}

%x LABEL_STATE

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

"LABEL" {
    BEGIN(LABEL_STATE);
    return LABEL;
}

"GOTO" {
    BEGIN(LABEL_STATE);
    return GOTO;
}

"END" {
    return END;
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

%%

int yywrap() {
    return 1; // Eingabe ist am Dateiende beendet
}