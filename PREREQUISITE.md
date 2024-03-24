# Prerequisite
### 1) Libraries Install (Tested in Ubuntu18.04)
``` shell
sudo apt-get update
sudo apt install gcc make cmake build-essential autoconf autoconf-archive ninja-build clang pkg-config clang-format libpq-dev libyaml-cpp-dev
# Haskell environment is required 
wget -qO- https://get.haskellstack.org/ | sh
```
### 2) Build AFLplusplus
``` shell
cd AFLplusplus
make all -j && sudo make install
```
### 3) Build lib for Pgcuckoo
``` shell
# Haskell lib, will build in pg_cuckoo/PgCuckoo/.stack-work/.../build/
cd pg_cuckoo/PgCuckoo 
stack build

# C++ lib, will build in src/cuckoo/
make
````