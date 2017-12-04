
create or replace function get_tx_throughputs() returns table(tx_id integer, througput integer) $$


$$ language sql


with

tx_input as (
  select transactions.block_id, transactions.tx_id, sum(value) as input_value
  from inputs join outputs using(output_id) join transactions on inputs.tx_id = transactions.tx_id
  group by transactions.tx_id
),

tx_output as (
  select transactions.block_id, tx_id, sum(value) as output_value
  from transactions join outputs using(tx_id)
  where outputs.output_id <> -1
  group by tx_id
),

first_block_transaction as (
  select min(tx_id) as tx_id, block_id
  from inputs inner join transactions using(tx_id)
  group by block_id
  order by block_id
),

block_coinbase as (
  select block_id, sum(value) as value
  from first_block_transaction inner join outputs using(tx_id)
  group by block_id
  order by block_id
),

block_diff as (
  select block_id, sum(tx_input.input_value) - sum(tx_output.output_value) as diff
  from tx_input join tx_output using(tx_id, block_id)
  group by block_id
),

block_stats as (
  select block_id, block_diff.diff as io_diff, block_coinbase.value as coinbase
  from block_diff join block_coinbase using(block_id)
)

insert into invalid_blocks
select block_id
from block_stats
where 5000000000 + io_diff <> coinbase;
