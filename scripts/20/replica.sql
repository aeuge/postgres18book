#replica
pg_lsclusters

-- stop and delete 2 clusters
sudo pg_ctlcluster 18 main stop
sudo pg_dropcluster 18 main
sudo pg_ctlcluster 18 main2 stop
sudo pg_dropcluster 18 main2

-- create new 2 clusters
sudo pg_createcluster -d /var/lib/postgresql/18/main 18 main
sudo pg_createcluster -d /var/lib/postgresql/18/main2 18 main2


pg_lsclusters

sudo pg_ctlcluster 18 main start

-- delete files from 2
sudo rm -rf /var/lib/postgresql/18/main2

-- Let's make a backup of our database. The -R switch will create a stub control file recovery.conf.
sudo -u postgres pg_basebackup -p 5432 -R -D /var/lib/postgresql/18/main2

-- Add hot spare parameter
echo 'hot_standby = on' >> sudo tee /var/lib/postgresql/18/main2/postgresql.auto.conf

sudo pg_ctlcluster 18 main2 start

pg_lsclusters

-- create a database on the master and see what happened on the replica
sudo -u postgres psql -c 'CREATE DATABASE replica;'

sudo -u postgres psql -p 5433 -c '\l replica';


-- Checking the status of replication
sudo su postgres 
psql 
SELECT * FROM pg_stat_replication\gx

-- Let's look at the replica processes
exit
ps -o pid,command --ppid `head -n 1 /var/lib/postgresql/18/main2/postmaster.pid`
 
-- master process
ps -o pid,command --ppid `head -n 1 /var/lib/postgresql/18/main/postmaster.pid`

-- put the replica in the master state
pg_ctlcluster 18 main2 promote



pg_lsclusters

-- on 1 && 2 server
sudo pg_ctlcluster 18 main stop
sudo mkdir /archive
sudo chown -R postgres:postgres /archive
sudo su postgres
ip a
echo "listen_addresses = '10.128.15.209'" >> /etc/postgresql/18/main/postgresql.conf
echo "wal_log_hints = on" >> /etc/postgresql/18/main/postgresql.conf

echo "archive_mode = on" >>  /etc/postgresql/18/main/postgresql.conf
echo "archive_command = 'test ! -f /archive/%f && cp %p /archive/%f'" >>  /etc/postgresql/18/main/postgresql.conf

echo "host replication replica 10.128.15.0/24 md5" >> /etc/postgresql/18/main/pg_hba.conf
echo "host all rewind 10.128.15.0/24 md5" >> /etc/postgresql/18/main/pg_hba.conf


-- 1 server
cd $HOME
pg_ctlcluster 18 main start

-- create replica and rewind users with password test123

psql -c "CREATE USER replica WITH REPLICATION encrypted password 'test123'"
psql -c "CREATE USER rewind SUPERUSER encrypted PASSWORD 'test123'"

-- create sample database and fill it 

psql -c "create database sample"
pgbench -i -s 10 sample

-- on 2 server
-- cleanup data directory
rm -rf /var/lib/postgresql/18/main


-- notes:
--  it will ask for 123 password of replica user created earlier
--  it might take some time to backup restore 500mb of data
--  if it wait for a checkpoint before starting, so run on a master
psql -c "checkpoint" 

-- make sure that connection info is saved
cat /var/lib/postgresql/18/main/postgresql.auto.conf

-- and that you have standby.signal file in place (existence of this file will force postgres to run as slave)
ls -la /var/lib/postgresql/18/main/ | grep standby

-- start postgres
pg_ctlcluster 18 main start

-- and make sure it is up and running - see online,recovery
pg_lsclusters

-- on 1 server
psql -c "select * from pg_stat_replication"
psql -c "select * from pg_replication_slots"

-- lets create table and fill it with some dummy data

-- psql sample -c "drop table messages"
psql sample -c "create table messages(m text)"
psql sample -c "insert into messages values('hello')"
psql sample -c "select * from messages"

-- almost immediatelly you should see that table and message on a replica
-- Failover
-- on a second container
-- lets pretend that we lose our master - promote second container as a new master

pg_ctlcluster 18 main promote

-- standby file should be removed automatically
ls -la /var/lib/postgresql/18/main/ | grep standby

-- Connection info in postgres.auto.conf will left inact, but it is ok, until there is no standby file
cat /var/lib/postgresql/18/main/postgresql.auto.conf

pg_lsclusters

-- write records now to 2 server
psql sample -c "insert into messages values('world')"
psql sample -c "select * from messages"

-- on 1

psql sample -c "insert into messages values('russia')"
psql sample -c "select * from messages"

-- has splitbrain

-- 1 stop postgres 
pg_ctlcluster 18 main stop

-- rewind
/usr/lib/postgresql/18/bin/pg_rewind --target-pgdata /var/lib/postgresql/18/main --source-server="postgresql://rewind:test123@postres2:5432/sample" --progress

ping postgres2

/usr/lib/postgresql/18/bin/pg_rewind --target-pgdata /var/lib/postgresql/18/main --source-server="postgresql://rewind:test123@10.128.15.210:5432/sample" --progress

