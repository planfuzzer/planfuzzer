export AFL_CUSTOM_MUTATOR_LIBRARY="/home/planfuzzer/Grammar-Mutator/libgrammarmutator-postgres.so"
export AFL_CUSTOM_MUTATOR_ONLY=1
export AFL_DISABLE_TRIM=1
export AFL_FAST_CAL=1

export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_SKIP_CPUFREQ=1

screen -dmS log_0 -- ~/planfuzzer/AFLplusplus/afl-fuzz -m 2048 -i ../data/input -o ../data/output -t 600000 -- ../build/db_driver
