#ifndef PGCUCKOO_H
#define PGCUCKOO_H

#include <iostream>

/**
 * @brief call Haskell function，Convert String to PlannedStmt
 * 
 * @param input mutated data from AFL
 * @return char* return NULL on error
 */
char* operator2PlannedStmt(std::string input, std::string connection);

#endif