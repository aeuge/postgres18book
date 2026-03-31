sudo apt install -y pgtop
-- pgtop
-- 2 окно
sudo -u postgres psql
CREATE TABLE test(i int);
INSERT INTO test SELECT s.id FROM generate_series(1,1000000000) AS s(id);

-- 1 
sudo -u postgres pg_top

-- текст запроса Q #
-- план E
-- блокировки L


-- что подключено в текущую секунду
sudo -u postgres psql

-- во 2 запустим нагрузку

SELECT * FROM pg_stat_activity;

-- Получаем активные запросы длительностью более 5 секунд:
SELECT now() - query_start as "runtime", usename, datname, state, wait_event_type, wait_event, query 
FROM pg_stat_activity 
WHERE now() - query_start > '5 seconds'::interval and state='active' 
ORDER BY runtime DESC;

-- State = ‘idle’ тоже вызывают подозрения. Но хуже всего - idle in transaction!

-- Далее убиваем: для active
-- SELECT pg_cancel_backend(procpid);
-- для idle
-- SELECT pg_terminate_backend(procpid); 


-- ТОП по загрузке CPU:
SELECT pid, xact_start, now() - xact_start AS duration 
FROM pg_stat_activity 
WHERE state LIKE '%active%' 
ORDER BY duration DESC;

-- использование pg_stat_statements
CREATE EXTENSION pg_stat_statements;
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
exit
pg_ctlcluster 18 main restart
psql
show shared_preload_libraries;

SELECT * FROM  pg_stat_statements;

SELECT substring(query, 1, 50) AS short_query, round(total_exec_time::numeric, 2) AS total_time,
	calls, rows, round(total_exec_time::numeric / calls, 2) AS avg_time,
	round((100 * total_exec_time / sum(total_exec_time::numeric) OVER ())::numeric, 2) AS percentage_cpu
FROM pg_stat_statements
ORDER BY total_time DESC LIMIT 20;

-- ТОП по времени выполнения:
SELECT substring(query, 1, 50) AS short_query, round(total_exec_time::numeric, 2) AS total_time,
	calls, rows, round(total_exec_time::numeric / calls, 2) AS avg_time,
	round((100 * total_exec_time / sum(total_exec_time::numeric) OVER ())::numeric, 2) AS percentage_cpu
FROM pg_stat_statements
ORDER BY avg_time DESC LIMIT 20;

SELECT schemaname, relname, seq_scan, seq_tup_read, seq_tup_read / seq_scan AS avg, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC
LIMIT 25;


-- PMM
-- https://docs.percona.com/percona-monitoring-and-management/3/install-pmm/install-pmm-server/deployment-options/docker/index.html
sudo su
cd && wget https://www.percona.com/get/pmm
chmod +x pmm
./pmm

htop
-- под капотом клик + виктория метрикс)
-- Yandex browser not supported

sudo su postgres
pgbench -i -s 1000 postgres

pgbench -P 1 -c 10 -j 4 -T 10 postgres


exit
sudo docker exec -it pmm-server bash
psql -h localhost -U postgres
\du
SELECT * FROM information_schema.table_privileges WHERE grantee = 'postgres' LIMIT 10;

exit

cd ~ && wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
sudo dpkg -i percona-release_latest.generic_all.deb
-- !!!в 3.0 забыли про эту строчку и добавили только в 3.0.1 !!!
sudo percona-release enable pmm3-client release
sudo apt update && sudo apt install -y pmm-client


sudo pmm-admin --version

https://35.223.139.169/graph/login

-- https://docs.percona.com/percona-monitoring-and-management/3/install-pmm/install-pmm-client/index.html
sudo pmm-admin config --server-insecure-tls --server-url=https://admin:admin$123@127.0.0.1:443

sudo pmm-admin config --server-insecure-tls --server-url=https://admin:admin\$123@127.0.0.1:443

sudo -u postgres psql
CREATE USER pmm with password 'pmm123pmm';
GRANT pg_monitor to pmm;

-- Создадим расширение для мониторинга
-- pg_stat_statements - устарело
wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb && sudo dpkg -i ./percona-release_latest.generic_all.deb && sudo apt-get update
sudo percona-release setup ppg18
sudo apt install percona-pg-stat-monitor18
sudo -u postgres psql
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_monitor';
ALTER SYSTEM SET track_io_timing = on;

CREATE EXTENSION pg_stat_monitor;

sudo pg_ctlcluster 18 main restart

-- Putting database under monitoring
sudo pmm-admin add postgresql --username=pmm --password=pmm123pmm pgtest

sudo pmm-admin list

sudo pmm-admin remove postgresql pgtest
