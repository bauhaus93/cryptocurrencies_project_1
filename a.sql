create or replace function get_tx_throughputs() returns table(tx_id integer, block_id integer, throughput numeric) as $$
  with
  tx_input as (
    select transactions.block_id, transactions.tx_id, sum(value) as value
    from inputs join outputs using(output_id) join transactions on inputs.tx_id = transactions.tx_id
    group by transactions.tx_id
  ),
  tx_output as (
    select transactions.block_id, tx_id, sum(value) as value
    from transactions join outputs using(tx_id)
    where outputs.output_id <> -1
    group by tx_id
  )
  select tx_id, block_id, tx_input.value - tx_output.value as throughput
  from tx_input join tx_output using(tx_id, block_id);
$$ language sql;

create or replace function get_block_throughputs() returns table(block_id integer, throughput numeric) as $$
  select block_id, sum(throughput) as throughput
  from get_tx_throughputs()
  group by block_id
  order by block_id;
$$ language sql;

create or replace function get_first_block_transactions() returns table(block_id integer, tx_id integer) as $$
  select block_id, min(tx_id) as tx_id
  from inputs inner join transactions using(tx_id)
  group by block_id
  order by block_id;
$$ language sql;

create or replace function get_block_creation_fee() returns table(block_id integer, creation_fee numeric) as $$
  select block_id, sum(value) as creation_fee
  from get_first_block_transactions() inner join outputs using(tx_id)
  group by block_id
  order by block_id;
$$ language sql;

select *
from get_block_creation_fee()
where creation_fee < 5000000000;
