with

first_block_transaction as (
  select min(tx_id) as tx_id, block_id
  from inputs inner join transactions using(tx_id)
  group by block_id
  order by block_id
),

block_coinbase_value as (
  select block_id, value
  from first_block_transaction inner join outputs using(tx_id)
),

block_input as (
  select block_id, sum(value)
  from 
),

select *
from block_coinbase_value
order by block_id;
