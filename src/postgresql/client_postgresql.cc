#include "client_postgresql.h"

#include <unistd.h>

#include <cstring>
#include <deque>
#include <iostream>
#include <optional>
#include <string>

#include "client.h"
#include "libpq-fe.h"

using namespace std;

namespace client {

// load config 
void PostgreSQLClient::initialize(YAML::Node config) {
  host_ = config["host"].as<std::string>();
  port_ = config["port"].as<std::string>();
  user_name_ = config["user_name"].as<std::string>();
  passwd_ = config["passwd"].as<std::string>();
  db_name_ = config["db_name"].as<std::string>();
}

std::string PostgreSQLClient::cuckoo_conn(){
    return "user="+user_name_+" "+"password="+passwd_+" "+"host="+host_+" "+"dbname="+db_name_+" "+"port="+port_;
}

PGconn * PostgreSQLClient::create_connection(std::string db_name) {
  std::string conninfo = "hostaddr="+host_+ " " +"port="+port_+ " " +"connect_timeout=4"+ " " +"dbname=" + db_name;

  std::cerr << "Fuzz conn : " << conninfo << std::endl;
  PGconn *result = PQconnectdb(conninfo.c_str());
  if (PQstatus(result) == CONNECTION_BAD) {
    fprintf(stderr, "Error1: %s\n", PQerrorMessage(result));
    std::cerr << "BAd" << std::endl;
  }
  return result;
}

void PostgreSQLClient::install_extension(PGconn *conn){
  auto res = PQexec(conn, "CREATE EXTENSION cuckoo");
  std::cout << "Installed extension cuckoo" << std::endl;
  PQclear(res);
}

void PostgreSQLClient::prepare_env() {
  PGconn *conn = create_connection(db_name_);
  install_extension(conn);
  PQfinish(conn);
}

ExecutionStatus PostgreSQLClient::execute(const char *query, size_t size) {
  auto conn = create_connection(db_name_);

  if (PQstatus(conn) != CONNECTION_OK) {
    fprintf(stderr, "Error2: %s\n", PQerrorMessage(conn));
    PQfinish(conn);
    return kServerCrash;
  }

  std::string cmd(query, size);

  auto res = PQexec(conn, cmd.c_str());
  if (PQstatus(conn) != CONNECTION_OK) {
    fprintf(stderr, "Error3: %s\n", PQerrorMessage(conn));
    PQclear(res);
    return kServerCrash;
  }

  if (PQresultStatus(res) != PGRES_COMMAND_OK &&
      PQresultStatus(res) != PGRES_TUPLES_OK) {
    fprintf(stderr, "Error4: %s\n", PQerrorMessage(conn));
    PQclear(res);
    PQfinish(conn);
    return kExecuteError;
  }
  PQclear(res);
  PQfinish(conn);
  return kNormal;
}

void PostgreSQLClient::clean_up_env() {}

bool PostgreSQLClient::check_alive() {
  std::string conninfo = "hostaddr="+host_+ " " +"port="+port_+ " " +"connect_timeout=4";

  PGPing res = PQping(conninfo.c_str());
  return res == PQPING_OK;
}
}  // namespace client
