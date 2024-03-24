#include <cassert>
#include <cstring>
#include <iostream>
#include <string>
#include <unistd.h>
#include <fstream>
// GCC version < 8.0
#include <experimental/filesystem>
#include <vector>

#include "client.h"
#include "yaml-cpp/yaml.h"

#include "pgcuckoo.h"
#include "utils.h"


namespace fs=std::experimental::filesystem;

int main(int argc, char **argv) {
  YAML::Node config = YAML::LoadFile("../config.yml");
  std::string db_name = config["db"].as<std::string>();
  std::string startup_cmd = config["startup_cmd"].as<std::string>();
  client::DBClient *test_client = client::create_client(db_name, config);
  std::string cuckoo_conn = test_client->cuckoo_conn();
  std::string input_path = argv[1];

  if (!test_client->check_alive()) {
    system(startup_cmd.c_str());
    sleep(3);
  }
  test_client->prepare_env();

  std::string op;
  char* sql;
  int i=0;
  
  // while(1){
  for (const auto & entry : fs::directory_iterator(input_path)){

    std::string filename = entry.path().filename().string();
    if (entry.path().extension() == ".txt"){
    // if (filename.find("id") == 0) {
        // i += 1;

        std::ifstream infile(entry.path());
        std::getline(infile, op);

        std::cout << "\033[" << "34m" << "Read seed:" << entry.path() << "\033[0m" << std::endl;
        std::cout << "Cuckoo conn : " << cuckoo_conn << std::endl;
        sql = operator2PlannedStmt(op, cuckoo_conn);

        // fill faild，continue
        if(sql == NULL){
          test_client->clean_up_env();
          LOG("red", "Error: fill plan error!");
          continue;
        }

        client::ExecutionStatus result = test_client->execute(sql, strlen(sql));
        // client::ExecutionStatus result = test_client->execute(op.c_str(), strlen(op.c_str()));
        if(result != client::kNormal){
          LOG("red", "Error: pg run error!");
          while (!test_client->check_alive()) {
          // Wait for the server to be restart.
            sleep(5);
          }  
        }
        test_client->clean_up_env();
      }
          
  }
       
}