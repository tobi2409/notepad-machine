%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    struct Instruction;
    struct AddressComponent;
    struct Address;

    void run();
    void runInstructions();
    int resolveAddressComponent(struct AddressComponent component);
    void resolveAddress(struct Address address, int *row, int *column);

    int yylex();
    void yyerror(const char* s);

    #define MAX_INSTRUCTIONS 20
    #define MAX_LABELS 20
    #define MAX_LABEL_NAME_LENGTH 31

    struct AddressComponent {
        int isDynamic;
        int value;
        struct Address *reference;
    };

    struct Address {
        struct AddressComponent row;
        struct AddressComponent column;
    };

    enum InstructionType {
        INSTRUCTIONTYPE_ASSIGNDIGIT,
        INSTRUCTIONTYPE_ASSIGNCHARACTER,
        INSTRUCTIONTYPE_ASSIGNADDRESS,
        INSTRUCTIONTYPE_GOTO,
        INSTRUCTIONTYPE_COMPARE,
        INSTRUCTIONTYPE_CONDITIONAL_GOTO
    };

    enum CompareValueType {
        COMPAREVALUETYPE_DIGIT,
        COMPAREVALUETYPE_CHARACTER,
        COMPAREVALUETYPE_ADDRESS 
    };

    enum ComparisonCondition {
        COMPARISON_EQUAL,
        COMPARISON_NOTEQUAL,
        COMPARISON_GREATER,
        COMPARISON_LESS,
        COMPARISON_GREATEROREQUAL,
        COMPARISON_LESSOREQUAL
    };

    struct CompareOperand {
        enum CompareValueType type;
        union {
            int digit;
            char character;
            struct Address address;
        } value;
    };

    struct Instruction {
        enum InstructionType instructionType;

        union {
            struct {
                struct Address address;
                int digit;
            } assignDigitInstruction;

            struct {
                struct Address address;
                char character;
            } assignCharacterInstruction;

            struct {
                struct Address source;
                struct Address destination;
            } assignAddressInstruction;

            struct {
                char labelName[MAX_LABEL_NAME_LENGTH + 1];
            } gotoInstruction;

            struct {
                struct Address address;
                struct CompareOperand operand;
            } compareInstruction;

            struct {
                enum ComparisonCondition condition;
                char labelName[MAX_LABEL_NAME_LENGTH + 1];
            } conditionalGotoInstruction;
        } data;
    };

    struct Label {
        char name[MAX_LABEL_NAME_LENGTH + 1];
        int instructionPointer;
    };

    struct Instruction instructions[MAX_INSTRUCTIONS] = {}; // Tätigkeitenblatt mit 20 Zeilen
    int instructionsSize = 0;
    struct Label labels[MAX_LABELS] = {};
    int labelsSize = 0;
    int instructionPointer = 0;

    enum ValueType {
        VALUETYPE_DIGIT,
        VALUETYPE_CHARACTER
    };

    // union kann genau ein Feld belegen
    struct MemoryCell {
        enum ValueType valueType;
        union {
            int digit;
            char character;
        } value;
    };

    struct MemoryCell memory[5][5] = {}; // kariertes Papier 5x5 Zellen
%}

/* Flex bindet parser.tab.h ein; dort muss YYSTYPE die Adresstypen vollständig kennen, damit yylval kompiliert. */
%code requires {
    struct Address;

    struct AddressComponent {
        int isDynamic;
        int value;
        struct Address *reference;
    };

    struct Address {
        struct AddressComponent row;
        struct AddressComponent column;
    };
}

%union {
    int digit;
    int coordinateNumber;
    char character;
    char labelName[32]; // Labelnamen sind kein Datentyp der Sprache, sondern Parser-Metadaten

    struct Address address;
    struct AddressComponent addressComponent;
}

%token<digit> DIGIT
%token<coordinateNumber> COORDINATE_NUMBER
%token<character> CHARACTER
%token<labelName> LABEL_NAME
%token ASSIGN
%token RUN
%token PRINT_MEMORY
%token LABEL
%token END
%token GOTO
%token COMPARE
%token COMMA
%token EQUAL NOT_EQUAL GREATER LESS GREATER_OR_EQUAL LESS_OR_EQUAL
%token LBRACKET RBRACKET
%type<address> address
%type<addressComponent> addressComponent
%type<coordinateNumber> coordinateNumber

%%


input:
    instruction
    | instruction input;
