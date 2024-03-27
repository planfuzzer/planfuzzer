from ubuntu:18.04
LABEL maintainer="planfuzzer"

RUN apt-get update
RUN sudo apt install gcc clang clang-format make cmake build-essential \
        autoconf autoconf-archive ninja-build clang pkg-config clang-format \
        libpq-dev libyaml-cpp-dev zlib1g-dev libreadline8 libreadline-dev \
        llvm python3-fire
    
RUN wget -qO- https://get.haskellstack.org/ | sh

RUN mkdir -p /home && \
    groupadd postgres && \
    useradd -l -K UMASK=0000 -d /home -g postgres postgres && \
    chown postgres:postgres /home

RUN	echo "postgres:postgres" | chpasswd && usermod -a -G sudo postgres
RUN chmod +w /etc/sudoers && \
    echo "%postgres   ALL=(ALL:ALL)NOPASSWD:ALL" >> /etc/sudoers && \
    chmod -w /etc/sudoers

COPY ./planfuzzer /home/planfuzzer

USER postgres

ENV PATH=/usr/lib/llvm-10/bin:/home/.local/bin/:$PATH

# Build lib for Pgcuckoo
WORKDIR /home/planfuzzer/pg_cuckoo/PgCuckoo
RUN stack build && make

RUN git clone https://github.com/planfuzzer/planfuzzer.git && \
    cd AFLplusplus/ && make -j && make install

# Build PostgreSQL
WORKDIR /home
RUN wget https://ftp.postgresql.org/pub/source/v10.23/postgresql-10.23.tar.gz && \
     tar -xf postgresql-10.23.tar.gz
WORKDIR /home/postgresql-10.23/
RUN CC=afl-clang-fast CXX=afl-clang-fast++ ./configure --prefix=$PWD/install && \
     make install -j

# DBMD Init
ENV PATH=/home/postgresql-10.23/install/bin:$PATH
WORKDIR /home/planfuzzer/pg_cuckoo/PgExtension/src 
RUN make && make install

WORKDIR /home/planfuzzer/postgresql-10.23/install
RUN AFL_IGNORE_PROBLEMS=1 bin/initdb -D data && bin/pg_ctl start -D data && \
    bin/createdb fuzz && bin/psql -d fuzz -c "CREATE EXTENSION cuckoo;"
RUN AFL_DEBUG=1 bin/postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
RUN python3 initDB.py

# Build Grammar
WORKDIR /home/planfuzzer/Grammar-Mutator
RUN make GRAMMAR_FILE=../src/grammar/postgresql.json

# Build planfuzzer
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/plan-fuzzer/pg_cuckoo/PgCuckoo/.stack-work/dist/x86_64-linux/Cabal-2.0.1.0/build/:/home/.stack/programs/x86_64-linux/ghc-8.2.2/lib/ghc-8.2.2/rts/:/home/plan-fuzzer/src/cuckoo/
WORKDIR /home/planfuzzer
RUN mkdir build && cd build && \
    cmake .. -DPOSTGRESQL && make -j
    
# RUN   
WORKDIR /home/planfuzzer/scripts 
RUN sh fuzz.sh
