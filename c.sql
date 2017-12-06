drop table if exists closure;
drop table if exists cliques;
drop table if exists iterationset;

delete from addressRelations;
delete from max_value_by_entity;
delete from min_addr_of_max_entity;
delete from max_tx_to_max_entity;
  
drop table if exists cluster;
drop table if exists cluster_money;
create table cluster(id integer, address integer);
create table cluster_money(id integer, value bigint);

create or replace function get_entity_utxo(entity_id integer) returns table(value bigint) as $$
  with
  addresses as (select address
  from cluster
  where id = entity_id)
  select value
  from utxos join outputs using(output_id, value) join addresses on pk_id = address;
$$ language sql;

create or replace function get_entities_utxo() returns table(entity_id integer, value bigint) as $$
  select id, get_entity_utxo(id)
  from cluster
  order by id;
$$ language sql;

create or replace function get_richest_entity() returns table(entity_id integer, value bigint) as $$
  select id, value
  from cluster_money
  where value = (select max(value) from cluster_money);
$$ language sql;

create or replace function get_richest_addresses() returns table(addr integer) as $$
  select address
  from cluster join get_richest_entity() on id = entity_id;
$$ language sql;

insert into addressRelations
select a.sig_id, b.sig_id
from inputs a, inputs b
where a.output_id <> -1
and b.output_id <> -1
and a.tx_id = b.tx_id
and a.sig_id <> b.sig_id;

insert into addressRelations
select sig_id, pk_id
from (inputs join outputs using(tx_id)) a
where a.sig_id <> 0
and a.sig_id <> a.pk_id
and ( select count(*)
      from (inputs join outputs using(tx_id)) b
      where b.tx_id = a.tx_id
      group by b.tx_id) = 1;

insert into cluster
select *
from clusterAddresses();

insert into cluster_money
select entity_id, sum(value)
from get_entities_utxo()
group by entity_id
order by sum(value) desc;

insert into max_value_by_entity
select value
from get_richest_entity();

insert into min_addr_of_max_entity
select min(addr) as addr
from get_richest_addresses();

insert into max_tx_to_max_entity
select tx_id
from get_richest_addresses() join outputs on addr = pk_id
where value = (select max(value) from get_richest_addresses() join outputs on addr = pk_id);

select * from max_value_by_entity;
select * from min_addr_of_max_entity;
select * from max_tx_to_max_entity;
