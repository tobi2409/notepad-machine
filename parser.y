%{
    #include <stdio.h>
    #include <string.h>

    struct Instruction;

    void run();
    void runInstructions(struct Instruction *instructionList, int instructionCount);

    int yylex();
    void yyerror(const char* s);

    #define MAX_INSTRUCTIONS 20
    #define MAX_MODULES 20
    #define MAX_MODULE_NAME_LENGTH 31

    struct AddressComponent {
        int isDynamic;
        int value;
        int referenceRow;
        int referenceColumn;
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
        COMPARISON_LESS
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
                char moduleName[MAX_MODULE_NAME_LENGTH + 1];
            } gotoInstruction;

            struct {
                struct Address address;
                struct CompareOperand operand;
            } compareInstruction;

            struct {
                enum ComparisonCondition condition;
                char moduleName[MAX_MODULE_NAME_LENGTH + 1];
            } conditionalGotoInstruction;
        } data;
    };

    struct Module {
        char name[MAX_MODULE_NAME_LENGTH + 1];
        struct Instruction instructions[MAX_INSTRUCTIONS];
        int instructionsSize;
    };

    struct Instruction instructions[MAX_INSTRUCTIONS] = {}; // Tätigkeitenblatt mit 20 Zeilen
    int instructionsSize = 0;
    struct Module modules[MAX_MODULES] = {};
    int modulesSize = 0;
    struct Instruction *currentInstructions = instructions;
    int *currentInstructionsSize = &instructionsSize;

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

%code requires {
    struct AddressComponent {
        int isDynamic;
        int value;
        int referenceRow;
        int referenceColumn;
    };

    struct Address {
        struct AddressComponent row;
        struct AddressComponent column;
    };
}

%union {
    int digit;
    char character;
    char string[32];

    struct Address address;
    struct AddressComponent addressComponent;
}

%token<digit> DIGIT
%token<character> CHARACTER
%token<string> STRING
%token ASSIGN
%token RUN
%token PRINT_MEMORY
%token MODULE
%token END
%token GOTO
%token COMPARE
%token COMMA
%token EQUAL
%token NOTEQUAL
%token GREATER
%token LESS

%token LBRACKET RBRACKET
%type<address> address
%type<addressComponent> addressComponent

%%


input:
    instruction
    | instruction input;
instruction:
    assign
    | goto
    | compare
    | conditionalGoto
    | module
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
module:
    MODULE STRING {
        struct Module *module = &modules[modulesSize++];
        strcpy(module->name, $2);
        currentInstructions = module->instructions;
        currentInstructionsSize = &module->instructionsSize;
    } moduleInstructions END {
        currentInstructions = instructions;
        currentInstructionsSize = &instructionsSize;
    };
moduleInstructions:
    moduleInstruction
    | moduleInstruction moduleInstructions;
moduleInstruction:
    assign
    | goto
    | compare
    | conditionalGoto;
goto:
    GOTO STRING {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_GOTO;
        strcpy(currentInstructions[nextIndex].data.gotoInstruction.moduleName, $2);
    };
compare:
    COMPARE address COMMA DIGIT {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_COMPARE;
        currentInstructions[nextIndex].data.compareInstruction.address = $2;
        currentInstructions[nextIndex].data.compareInstruction.operand.type = COMPAREVALUETYPE_DIGIT;
        currentInstructions[nextIndex].data.compareInstruction.operand.value.digit = $4;
    }
    | COMPARE address COMMA CHARACTER {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_COMPARE;
        currentInstructions[nextIndex].data.compareInstruction.address = $2;
        currentInstructions[nextIndex].data.compareInstruction.operand.type = COMPAREVALUETYPE_CHARACTER;
        currentInstructions[nextIndex].data.compareInstruction.operand.value.character = $4;
    }
    | COMPARE address COMMA address {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_COMPARE;
        currentInstructions[nextIndex].data.compareInstruction.address = $2;
        currentInstructions[nextIndex].data.compareInstruction.operand.type = COMPAREVALUETYPE_ADDRESS;
        currentInstructions[nextIndex].data.compareInstruction.operand.value.address = $4;
    };
