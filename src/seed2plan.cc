/*
g++ -I "../include" -I "/usr/include/yaml-cpp" seed2plan.cc -std=c++17 -lstdc++fs -L"../cuckoo" -L"/usr/lib/x86_64-linux-gnu/"  -lpgcuckoo -lyaml-cpp -o seed2plan
*/ 
#include <experimental/filesystem>
#include <fstream>
#include <iostream>
#include <vector>
#include "yaml-cpp/yaml.h"

#include "pgcuckoo.h"

namespace fs = std::experimental::filesystem;

int main (int argc, char** argv){
    YAML::Node config = YAML::LoadFile("../config.yml");
    std::string db_name = config["db_name"].as<std::string>();
    std::string user_name = config["user_name"].as<std::string>();
    std::string host = config["host"].as<std::string>();
    std::string port = config["port"].as<std::string>();
    std::string cuckoo_conn = "hostaddr="+host+ " " +"port="+port+ " " +"connect_timeout=4"+ " " +"dbname=" + db_name;
    std::string line;
    char * sql; 
    fs::path dir { argv [2] };

    if (argc < 3){
        std::cout << "Translate seed to plannedStmt, config in planfuzzer/config.yml." << std::endl;
        std::cout << "Usage: " << argv [0] << "\t" << "seedDir" << "\t" << "planedstmtDir" << std::endl;
        return 1;
    }

    // 检查目录是否存在
    if (!fs::is_directory (dir)){
        std::cout << "dir not exist !" << std::endl;
        return 1;
    }

    for (auto& file : fs::directory_iterator{argv[1]}){
        if (!fs::is_directory (file.path())){ 
            std::ifstream fs { file.path () }; //打开文件

            if (fs.is_open()){
                getline (fs, line); //读取文件的一行
                
                sql = operator2PlannedStmt(line, cuckoo_conn);
                // 填充计划失败，continue
                if(sql == NULL){
                    std::cout << file.path().filename() << " translate to plannedstmt error!" << std::endl;
                    continue;
                }

                fs::path file_saved = dir / file.path().filename() ; //构造文件名
                std::ofstream ofs { file_saved }; //打开文件
                if (ofs){
                    ofs << std::string(sql) << std::endl; //写入字符串
                    ofs.close (); //关闭文件
                    // std::cout << "File " << file_saved << " written successfully." << std::endl;
                }else
                    std::cout << "Unable to open plannedstmt file: " << file_saved << std::endl;
                }

                fs.close (); //关闭文件
        }
    }
}

