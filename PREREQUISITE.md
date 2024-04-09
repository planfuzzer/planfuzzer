# Prerequisite
### 1) Libraries Install (Tested in Ubuntu18.04)
``` shell
sudo apt-get update
sudo apt install sudo gcc clang clang-format make cmake build-essential valgrind uuid-dev unzip autoconf autoconf-archive ninja-build clang pkg-config clang-format default-jre python3 libpq-dev libyaml-cpp-dev zlib1g-dev libreadline-dev llvm wget postgresql-server-dev-all
wget https://www.antlr.org/download/antlr-4.8-complete.jar
sudo cp -f antlr-4.8-complete.jar /usr/local/lib
# Haskell environment is required 
wget -qO- https://get.haskellstack.org/ | sh
```
### 2) Build AFLplusplus
``` shell
export PATH=/usr/lib/llvm-10/bin:$PATH
cd AFLplusplus
make all -j && sudo make install
```
### 3) Build Lib for Pgcuckoo
``` shell
# Haskell lib, will build in pg_cuckoo/PgCuckoo/.stack-work/.../build/
cd pg_cuckoo/PgCuckoo 
stack build

# C++ lib, will build in src/cuckoo/
make
````
* NOTE: you may need to modify `LIBPATH*` and `LIBS` in `pg_cuckoo/PgCuckoo/Makefile`