# Создание и восстановление резервной копии с помощью pg_probackup
-- 18 pg
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -q && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-18

pg_lsclusters

-- поставим pg_probackup
sudo apt install gpg wget
wget -qO - https://repo.postgrespro.ru/pg_probackup/keys/GPG-KEY-PG-PROBACKUP | sudo tee /etc/apt/trusted.gpg.d/pg_probackup.asc

. /etc/os-release
echo "deb [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb $VERSION_CODENAME main-$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/pg_probackup.list

echo "deb-src [arch=amd64] https://repo.postgrespro.ru/pg_probackup/deb $VERSION_CODENAME main-$VERSION_CODENAME" | sudo tee -a /etc/apt/sources.list.d/pg_probackup.list

sudo apt update && apt search pg_probackup

-- 18 поставим доп пакеты
sudo DEBIAN_FRONTEND=noninteractive apt install pg-probackup-18 pg-probackup-18-dbg postgresql-contrib postgresql-18-pg-checksums -y

-- Создаем каталог и устанавливаем переменную окружения BACKUP_PATH
sudo rm -rf /home/backups && sudo mkdir /home/backups && sudo chmod 777 /home/backups
sudo su postgres

echo "BACKUP_PATH=/home/backups/">>~/.bashrc
echo "export BACKUP_PATH">>~/.bashrc
cd $HOME
-- cd ~
. .bashrc

echo $BACKUP_PATH