instruction:
    assign
    | goto
    | compare
    | conditionalGoto
    | label
    | PRINT_MEMORY {
        for (int i = 0 ; i < 5 ; i++) {
            for (int j = 0 ; j < 5 ; j++) {
                if (memory[i][j].valueType == VALUETYPE_DIGIT) {
                    printf("%d", memory[i][j].value.digit);
                } else if (memory[i][j].valueType == VALUETYPE_CHARACTER) {
                    printf("%c", memory[i][j].value.character);
                }
            }

            printf("\n");
        }
    }
    | RUN {
        run();
    };
label:
    LABEL LABEL_NAME {
        struct Label *label = &labels[labelsSize++];
        strcpy(label->name, $2);
        label->instructionPointer = instructionsSize;
    };
goto:
    GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_GOTO;
        strcpy(instructions[nextIndex].data.gotoInstruction.labelName, $2);
    };
compare:
    COMPARE address COMMA DIGIT {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_COMPARE;
        instructions[nextIndex].data.compareInstruction.address = $2;
        instructions[nextIndex].data.compareInstruction.operand.type = COMPAREVALUETYPE_DIGIT;
        instructions[nextIndex].data.compareInstruction.operand.value.digit = $4;
    }
    | COMPARE address COMMA CHARACTER {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_COMPARE;
        instructions[nextIndex].data.compareInstruction.address = $2;
        instructions[nextIndex].data.compareInstruction.operand.type = COMPAREVALUETYPE_CHARACTER;
        instructions[nextIndex].data.compareInstruction.operand.value.character = $4;
    }
    | COMPARE address COMMA address {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_COMPARE;
        instructions[nextIndex].data.compareInstruction.address = $2;
        instructions[nextIndex].data.compareInstruction.operand.type = COMPAREVALUETYPE_ADDRESS;
        instructions[nextIndex].data.compareInstruction.operand.value.address = $4;
    };
conditionalGoto:
    EQUAL GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        instructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_EQUAL;
        strcpy(instructions[nextIndex].data.conditionalGotoInstruction.labelName, $3);
    }
    | NOT_EQUAL GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        instructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_NOTEQUAL;
        strcpy(instructions[nextIndex].data.conditionalGotoInstruction.labelName, $3);
    }
    | GREATER GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        instructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_GREATER;
        strcpy(instructions[nextIndex].data.conditionalGotoInstruction.labelName, $3);
    }
    | LESS GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        instructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_LESS;
        strcpy(instructions[nextIndex].data.conditionalGotoInstruction.labelName, $3);
    }
    | GREATER_OR_EQUAL GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        instructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_GREATEROREQUAL;
        strcpy(instructions[nextIndex].data.conditionalGotoInstruction.labelName, $3);
    }
    | LESS_OR_EQUAL GOTO LABEL_NAME {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        instructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_LESSOREQUAL;
        strcpy(instructions[nextIndex].data.conditionalGotoInstruction.labelName, $3);
    };
assign:
    address ASSIGN DIGIT {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_ASSIGNDIGIT;
        instructions[nextIndex].data.assignDigitInstruction.address = $1;
        instructions[nextIndex].data.assignDigitInstruction.digit = $3;
    }
    | address ASSIGN CHARACTER {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_ASSIGNCHARACTER;
        instructions[nextIndex].data.assignCharacterInstruction.address = $1;
        instructions[nextIndex].data.assignCharacterInstruction.character = $3;
    }
    | address ASSIGN address {
        int nextIndex = instructionsSize++;
        instructions[nextIndex].instructionType = INSTRUCTIONTYPE_ASSIGNADDRESS;
        instructions[nextIndex].data.assignAddressInstruction.source = $3;
        instructions[nextIndex].data.assignAddressInstruction.destination = $1;
    };

address:
    LBRACKET addressComponent COMMA addressComponent RBRACKET {
        $$.row = $2;
        $$.column = $4;
    };
addressComponent:
    coordinateNumber {
        $$.isDynamic = 0;
        $$.value = $1;
        $$.reference = NULL;
    }
    | address {
        $$.isDynamic = 1;
        $$.value = 0;
        $$.reference = malloc(sizeof(struct Address));
        *$$.reference = $1;
    };
coordinateNumber:
    DIGIT {
        $$ = $1;
    }
    | COORDINATE_NUMBER {
        $$ = $1;
    }
    ;

%%

void run() {
    instructionPointer = 0;
    runInstructions();
}

int resolveAddressComponent(struct AddressComponent component) {
    if (!component.isDynamic) {
        return component.value;
    }

    int row;
    int column;
    resolveAddress(*component.reference, &row, &column);
    struct MemoryCell cell = memory[row][column];
    return cell.valueType == VALUETYPE_DIGIT ? cell.value.digit : 0;
}

