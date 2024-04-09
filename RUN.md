# Run Fuzzing
## Configuration
* You can specify detailed configuration
* Default configuration yaml file is under `root` directory
  
| **Config attribute** | **Description**               |
|----------------------|-------------------------------|
| db                   | target DBMS name              |
| db_name              | database name                 |
| user_name            | DBMS user                     |
| passwd               | DBMS password                 |
| port                 | DBMS connection port          |
| sqlsmith             | sqlsmith executable file path |
| output               | saved query plan              |
| capacity             | query plan pool capacity      |
| startup_cmd          | DBMS startup command          |

_____

## Plan Seed Construction
``` shell
cd planfuzzer/src
python3 preprocess.py
```
____
## PostgreSQL Fuzzing
### 1) DBMS Install
```
wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.gz
cd postgresql-10.23
CC=afl-clang-fast CXX=afl-clang-fast++ ./configure --prefix=$PWD/install
make -j && make install
```
### 2) DBMS Init
``` shell
# Build Extension
export PATH=~/postgresql-10.23/install/bin:$PATH
cd planfuzzer/pg_cuckoo/PgExtension/src
make && make install
# Init database
AFL_IGNORE_PROBLEMS=1 initdb -D data
pg_ctl start -D data
AFL_DEBUG=1 postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
createdb fuzz && psql -d fuzz -c "CREATE EXTENSION cuckoo;"
pg_restore -d fuzz planfuzzer/data/fuzz.dump
```
### 3) Build Grammar
``` shell
cd planfuzzer/Grammar-Mutator
make GRAMMAR_FILE=../src/grammar/postgresql.json
```
### 4) Fuzzing!
``` shell
mkdir build && cd build
cmake .. && make -j
sh srcipts/fuzz.sh
```
* NOTE: you may need to modify `fuzz.sh`
___________
## TimescaleDB
### 1) DBMS Install
``` shell
export CC=afl-clang-fast
export CXX=afl-clang-fast++
wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.gz
cd postgresql-10.23
./configure --prefix=$PWD/install
make -j && make install
export PATH=~/postgres-10.23/install/bin:$PATH
git clone https://github.com/timescale/timescaledb
cd timescaledb && git checkout 1.7.0
./bootstrap -DREGRESS_CHECKS=OFF
cd build && make install
```
### 2) DBMS Init
``` shell
# Build Extension
export PATH=~/postgres-10.23/install/bin:$PATH
cd planfuzzer/pg_cuckoo/PgExtension/src
make && make install
# Init database
cd postgresql-10.23/install 
AFL_IGNORE_PROBLEMS=1 initdb -D data
pg_ctl start -D data
AFL_DEBUG=1 postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
createdb fuzz && psql -d fuzz -c "CREATE EXTENSION cuckoo; CREATE EXTENSION timescaledb;"
pg_restore -d fuzz planfuzzer/data/fuzz.dump
```
### 3) Build Grammar
``` shell
cd planfuzzer/Grammar-Mutator
make GRAMMAR_FILE=../src/grammar/timescaledb.json
```
### 4) Fuzzing!
``` shell
mkdir build && cd build
cmake .. && make -j
sh srcipts/fuzz.sh
```
* NOTE: you may need to modify `fuzz.sh`
____________
## PostGIS
### 1) DBMS Install
``` shell
export CC=afl-clang-fast
export CXX=afl-clang-fast++
wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.gz
cd postgresql-10.23
./configure --prefix=$PWD/install
make -j && make install
export PATH=~/postgresql-10.23/install/bin:$PATH
git clone https://github.com/postgis/postgis
cd postgis && git checkout 3.2.6
sh autogen.sh
./configure
make && make install
```
### 2) DBMS Init
``` shell
# Build Extension
export PATH=~/postgresql-10.23/install/bin:$PATH
cd planfuzzer/pg_cuckoo/PgExtension/src
make && make install
# Init database
cd postgresql-10.23/install 
AFL_IGNORE_PROBLEMS=1 initdb -D data
pg_ctl start -D data
AFL_DEBUG=1 postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
createdb fuzz && psql -d fuzz -c "CREATE EXTENSION cuckoo; CREATE EXTENSION postgis;"
pg_restore -d fuzz planfuzzer/data/fuzz.dump
```
### 3) Build Grammar
``` shell
cd planfuzzer/Grammar-Mutator
make GRAMMAR_FILE=../src/grammar/postgis.json
```
### 4) Fuzzing!
``` shell
mkdir build && cd build
cmake .. && make -j
sh srcipts/fuzz.sh
```
* NOTE: you may need to modify `fuzz.sh`
_________________

## AgensGraph
### 1) DBMS Install
``` shell
export CC=afl-clang-fast
export CXX=afl-clang-fast++
git clone https://github.com/bitnine-oss/agensgraph
cd agensgraph && git checkout 2.1.3
./configure --prefix=$PWD/install
make -j && make install
```
### 2) DBMS Init
``` shell
# Build Extension
export PATH=~/agensgraph/install/bin:$PATH
cd planfuzzer/pg_cuckoo/PgExtension/src
make && make install
# Init database
AFL_IGNORE_PROBLEMS=1 initdb -D data
pg_ctl start -D data
AFL_DEBUG=1 postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
createdb fuzz && psql -d fuzz -c "CREATE EXTENSION cuckoo;"
pg_restore -d fuzz planfuzzer/data/fuzz.dump
```
### 3) Build Grammar
``` shell
cd planfuzzer/Grammar-Mutator
make GRAMMAR_FILE=../src/grammar/agensgraph.json
```
### 4) Fuzzing!
``` shell
mkdir build && cd build
cmake .. && make -j
sh srcipts/fuzz.sh
```
* NOTE: you may need to modify `fuzz.sh`