-- if error
rewind might complain with error like: pg_rewind: error: could not open file "/var/lib/postgresql/12/main/pg_wal/00000001000000000000000A": No such file or directory you gonna need to copy this file from /archive to pg_wal, e.g.:

ls -la /archive/
cp /archive/00000001000000000000000A /var/lib/postgresql/18/main/pg_wal/
-- chown postgres:postgres /var/lib/postgresql/18/main/pg_wal/00000001000000000000000A

/usr/lib/postgresql/18/bin/pg_rewind --target-pgdata /var/lib/postgresql/18/main --source-server="postgresql://rewind:test123@10.128.15.210:5432/sample" --progress
-- now, when we rewinded lets make it slave


-- create standy signal
touch /var/lib/postgresql/18/main/standby.signal

-- and add replication info
echo "primary_conninfo = 'user=replica password=test123 host=10.128.15.210 port=5432 sslmode=prefer sslcompression=0 gssencmode=prefer krbsrvname=postgres target_session_attrs=any'" >> /var/lib/postgresql/18/main/postgresql.auto.conf
-- adding another relication slot
echo "primary_slot_name = 'replica2'" >> /var/lib/postgresql/18/main/postgresql.auto.conf

-- create slot on new master

psql -c "select * from pg_create_physical_replication_slot('replica2')"
psql -c "select * from pg_replication_slots"

-- start postgres
pg_ctlcluster 18 main start

pg_lsclusters

-- check that data is synced
psql sample -c "select * from messages"


pg_ctlcluster 18 main promote
gcloud compute instances delete postgres2




-- Логическая репликация
sudo -u postgres psql -c 'ALTER SYSTEM SET wal_level = logical;'

sudo pg_ctlcluster 18 main restart

-- Change the password to the user postgres
sudo -u postgres psql -c "ALTER USER postgres WITH password 'Postgres123#';"

-- Create a publication on the first server
sudo -u postgres psql -c "CREATE DATABASE replica;";
sudo -u postgres psql replica -c "CREATE TABLE test(i int);"
sudo -u postgres psql replica -c "CREATE PUBLICATION test_pub FOR TABLE test;"
sudo -u postgres psql replica -c "\dRp+"


-- create a subscription on the second server
sudo -u postgres psql replica -p 5433 -c 'CREATE TABLE test(i int);'

sudo -u postgres psql replica -p 5433 -c "CREATE SUBSCRIPTION test_sub 
CONNECTION 'host=localhost port=5432 user=postgres password=Postgres123# dbname=replica' 
PUBLICATION test_pub WITH (copy_data = false);"

-- on 1
sudo -u postgres psql -c "show listen_addresses;"

sudo -u postgres psql -c "ALTER SYSTEM SET listen_addresses = '10.128.15.209, 127.0.0.1';"
sudo -u postgres psql -c "SELECT pg_reload_conf();"

sudo pg_ctlcluster 18 main restart

sudo -u postgres psql -c "show listen_addresses;"

-- on 2
sudo -u postgres psql replica -p 5433 -c "CREATE SUBSCRIPTION test_sub 
CONNECTION 'host=localhost port=5432 user=postgres password=Postgres123# dbname=replica' 
PUBLICATION test_pub WITH (copy_data = false);"

sudo -u postgres psql replica -p 5433 -c "\dRs";

-- Let's look at the status of the subscription
sudo -u postgres psql replica -p 5433 -c "SELECT * FROM pg_stat_subscription";

-- add the same data
-- on subscriber
sudo -u postgres psql replica -p 5433 -c "INSERT INTO test VALUES(1);"

-- on the publishing server
sudo -u postgres psql replica -c "INSERT INTO test VALUES(1);"

-- on subscriber
sudo -u postgres psql replica -p 5433 -c "SELECT * FROM test;"

-- clear the table and add an index on subscriber
sudo -u postgres psql replica -p 5433 -c "TRUNCATE test;"
sudo -u postgres psql replica -p 5433 -c "CREATE UNIQUE INDEX ON test (i);"
sudo -u postgres psql replica -p 5433 -c "\dS+ test"

-- check the same data after creating the index
-- on subscriber
sudo -u postgres psql replica -p 5433 -c "INSERT INTO test VALUES(2);"

-- on the publishing server
sudo -u postgres psql replica -c "INSERT INTO test VALUES(2);"

-- on subscriber
sudo -u postgres psql replica -p 5433 -c "SELECT * FROM test;"

-- Let's look at the status of the subscription
sudo -u postgres psql replica -p 5433 -c "SELECT * FROM pg_stat_subscription;"

-- we will also see the problem in the logs
sudo tail /var/log/postgresql/postgresql-14-main2.log

-- delete the conflicting entry on the subscriber
sudo -u postgres psql replica -p 5433 -c "DELETE FROM test WHERE i = 2;"

-- Let's look at the status of the subscription:
sudo -u postgres psql replica -p 5433 -c "SELECT * FROM pg_stat_subscription;"

-- to delete a post and a subscription
DROP PUBLICATION test_pub;
DROP SUBSCRIPTION test_sub;

