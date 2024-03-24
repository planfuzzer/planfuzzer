#include "client.h"

#include <cassert>
#include <string>

#include "client_postgresql.h"
#include "utils.h"

namespace client {
DBClient *create_client(const std::string &db_name, const YAML::Node &config) {
  DBClient *result = nullptr;
  
  if (db_name == "postgresql") {
    result = new PostgreSQLClient;
  } else {
    ERROR("%s is not supported", db_name.c_str());
  }

  result->initialize(config);
  return result;
}
};  // namespace client
