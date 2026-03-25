-- bigdata 

bq show bigquery-public-data:chicago_taxi_trips.taxi_trips
-- bq extract bigquery-public-data:chicago_taxi_trips.taxi_trips gs://pg14/taxi.csv.*

SELECT count(*)
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips`;

SELECT payment_type, round(sum(tips)/sum(trip_total)*100, 0) + 0 as tips_percent, count(*) as c
FROM `bigquery-public-data.chicago_taxi_trips.taxi_trips` 
group by payment_type
order by 3 desc;

-- mount to local dir
https://github.com/GoogleCloudPlatform/gcsfuse

-- installing
-- gcsfuse
-- https://github.com/GoogleCloudPlatform/gcsfuse/blob/master/docs/installing.md
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt update
sudo apt install gcsfuse -y

-- gsutil
-- https://docs.cloud.google.com/storage/docs/gsutil_install 
-- gsutil rsync -r taxi gs://chicago10
-- gsutil cp -r gs://chicago10 taxi


-- mount under postgres
sudo su postgres
cd $HOME
mkdir taxi
-- gcloud auth login
-- gcsfuse chicago10 taxi
gsutil cp -r gs://chicago10 taxi

ls -la

-- umount 
fusermount -u taxi

psql
CREATE DATABASE taxi;
\c taxi
CREATE TABLE taxi_trips(unique_key text
,taxi_id text
,trip_start_timestamp timestamp
,trip_end_timestamp timestamp
,trip_seconds bigint
,trip_miles float
,pickup_census_tract bigint
,dropoff_census_tract bigint
,pickup_community_area bigint
,dropoff_community_area bigint
,fare float
,tips float
,tolls float
,extras float
,trip_total float
,payment_type text
,company text
,pickup_latitude float
,pickup_longitude float
,pickup_location text
,dropoff_latitude float
,dropoff_longitude float
,dropoff_location text);

exit
cd /var/lib/postgresql/taxi
for f in *.csv*; do psql -d taxi -c "\\COPY taxi_trips FROM PROGRAM 'cat $f' CSV HEADER"; done

psql
\timing
\c taxi
SELECT count(*) FROM taxi_trips;

EXPLAIN SELECT payment_type, round(sum(tips)/sum(tips+fare)*100) tips_persent, count(*)
FROM taxi_trips
group by payment_type
order by 3 desc;

SELECT payment_type, round(sum(tips)/sum(tips+fare)*100) tips_persent, count(*)
FROM taxi_trips
group by payment_type
order by 3 desc;


CREATE INDEX idx_taxi2 on taxi_trips(payment_type) include (tips, fare);

VACUUM ANALYZE taxi_trips;