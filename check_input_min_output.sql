
with

tx_input as (
  select transactions.tx_id, sum(value) as input_value
  from inputs join outputs using(output_id) join transactions on inputs.tx_id = transactions.tx_id
  group by transactions.tx_id
),

tx_output as (
  select tx_id, sum(value) as output_value
  from transactions join outputs using(tx_id)
  where outputs.output_id <> -1
  group by tx_id
)

insert into invalid_blocks
select block_id
from tx_input join tx_output using(tx_id) join transactions using(tx_id)
where input_value < output_value
