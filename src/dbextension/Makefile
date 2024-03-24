MODULE_big = planfuzzer
EXTENSION = planfuzzer
DATA = planfuzzer--1.0.sql

#OBJS = $(patsubst %.c,%.o,$(wildcard *.c))
OBJS = planfuzzer.o
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

ifeq ($(PORTNAME), darwin)
override CFLAGS += -undefined dynamic_lookup
endif