#ifndef __UTILS_H__
#define __UTILS_H__

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <iostream>

inline void ERROR(const char *fmt, ...) {  
    va_list ap; 
    va_start(ap, fmt);  
    vfprintf(stderr, fmt, ap); 
    va_end(ap); 

    exit(1);
}

inline void LOG(std::string color, std::string s){
    
    if(color=="red"){
        std::cout << "\033[" << "31m" << s << "\033[0m\n" ;
    }else if(color=="green"){
        std::cout << "\033[" << "32m" << s << "\033[0m\n" ;
    }else if(color=="blue"){
        std::cout << "\033[" << "34m" << s << "\033[0m\n" ;
    }
    
}


#endif