-- Создадим роль в PostgreSQL для выполнения бекапов и дадим ему соответствующие права
-- права нужно будет выдавать в каждой БД!!!
-- https://postgrespro.github.io/pg_probackup/#pbk-install-and-setup
-- в 15+ версии
psql
BEGIN;
CREATE ROLE backup WITH LOGIN;
GRANT USAGE ON SCHEMA pg_catalog TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.current_setting(text) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.set_config(text, text, boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_is_in_recovery() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_start(text, boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_stop(boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_create_restore_point(text) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_switch_wal() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_last_wal_replay_lsn() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current_snapshot() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_snapshot_xmax(txid_snapshot) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_checkpoint() TO backup;
COMMIT;

ALTER ROLE backup WITH REPLICATION;

exit
-- Инициализируем наш бекап
pg_probackup-18 init


-- В нашей директории для бекапов появились следующие папки
cd $BACKUP_PATH
ls -l 

-- Инициализируем инстанс main
pg_probackup-18 add-instance --instance 'main' -D /var/lib/postgresql/15/main

-- Создадим новую базу данных
psql -c "CREATE DATABASE testb;"

-- Таблицу в этой базе данных и заполним ее тестовыми данными
psql testb -c "CREATE TABLE test(i int);"
psql testb -c "INSERT INTO test VALUES (10), (20), (30);"
psql testb -c "SELECT * FROM test;"

-- Создадим резервную копию.  Команда backup принимает три параметра:
    - `-b` - тип создания резервной копии. Для первого запуска нужно создать полную копию кластера PostgreSQL, поэтому команда `FULL`
    - параметр `-–stream` указывает на то, что нужно вместе с созданием резервной копии, параллельно передавать wal по слоту репликации. Запуск потоковой передачи wal.
    - параметр `--temp-slot` указывает на то, что потоковая передача wal-ов будет использовать временный слот репликации

-- зададим пароль backup
psql -c "ALTER USER backup PASSWORD 'testb123';"
pg_probackup-18  show
psql testb -c "insert into test values (4);"

pg_probackup-18 backup --instance 'main' -b DELTA --stream --temp-slot -h localhost -U backup -W


pg_probackup-18 backup --instance 'main' -b DELTA --stream --temp-slot -h localhost -U backup --pgdatabase=testb

-- nano /etc/postgresql/18/main/pg_hba.conf
-- host    testb   backup localhost scram-sha-256
-- psql -c "select pg_reload_conf()"
-- psql -c 'select * from pg_hba_file_rules'

-- обязательно выдать в нужной бд права на запуск функций!!
psql -d testb
BEGIN;
GRANT USAGE ON SCHEMA pg_catalog TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.current_setting(text) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.set_config(text, text, boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_is_in_recovery() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_start(text, boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_backup_stop(boolean) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_create_restore_point(text) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_switch_wal() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_last_wal_replay_lsn() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_current_snapshot() TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.txid_snapshot_xmax(txid_snapshot) TO backup;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_control_checkpoint() TO backup;
COMMIT;


pg_probackup-18 backup --instance 'main' -b DELTA --stream --temp-slot -h localhost -U backup --pgdatabase=testb
pg_probackup-18 show
pg_probackup-18 backup --instance 'main' -b DELTA --stream --temp-slot -h localhost -U backup -d testb -p 5432


-- Резервные копии успешно создались, но запрашивается пароль..

-- Note
-- If you are planning to rely on .pgpass for authentication when running backup in STREAM mode, 
-- then .pgpass must contain credentials for replication database, used to establish connection via replication protocol. 
-- Example: pghost:5432:replication:backup_user:my_strong_password 
-- nano ~/.pgpass
echo "localhost:5432:*:backup:test123">>~/.pgpass
chmod 600 ~/.pgpass

psql -U backup -h localhost -p 5432
psql -d testb -U backup -h localhost -p 5432
pg_probackup-18 backup --instance 'main' -b FULL --stream -d testb -U backup -h localhost -p 5432


pg_probackup-18 backup --instance 'main' -b FULL --stream -d testb -U backup -h localhost -p 5432

pg_probackup-18 show

-- создадим новый кластер
pg_createcluster 18 main2
rm -rf /var/lib/postgresql/18/main2

pg_probackup-18 restore --instance 'main' -i 'TCSYV4' -D /var/lib/postgresql/18/main2 
-- если не задали переменную окружения
-- -B /home/backups


pg_ctlcluster 18 main2 start

-- Проверяем, что данные восстановились
psql testb -p 5433 -c 'select * from test;'

-- дифференциальные бэкапы
-- PTRACK
-- https://github.com/postgrespro/ptrack


-- политика хранения резервных копии
pg_probackup-18 backup --instance 'main' -b FULL --stream
pg_probackup-18 show

-- хранение одной полной копии базы данных
-- pg_probackup-18 set-config --instance  'main' --retention-redundancy=1

-- pg_probackup-18 delete --instance  'main' --delete-expired --delete-wal
-- pg_probackup-18 show

-- старше 7 дней и не больше 2 полных копий
-- pg_probackup-18 delete --instance 'main' --delete-expired --retention-window=7 --retention-redundancy=2



-- дополнительное расширение amcheck
-- https://postgrespro.ru/docs/postgresql/14/amcheck
psql -d testb -c "CREATE EXTENSION amcheck"

-- Запускаем проверки целостности базы данных
pg_probackup-18 checkdb -D /var/lib/postgresql/15/main
psql -d testb -c "select * from test;"


-- настройки и скрипт бэкапа
-- посмотреть настройки
pg_probackup-18 show-config --instance main
-- https://habr.com/ru/company/barsgroup/blog/515592/


-- PITR
-- https://postgrespro.ru/docs/postgrespro/13/app-pgprobackup#PBK-PERFORMING-POINT-IN-TIME-PITR-RECOVERY

-- настроим непрерывное архивирование
-- https://postgrespro.ru/docs/postgrespro/13/app-pgprobackup#PBK-SETTING-UP-CONTINUOUS-WAL-ARCHIVING
-- https://habr.com/ru/company/barsgroup/blog/516088/
psql -c 'alter system set archive_mode = on'

-- изза кавычек не смог написать в 1 строку(
-- вручную каталог(
psql 
alter system set archive_command = 'pg_probackup-18 archive-push -B /home/backups/ --instance=main --wal-file-path=%p --wal-file-name=%f --compress';
exit
pg_ctlcluster 18 main stop && pg_ctlcluster 18 main start

psql -c 'show archive_mode'
psql -c 'show archive_command'

psql testb -c "insert into test values (5);"
pg_probackup-18 backup --instance 'main' -b FULL --stream --temp-slot -h localhost -U backup -d testb -p 5432

pg_probackup-18 show
psql testb -c "insert into test values (10);"
pg_probackup-18 backup --instance 'main' -b DELTA --stream --temp-slot -h localhost -U backup -d testb -p 5432

-- -i 'R2TH83' - !!! не указываем
pg_ctlcluster 18 main2 stop
rm -rf /var/lib/postgresql/18/main2

pg_probackup-18 restore --instance 'main' -D /var/lib/postgresql/15/main2 --recovery-target-time="2026-04-01 18:02:03+00"

pg_ctlcluster 18 main2 start

-- Проверяем, что данные восстановились без последних изменений
psql testb -p 5433 -c 'select * from test;'


cat /var/log/postgresql/postgresql-14-main2.log


!!!! --restore-as-replica
pg_probackup-18 restore --instance 'main' -D /var/lib/postgresql/18/main2 -B /home/backups --recovery-target-time="2026-04-01 11:38:03+00" --restore-as-replica


