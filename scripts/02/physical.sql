-- physycal architecture
pg_lsclusters

-- add another cluster
pg_createcluster 18 main2
sudo pg_createcluster 18 main2
sudo nano /etc/postgresql/18/main/postgresql.conf

sudo su postgres
cd /var/lib/postgresql/18/main
ls -la
ls -l base
# - command in psql
# SELECT oid, datname,dattablespace FROM pg_database;
# CREATE DATABASE book;
# SELECT * FROM pg_tablespace;

-- make a catalog for new tablespace
exit
sudo mkdir /home/postgres
sudo chown postgres /home/postgres
sudo su postgres
cd /home/postgres
mkdir tmptblspc

psql
# CREATE tablespace ts location '/home/postgres/tmptblspc';
-- list of tablespaces
# \db
# CREATE DATABASE app TABLESPACE ts;
# \c app
-- look for default tablespace
# \l+ 

exit
cd tmptblspc/
ls
cd PG_18_202506291/
ls -la
psql -c "SELECT oid, datname, dattablespace FROM pg_database;"

cd 16519
ls -la

psql
# \c app
# CREATE TABLE test (i int);
# CREATE TABLE test2 (i int) TABLESPACE pg_default;
# SELECT tablename, tablespace FROM pg_tables WHERE schemaname = 'public';
-- change tablespace for TABLE
# ALTER TABLE test SET TABLESPACE pg_default;
# SELECT oid, spcname FROM pg_tablespace; -- oid унимальный номер, по кторому можем найти файлы
# SELECT oid, datname,dattablespace FROM pg_database;
-- where is table
# SELECT pg_relation_filepath('test2');

# SELECT OID, relname, relnamespace FROM pg_class WHERE OID=24579;

# \! ls -la /var/lib/postgresql/18/main/pg_tblspc
# \! ls -la /var/lib/postgresql/18/main/pg_tblspc/16517/PG_18_202506291/16519/ | grep 24579
# ALTER TABLE test2 SET tablespace ts;
# SELECT pg_relation_filepath('test2');
# \! ls -la /var/lib/postgresql/18/main/pg_tblspc/16517/PG_18_202506291/16519/ | grep 24583

# INSERT INTO test2 VALUES ('1');



-- SHOW size of database
# SELECT pg_database_size('app');

-- pretty size
# SELECT pg_size_pretty(pg_database_size('app'));

-- full size of TABLE
# SELECT pg_size_pretty(pg_total_relation_size('test2'));

-- only size of data
# SELECT pg_size_pretty(pg_TABLE_size('test2'));

-- ... only indexes
# SELECT pg_size_pretty(pg_indexes_size('test2'));

-- size of visability map fro TABLE test2
# SELECT pg_size_pretty(pg_relation_size('test2','vm'));

-- size of tablespace
# SELECT pg_size_pretty(pg_tablespace_size('ts'));

-- try broke ts
exit
cd /home/postgres
mkdir tmptblspc2
psql -d app
# CREATE tablespace ts2 location '/home/postgres/tmptblspc2';

# ALTER TABLE test2 SET TABLESPACE ts2;

-- drop directory with new ts
exit
rm -rf tmptblspc2
psql -d app
\dt
SELECT * FROM test2;

exit
rm -rf tmptblspc
psql
\c app

DROP DATABASE app;

DROP TABLESPACE ts;
DROP TABLESPACE ts2;




-- pg_updatecluster
sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-17

pg_lsclusters

pg_createcluster 17 main

pg_upgradecluster 17 main

help pg_upgradecluster

sudo pg_upgradecluster 17 main upgrade17

sudo pg_renamecluster 17 main main17

pg_lsclusters

sudo pg_upgradecluster 17 main17

pg_lsclusters

sudo pg_dropcluster 17 main17

pg_upgradecluster --link --method=upgrade 17 main

sudo pg_ctlcluster 18 main17 stop
sudo pg_dropcluster 18 main17

sudo pg_dropcluster 18 main17 --stop