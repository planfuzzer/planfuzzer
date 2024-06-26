from ubuntu:18.04
LABEL maintainer="planfuzzer"

RUN apt-get update
RUN apt-get install sudo gcc clang clang-format make cmake build-essential valgrind uuid-dev unzip \
        autoconf autoconf-archive ninja-build clang pkg-config clang-format default-jre python3 \
        libpq-dev libyaml-cpp-dev zlib1g-dev libreadline-dev llvm wget postgresql-server-dev-all

RUN mkdir -p /home && \
    groupadd postgres && \
    useradd -l -K UMASK=0000 -d /home -g postgres postgres && \
    chown postgres:postgres /home

RUN	echo "postgres:postgres" | chpasswd && usermod -a -G sudo postgres
RUN chmod +w /etc/sudoers && \
    echo "%postgres   ALL=(ALL:ALL)NOPASSWD:ALL" >> /etc/sudoers && \
    chmod -w /etc/sudoers

COPY . /home/planfuzzer

USER postgres
WORKDIR /home

RUN wget https://www.antlr.org/download/antlr-4.8-complete.jar
RUN sudo cp -f antlr-4.8-complete.jar /usr/local/lib
RUN wget -qO- https://get.haskellstack.org/ | sh

ENV PATH=/usr/lib/llvm-10/bin:/home/.local/bin/:$PATH

RUN git clone https://github.com/planfuzzer/planfuzzer.git && \
    cd planfuzzer/AFLplusplus/ && sudo make install -j

# Build lib for Pgcuckoo
WORKDIR /home/planfuzzer/pg_cuckoo/PgCuckoo
RUN stack build && make

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
RUN make CC=gcc CXX=g++ && make install

WORKDIR /home/planfuzzer/postgresql-10.23/install
RUN AFL_IGNORE_PROBLEMS=1 initdb -D data && pg_ctl start -D data && \
    createdb fuzz && psql -d fuzz -c "CREATE EXTENSION cuckoo;"
RUN AFL_DEBUG=1 postgres 2>&1 | grep "__afl_map_size" | tail -n 1 | cut -d"," -f8 | cut -d" " -f 3 > /tmp/mapsize
RUN pg_restore -d fuzz /home/planfuzzer/data/fuzz.dump

# Build Grammar
WORKDIR /home/planfuzzer/Grammar-Mutator
RUN make GRAMMAR_FILE=../src/grammar/postgresql.json -j

# Build planfuzzer
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/planfuzzer/pg_cuckoo/PgCuckoo/.stack-work/dist/x86_64-linux/ghc-8.2.2/build/:/home/.stack/programs/x86_64-linux/ghc-8.2.2/lib/ghc-8.2.2/rts/:/home/planfuzzer/src/cuckoo/  
WORKDIR /home/planfuzzer
RUN mkdir build && cd build && \
    cmake .. && make -j
    
# RUN   
WORKDIR /home/planfuzzer/scripts 
RUN sh fuzz.sh
