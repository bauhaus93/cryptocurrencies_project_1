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

create or replace function get_block_coinbases() returns table(block_id integer, coinbase numeric) as $$
  select block_id, sum(value) as coinbase
  from get_first_block_transactions() inner join outputs using(tx_id)
  group by block_id
  order by block_id;
$$ language sql;

create or replace function get_multiple_used_outputs() returns table(output_id integer) as $$
  select output_id
  from outputs join inputs using(output_id)
  group by output_id
  having count(*) > 1;
$$ language sql;

create or replace function get_first_multiple_usages() returns table(output_id integer, first_tx_id integer) as $$
  select output_id, min(inputs.tx_id)
  from get_multiple_used_outputs()
  join outputs using(output_id)
  join inputs using(output_id)
  join transactions on inputs.tx_id = transactions.tx_id
  group by output_id;
$$ language sql;

-- get blocks with coinbases less than current block creation fee
select *
from get_block_coinbases()
where coinbase < 5000000000;

-- get blocks, where there were transactions with less input thant output
select block_id, throughput
from get_tx_throughputs()
where throughput < 0;

-- get blocks, where the coinbase was not the block creation fee plus the sum of transactions fees
-- transaction fee = amount of input greater than output in a transaction
select *
from get_block_coinbases() join get_block_throughputs() using(block_id)
where 5000000000 + throughput <> coinbase;

-- gets blocks, where the same output was already spent in a previous transaction
select block_id, output_id, first_tx_id, tx_id
from get_first_multiple_usages() join inputs using(output_id) join transactions using(tx_id)
where inputs.tx_id > first_tx_id;

-- gets blocks, where the same output is used more than once in the same transaction
select block_id, tx_id, output_id
from get_first_multiple_usages() join inputs using(output_id) join transactions using(tx_id)
group by output_id, tx_id, block_id
having count(tx_id) > 1;
