#!/bin/bash

pg_ctl stop -D project_1
mkdir /tmp/postgresql

pg_ctl start -D project_1/ -l run.log
psql -h /tmp/postgresql/project_1 $1
