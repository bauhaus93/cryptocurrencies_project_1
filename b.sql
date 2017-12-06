delete from utxos;
delete from number_of_utxos;
delete from id_of_max_utxo;

--TODO check if coinbase transactions also considered?
insert into utxos
select output_id, value
from outputs left join inputs using(output_id)
where inputs is null
or outputs.tx_id > inputs.tx_id
order by output_id;

insert into number_of_utxos
select count(*) as utxo_count
from utxos;

insert into id_of_max_utxo
select output_id as max_utxo
from utxos
where value = (select max(value) from utxos);
