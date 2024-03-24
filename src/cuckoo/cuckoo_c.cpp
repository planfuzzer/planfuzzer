#include <iostream>
#include <cstring>
#include "../include/cuckoo_stub.h"

/**
 * @brief call Haskell function，Convert String to PlannedStmt
 * 
 * @param input mutated data from AFL
 * @return char* return NULL on error
 */
char* operator2PlannedStmt(std::string input, std::string connection){
    char *op = new char[input.length() + 1]; 
    char *conn = new char[connection.length() + 1];
    char* output;

    strcpy(op, input.c_str());
    strcpy(conn, connection.c_str());

    hs_init(nullptr, nullptr);
    output = (char*)operatorToPlan((HsPtr)op, (HsPtr)conn);  

    delete op;
    if(strlen(output) == 0){
        return NULL;
    }

    return output;
}

