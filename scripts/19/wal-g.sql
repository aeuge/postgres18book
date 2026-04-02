-- wal-g v3.0.8
-- https://github.com/wal-g/wal-g
sudo pg_lsclusters
sudo pg_dropcluster 18 main2 --stop

wget https://github.com/wal-g/wal-g/releases/download/v3.0.8/wal-g-pg-24.04-amd64.tar.gz && tar -zxvf wal-g-pg-24.04-amd64.tar.gz && sudo mv wal-g-pg-24.04-amd64 /usr/local/bin/wal-g

sudo ls -l /usr/local/bin/wal-g

sudo rm -rf /home/backups && sudo mkdir /home/backups && sudo chmod 777 /home/backups

-- Создаем файл конфигурации для wal-g
sudo su postgres
nano ~/.walg.json

-- https://github.com/wal-g/wal-g/blob/master/docs/PostgreSQL.md
-- https://github.com/wal-g/wal-g/blob/master/docs/STORAGES.md
-- в 3- версии параметр другой     "PGHOST": "/var/run/postgresql/.s.PGSQL.5432"
{
    "WALG_FILE_PREFIX": "/home/backups",
    "WALG_COMPRESSION_METHOD": "brotli",
    "WALG_DELTA_MAX_STEPS": "5",
    "PGDATA": "/var/lib/postgresql/18/main",
    "PGHOST": "/var/run/postgresql"
}

-- опция для дебага
--     "WALG_LOG_LEVEL": "DEVEL"

mkdir /var/lib/postgresql/18/main/log

-- postgresql.con
echo "wal_level=replica" >> /var/lib/postgresql/18/main/postgresql.auto.conf
echo "archive_mode=on" >> /var/lib/postgresql/18/main/postgresql.auto.conf
echo "archive_command='wal-g wal-push \"%p\" >> /var/lib/postgresql/18/main/log/archive_command.log 2>&1' " >> /var/lib/postgresql/18/main/postgresql.auto.conf 
echo "archive_timeout=60" >> /var/lib/postgresql/18/main/postgresql.auto.conf 
echo "restore_command='wal-g wal-fetch \"%f\" \"%p\" >> /var/lib/postgresql/18/main/log/restore_command.log 2>&1' " >> /var/lib/postgresql/18/main/postgresql.auto.conf

cat ~/18/main/postgresql.auto.conf

-- Перезапускаем кластер PostgreSQL
pg_ctlcluster 18 main stop && pg_ctlcluster 18 main start
cd /home/backups

-- Создадим новую базу данных
psql -c "CREATE DATABASE testw;"

-- Таблицу в этой базе данных и заполним ее тестовыми данными
psql testw -c "create table test(i int);"
psql testw -c "insert into test values (10), (20), (30);"
psql testw -c "select * from test;"

-- бэкап
wal-g backup-push /var/lib/postgresql/18/main 

cat /var/log/postgresql/postgresql-18-main.log
cat /var/lib/postgresql/18/main/log/archive_command.log

PGUSER=backup wal-g backup-push /var/lib/postgresql/18/main
PGDATABASE=postgres PGUSER=backup wal-g backup-push /var/lib/postgresql/18/main

-- show hba_file;
-- nano /etc/postgresql/18/main/pg_hba.conf



wal-g backup-list

psql testw -c "UPDATE test SET i = 3 WHERE i = 30"

-- make delta
wal-g backup-push /var/lib/postgresql/18/main

wal-g backup-list

cd /home/backups
tree

-- restore 
pg_createcluster 18 main2
rm -rf /var/lib/postgresql/18/main2

wal-g backup-fetch /var/lib/postgresql/18/main2 LATEST


-- сделаем файл для восстановления из архивов wal
touch "/var/lib/postgresql/18/main2/recovery.signal"

pg_ctlcluster 18 main2 start

psql -p 5433 testw -c "select * from test;"

ls -la /home/backups/wal_005


-- Настроим на Gstore
rm $HOME/.walg.json
nano ~/.walg.json
{
    "WALG_GS_PREFIX": "gs://walgg",
    "GOOGLE_APPLICATION_CREDENTIALS" : "/var/lib/postgresql/celtic-house-266612-65d95e64c26a.json",
    "WALG_COMPRESSION_METHOD": "brotli",
    "WALG_DELTA_MAX_STEPS": "5",
    "PGDATA": "/var/lib/postgresql/18/main",
    "PGHOST": "/var/run/postgresql"
}

gcloud compute instances list

scp /mnt/d/download/celtic-house-266612-65d95e64c26a.json aeugene@34.136.57.48:/home/aeugene/
cp /home/aeugene/celtic-house-266612-65d95e64c26a.json /var/lib/postgresql/celtic-house-266612-65d95e64c26a.json
chown postgres:postgres /var/lib/postgresql/celtic-house-266612-65d95e64c26a.json

wal-g backup-push /var/lib/postgresql/18/main

wal-g backup-list

-- восстановимся
pg_ctlcluster 18 main2 stop

rm -rf /var/lib/postgresql/18/main2

wal-g backup-fetch /var/lib/postgresql/18/main2 LATEST

touch "/var/lib/postgresql/18/main2/recovery.signal"


pg_ctlcluster 18 main2 start

