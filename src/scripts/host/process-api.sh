#!/bin/bash
ACTION=${1}
# check if running init
if [[ "${ACTION}" == "init" ]]; then
    # create user 
    sudo -u postgres psql -c "CREATE USER kong"
    # create database 
    sudo -u postgres psql -c "CREATE DATABASE kong"
    # set owner 
    sudo -u postgres psql -c "ALTER DATABASE kong OWNER TO kong"
    # set password for kong user
    sudo -u postgres psql -c "ALTER USER kong WITH password 'kong'"
    # create config for kong
    touch /etc/kong/kong.conf
    echo "database = postgres" >> /etc/kong/kong.conf
    echo "pg_host = 127.0.0.1" >> /etc/kong/kong.conf
    echo "pg_port = 5432" >> /etc/kong/kong.conf
    echo "pg_timeout = 5000" >> /etc/kong/kong.conf
    echo "pg_user = kong" >> /etc/kong/kong.conf
    echo "pg_password = kong" >> /etc/kong/kong.conf
    echo "pg_database = kong" >> /etc/kong/kong.conf
    echo "pg_ssl = off" >> /etc/kong/kong.conf
    echo "pg_ssl_verify = off" >> /etc/kong/kong.conf
    # run the migrations
    kong migrations bootstrap -c /etc/kong/kong.conf
    # start kong
    kong start -c /etc/kong/kong.conf
    # add a service
    curl -i -X POST --url http://localhost:8001/services/ --data 'name=example-service' --data 'url=http://mockbin.org'
    # add a route 
    curl -i -X POST --url http://localhost:8001/services/example-service/routes --data 'hosts[]=example.com'
    # test route
    curl -i -X GET --url http://localhost:8000/ --header 'Host: example.com'
fi