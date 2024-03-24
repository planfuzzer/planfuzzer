# default install dir
# sudo install -c -m 755 cuckoo.so '/usr/local/pgsql/lib/cuckoo.so'
# sudo install -c -m 644 .//cuckoo.control '/usr/local/pgsql/share/extension/'
# sudo install -c -m 644 .//cuckoo--1.0.sql '/usr/local/pgsql/share/extension'

# customer build-clang install dir
# /usr/bin/install -c -m 755  cuckoo.so '/home/build-clang/install/lib/postgresql/cuckoo.so'
# /usr/bin/install -c -m 644 .//cuckoo.control '/home/build-clang/install/share/postgresql/extension/'
# /usr/bin/install -c -m 644 .//cuckoo--1.0.sql  '/home/build-clang/install/share/postgresql/extension/'

# customer build-cov install dir
/usr/bin/install -c -m 755  cuckoo.so '/home/build-cov/install/lib/postgresql/cuckoo.so'
/usr/bin/install -c -m 644 .//cuckoo.control '/home/build-cov/install/share/postgresql/extension/'
/usr/bin/install -c -m 644 .//cuckoo--1.0.sql  '/home/build-cov/install/share/postgresql/extension/'

