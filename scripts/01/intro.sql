sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y && sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt -y install postgresql-18

sudo su postgres
-- для открытия доступа извне
-- Первое — задайте пароль пользователю СУБД postgres через утилиту psql:
ALTER USER postgres PASSWORD ‘Postgres123#’;
-- или используя встроенную команду psql:
\password

--Второе — включите listener (процесс, слушающий подключения на сетевом интерфейсе) в postgresql.conf, раскомментируйте соответствующую строчку, убрав символ # в текстовом редакторе nano:
sudo nano /etc/postgresql/18/main/postgresql.conf
listen_addresses = ‘‘ # IP адреса, на которых PostgreSQL принимает сетевые подключения, например, localhost, 10...

--Третье — укажите вход по паролю в pg_hba.conf и измените маску подсети, откуда будет разрешён доступ к нашему кластеру.
sudo nano /etc/postgresql/15/main/pg_hba.conf
host all all 0.0.0.0/0 scram-sha-256

--После этого перезагрузите кластер PostgreSQL и получите доступ извне:
pg_ctlcluster 18 main stop && pg_ctlcluster 18 main start

-- загрузим тайские перевозки
cd ~ && wget https://storage.googleapis.com/thaibus/thai_small.tar.gz && tar -xf thai_small.tar.gz && psql < thai.sql

psql -d thai

\l+