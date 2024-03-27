GHC = stack ghc -- 
GHCFLAGS =  -dynamic -fPIC -O3
LDFLAGS = -dynamic -shared -fPIC
GCC = g++
CXXFLAGS = -shared -fPIC -O3
# LIBS = -lstdc++ -latomic -lHSrts-ghc8.2.2 -lHSPgCuckoo-0.1.0.0-9z3z4baR2vL8qx7FErfjhJ-ghc8.2.2
LIBS = -lstdc++ -latomic -lHSrts-ghc8.2.2 -lHSPgCuckoo-0.1.0.0-IxcU4xKSfURB1yERMS0uc2-ghc8.2.2  

# docker
GHC_INCLUDE = /home/.stack/programs/x86_64-linux/ghc-8.2.2/lib/ghc-8.2.2/include
LIBPATH_HS = -L/home/planfuzzer/pg_cuckoo/PgCuckoo/.stack-work/dist/x86_64-linux/Cabal-2.0.1.0/build/
LIBPATH_RTS = -L/home/.stack/programs/x86_64-linux/ghc-8.2.2/lib/ghc-8.2.2/rts/
LIBPATH_PG = -L/home/planfuzzer/src/cuckoo/

all: libpgcuckoo.so  

cuckoo.o: app/cuckoo.hs
	$(GHC) $(GHCFLAGS) -c $< -o ../../src/cuckoo/cuckoo.o

cuckoo-c.o: ../../src/cuckoo/cuckoo_c.cpp
	$(GCC) $(CXXFLAGS) -c $< -I $(GHC_INCLUDE) -o ../../src/cuckoo/cuckoo_c.o

libpgcuckoo.so: cuckoo-c.o cuckoo.o 
	$(GHC) $(LDFLAGS) ../../src/cuckoo/cuckoo.o  ../../src/cuckoo/cuckoo_c.o -o ../../src/cuckoo/libpgcuckoo.so $(LIBPATH_HS) $(LIBPATH_RTS) $(LIBS) 

test: ../../src/test.cpp
	$(GCC) $< $(LIBPATH_PG) -lpgcuckoo -o ../../src/test

.PHONY: test

clean:
	rm -rf app/cuckoo.hi app/cuckoo_stub.h ../../src/cuckoo/cuckoo.o ../../src/cuckoo/cuckoo_c.o ../../src/cuckoo/libpgcuckoo.so  ../../src/test