void resolveAddress(struct Address address, int *row, int *column) {
    *row = resolveAddressComponent(address.row);
    *column = resolveAddressComponent(address.column);
}

int findLabel(const char *name) {
    for (int i = 0; i < labelsSize; i++) {
        if (strcmp(labels[i].name, name) == 0) {
            return labels[i].instructionPointer;
        }
    }

    return instructionsSize;
}

void runInstructions() {
    enum ComparisonCondition lastComparison = COMPARISON_NOTEQUAL;

    while (instructionPointer < instructionsSize) {
        struct Instruction instruction = instructions[instructionPointer++];

        if (instruction.instructionType == INSTRUCTIONTYPE_ASSIGNDIGIT) {
            int row;
            int column;
            resolveAddress(instruction.data.assignDigitInstruction.address, &row, &column);

            memory[row][column].valueType = VALUETYPE_DIGIT;
            memory[row][column].value.digit = instruction.data.assignDigitInstruction.digit;
        } else if (instruction.instructionType == INSTRUCTIONTYPE_ASSIGNCHARACTER) {
            int row;
            int column;
            resolveAddress(instruction.data.assignCharacterInstruction.address, &row, &column);

            memory[row][column].valueType = VALUETYPE_CHARACTER;
            memory[row][column].value.character = instruction.data.assignCharacterInstruction.character;
        } else if (instruction.instructionType == INSTRUCTIONTYPE_ASSIGNADDRESS) {
            int sourceRow;
            int sourceColumn;
            int destinationRow;
            int destinationColumn;
            resolveAddress(instruction.data.assignAddressInstruction.source, &sourceRow, &sourceColumn);
            resolveAddress(instruction.data.assignAddressInstruction.destination, &destinationRow, &destinationColumn);

            memory[destinationRow][destinationColumn] = memory[sourceRow][sourceColumn];
        } else if (instruction.instructionType == INSTRUCTIONTYPE_GOTO) {
            instructionPointer = findLabel(instruction.data.gotoInstruction.labelName);
        } else if (instruction.instructionType == INSTRUCTIONTYPE_COMPARE) {
            int leftRow;
            int leftColumn;
            resolveAddress(instruction.data.compareInstruction.address, &leftRow, &leftColumn);
            struct MemoryCell left = memory[leftRow][leftColumn];
            struct MemoryCell right = {};
            struct CompareOperand operand = instruction.data.compareInstruction.operand;

            if (operand.type == COMPAREVALUETYPE_DIGIT) {
                right.valueType = VALUETYPE_DIGIT;
                right.value.digit = operand.value.digit;
            } else if (operand.type == COMPAREVALUETYPE_CHARACTER) {
                right.valueType = VALUETYPE_CHARACTER;
                right.value.character = operand.value.character;
            } else {
                int rightRow;
                int rightColumn;
                resolveAddress(operand.value.address, &rightRow, &rightColumn);
                right = memory[rightRow][rightColumn];
            }

            if (left.valueType == right.valueType) {
                if (left.valueType == VALUETYPE_DIGIT) {
                    lastComparison = left.value.digit == right.value.digit ? COMPARISON_EQUAL
                        : (left.value.digit > right.value.digit ? COMPARISON_GREATER : COMPARISON_LESS);
                } else {
                    lastComparison = left.value.character == right.value.character ? COMPARISON_EQUAL
                        : (left.value.character > right.value.character ? COMPARISON_GREATER : COMPARISON_LESS);
                }
            } else {
                lastComparison = left.valueType > right.valueType ? COMPARISON_GREATER : COMPARISON_LESS;
            }
        } else if (instruction.instructionType == INSTRUCTIONTYPE_CONDITIONAL_GOTO) {
            enum ComparisonCondition condition = instruction.data.conditionalGotoInstruction.condition;
            int matches = lastComparison == condition
                || (condition == COMPARISON_NOTEQUAL && lastComparison != COMPARISON_EQUAL)
                || (condition == COMPARISON_GREATEROREQUAL
                    && (lastComparison == COMPARISON_GREATER || lastComparison == COMPARISON_EQUAL))
                || (condition == COMPARISON_LESSOREQUAL
                    && (lastComparison == COMPARISON_LESS || lastComparison == COMPARISON_EQUAL));

            if (matches) {
                instructionPointer = findLabel(instruction.data.conditionalGotoInstruction.labelName);
            }
        }
    }
}

void yyerror(const char* s) {
    printf("ERROR: %s", s);
}

int main() {
    return yyparse();
}