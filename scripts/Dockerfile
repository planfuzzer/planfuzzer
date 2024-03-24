from ubuntu:18.04
LABEL maintainer="planFuzzer"

RUN apt-get update
RUN sudo apt-get -y install make cmake build-essential vim git \
    clang ninja-build pkg-config clang-format libpq-dev llvm libyaml-cpp-dev \
     zlib1g-dev libreadline8 libreadline-dev python3-fire
    
RUN wget -qO- https://get.haskellstack.org/ | sh

RUN mkdir -p /home && \
    groupadd postgres && \
    useradd -l -K UMASK=0000 -d /home -g postgres postgres && \
    chown postgres:postgres /home

RUN	echo "postgres:postgres" | chpasswd && usermod -a -G sudo postgres
RUN chmod +w /etc/sudoers && \
    echo "%postgres   ALL=(ALL:ALL)NOPASSWD:ALL" >> /etc/sudoers && \
    chmod -w /etc/sudoers

USER postgres
WORKDIR /home

RUN wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.gz && tar -xf postgresql-10.23.tar.gz

RUN git clone https://github.com/planfuzzer/planfuzzer.git && \
    cd AFLplusplus/ && LLVM_CONFIG=llvm-config-14 make -j

# Build PostgreSQL
WORKDIR /home/postgresql-10.23/
RUN mkdir build/ && cd build/ && \
    CC=/home/planfuzzer/AFLplusplus/afl-cc CXX=/home/planfuzzer/AFLplusplus/afl-c++  ../configure && \
    make -j && sudo make install  

RUN sudo mkdir /usr/local/pgsql/data && sudo chown postgres /usr/local/pgsql/data &&  \
    AFL_IGNORE_PROBLEMS=1 /usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data

# Build lib for Pgcuckoo(Haskell)
WORKDIR /home/planfuzzer/pg_cuckoo/PgCuckoo
RUN stack instal ghcid && stack build 
RUN make -j

# Build extensions for postgresql
WORKDIR /home/planfuzzer/pg_cuckoo/PgExtension/src
RUN make && \
    sudo install -c -m 755 cuckoo.so '/usr/local/pgsql/lib/cuckoo.so' && \
    sudo install -c -m 644 .//cuckoo.control '/usr/local/pgsql/share/extension/' &&\
    sudo install -c -m 644 .//cuckoo--1.0.sql '/usr/local/pgsql/share/extension'

# Build lib for mutator
WORKDIR /home/planfuzzer/Grammar-Mutator
RUN make GRAMMAR_FILE=../src/grammar/plan.json

# Build driver for PostgreSQL
WORKDIR /home/planfuzzer
RUN mkdir build %% cd build && \
    cmake .. && make -j
    
# RUN    
RUN AFL_DEBUG=1 /usr/local/pgsql/bin/postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
RUN cd scripts && sh fuzz.sh
