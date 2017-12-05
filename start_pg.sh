#!/bin/sh
mkdir /tmp/postgresql
pg_ctl -D blockchain -l run.log start
psql -h /tmp/postgresql/ blockchain
