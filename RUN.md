# Run Fuzzing
## PostgreSQL Fuzzing
### 1) DBMS Install
```
wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.gz
cd postgresql-10.23
CC=afl-clang-fast CXX=afl-clang-fast++ ../configure --prefix=$PWD/install
make -j && make install
```
### 2) Build Extension
``` shell
cd pg_cuckoo/PgExtension/src
make
```
### 3) DBMS Init
``` shell
cd postgresql-10.23/install && mkdir data
AFL_IGNORE_PROBLEMS=1 bin/initdb -D data
pg_ctl start -D data
bin/createdb fuzz && bin/psql -d fuzz -c "CREATE EXTENSION cuckoo;"
python3 initDB.py
```
### 4) Build Grammar
``` shell
cd Grammar-Mutator
make GRAMMAR_FILE=../src/grammar/postgresql.json
```
### 5) Build Driver
``` shell
mkdir build && cd build
cmake .. && make -j
```
### 6) Fuzzing!
``` shell
sh srcipts/fuzz.sh
```