conditionalGoto:
    EQUAL GOTO STRING {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        currentInstructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_EQUAL;
        strcpy(currentInstructions[nextIndex].data.conditionalGotoInstruction.moduleName, $3);
    }
    | NOTEQUAL GOTO STRING {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        currentInstructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_NOTEQUAL;
        strcpy(currentInstructions[nextIndex].data.conditionalGotoInstruction.moduleName, $3);
    }
    | GREATER GOTO STRING {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        currentInstructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_GREATER;
        strcpy(currentInstructions[nextIndex].data.conditionalGotoInstruction.moduleName, $3);
    }
    | LESS GOTO STRING {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_CONDITIONAL_GOTO;
        currentInstructions[nextIndex].data.conditionalGotoInstruction.condition = COMPARISON_LESS;
        strcpy(currentInstructions[nextIndex].data.conditionalGotoInstruction.moduleName, $3);
    };
assign:
    address ASSIGN DIGIT {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_ASSIGNDIGIT;
        currentInstructions[nextIndex].data.assignDigitInstruction.address = $1;
        currentInstructions[nextIndex].data.assignDigitInstruction.digit = $3;
    }
    | address ASSIGN CHARACTER {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_ASSIGNCHARACTER;
        currentInstructions[nextIndex].data.assignCharacterInstruction.address = $1;
        currentInstructions[nextIndex].data.assignCharacterInstruction.character = $3;
    }
    | address ASSIGN address {
        int nextIndex = (*currentInstructionsSize)++;
        currentInstructions[nextIndex].instructionType = INSTRUCTIONTYPE_ASSIGNADDRESS;
        currentInstructions[nextIndex].data.assignAddressInstruction.source = $3;
        currentInstructions[nextIndex].data.assignAddressInstruction.destination = $1;
    };

address:
    LBRACKET addressComponent COMMA addressComponent RBRACKET {
        $$.row = $2;
        $$.column = $4;
    };
addressComponent:
    DIGIT {
        $$.isDynamic = 0;
        $$.value = $1;
        $$.referenceRow = 0;
        $$.referenceColumn = 0;
    }
    | LBRACKET DIGIT COMMA DIGIT RBRACKET {
        $$.isDynamic = 1;
        $$.value = 0;
        $$.referenceRow = $2;
        $$.referenceColumn = $4;
    };

%%

void run() {
    runInstructions(instructions, instructionsSize);
}

int resolveAddressComponent(struct AddressComponent component) {
    if (!component.isDynamic) {
        return component.value;
    }

    struct MemoryCell cell = memory[component.referenceRow][component.referenceColumn];
    return cell.valueType == VALUETYPE_DIGIT ? cell.value.digit : 0;
}

void resolveAddress(struct Address address, int *row, int *column) {
    *row = resolveAddressComponent(address.row);
    *column = resolveAddressComponent(address.column);
}

void runInstructions(struct Instruction instructionList[], int instructionCount) {
    enum ComparisonCondition lastComparison = COMPARISON_NOTEQUAL;

    for (int i = 0 ; i < instructionCount ; i++) {
        struct Instruction instruction = instructionList[i];

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
            for (int moduleIndex = 0 ; moduleIndex < modulesSize ; moduleIndex++) {
                if (strcmp(modules[moduleIndex].name, instruction.data.gotoInstruction.moduleName) == 0) {
                    runInstructions(modules[moduleIndex].instructions, modules[moduleIndex].instructionsSize);
                    break;
                }
            }
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
                || (condition == COMPARISON_NOTEQUAL && lastComparison != COMPARISON_EQUAL);

            if (matches) {
                for (int moduleIndex = 0 ; moduleIndex < modulesSize ; moduleIndex++) {
                    if (strcmp(modules[moduleIndex].name, instruction.data.conditionalGotoInstruction.moduleName) == 0) {
                        runInstructions(modules[moduleIndex].instructions, modules[moduleIndex].instructionsSize);
                        break;
                    }
                }
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