--delete from invalid_blocks;

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

/*
-- gets blocks, where the first tx is not a coinbase tx
select block_id, tx_id, output_id, sig_id
from get_first_block_transactions() join inputs using(tx_id)
where output_id <> -1 or sig_id <> 0;

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

-- gets blocks, where the same output is used more than once as input in the same transaction
select block_id, tx_id, output_id
from get_first_multiple_usages() join inputs using(output_id) join transactions using(tx_id)
group by output_id, tx_id, block_id
having count(tx_id) > 1;

-- gets blocks, where the input signature pk is not the pk of the owner of the output
-- = a person wanted to buy something with money another person owns
-- signature ids of -1 are ignored, since different sig calculation scripts (standard/custom)
-- can be used in different transactions (by the same user, but this can't be checked with the given data)
select block_id, output_id, input_id, pk_id, sig_id
from outputs join inputs using(output_id) join transactions on inputs.tx_id = transactions.tx_id
where output_id > -1 and pk_id <> sig_id and sig_id <> -1;

-- selects all blocks, where the a transaction used an input which is generated in a future transaction
-- = the money is not (yet) owned by the payer
select out_tx.block_id as output_block, in_tx.block_id as input_block, outputs.tx_id as output_tx, inputs.tx_id as input_tx, output_id
from outputs join inputs using(output_id), transactions as out_tx, transactions as in_tx
where inputs.tx_id < outputs.tx_id
and outputs.tx_id = out_tx.tx_id
and inputs.tx_id = in_tx.tx_id;

-- selects all blocks, where there are more than one coinbase transaction
-- There must only be 1 coinbase transaction per block
select block_id, min(tx_id) as min_coinbase_tx, max(tx_id) as max_coinbase_tx
from inputs join outputs using(tx_id) join transactions using(tx_id)
where inputs.output_id = -1
group by block_id
having min(tx_id) <> max(tx_id);

-- selects all blocks, where transactions with illegal values occur
select block_id, output_id, value
from outputs join transactions using(tx_id)
where outputs.value > 2100000000000000 or outputs.value < 0;

-- select all blocks, where the total transferred output is not in legal range
select block_id, tx_id, sum(value) as total_value
from outputs join transactions using(tx_id)
group by tx_id, block_id
having sum(value) > 2100000000000000 or sum(value) < 0;

-- selects all blocks, with invalid input sig ids (sig ids must be >= -1)
select block_id, sig_id
from inputs join transactions using(tx_id)
where sig_id < -1;

-- selects all blocks, with invalid output pk ids (pk ids must be >= -1)
select block_id, pk_id
from outputs join transactions using(tx_id)
where pk_id < -1;*/


insert into invalid_blocks
select block_id
from get_first_block_transactions() join inputs using(tx_id)
where output_id <> -1 or sig_id <> 0;

insert into invalid_blocks
select block_id
from get_block_coinbases()
where coinbase < 5000000000;

insert into invalid_blocks
select block_id
from get_tx_throughputs()
where throughput < 0;

insert into invalid_blocks
select block_id
from get_block_coinbases() join get_block_throughputs() using(block_id)
where 5000000000 + throughput <> coinbase;

insert into invalid_blocks
select block_id
from get_first_multiple_usages() join inputs using(output_id) join transactions using(tx_id)
where inputs.tx_id > first_tx_id;

insert into invalid_blocks
select block_id
from get_first_multiple_usages() join inputs using(output_id) join transactions using(tx_id)
group by output_id, tx_id, block_id
having count(tx_id) > 1;

insert into invalid_blocks
select block_id
from outputs join inputs using(output_id) join transactions on inputs.tx_id = transactions.tx_id
where output_id > -1 and pk_id <> sig_id and sig_id <> -1;

insert into invalid_blocks
select in_tx.block_id
from outputs join inputs using(output_id), transactions as out_tx, transactions as in_tx
where inputs.tx_id < outputs.tx_id
and outputs.tx_id = out_tx.tx_id
and inputs.tx_id = in_tx.tx_id;

insert into invalid_blocks
select block_id
from inputs join outputs using(tx_id) join transactions using(tx_id)
where inputs.output_id = -1
group by block_id
having min(tx_id) <> max(tx_id);

insert into invalid_blocks
select block_id
from outputs join transactions using(tx_id)
where outputs.value > 2100000000000000 or outputs.value < 0;

insert into invalid_blocks
select block_id
from outputs join transactions using(tx_id)
group by tx_id, block_id
having sum(value) > 2100000000000000 or sum(value) < 0;

insert into invalid_blocks
select block_id
from inputs join transactions using(tx_id)
where sig_id < -1;

insert into invalid_blocks
select block_id
from outputs join transactions using(tx_id)
where pk_id < -1;

select * from invalid_blocks group by block_id;
