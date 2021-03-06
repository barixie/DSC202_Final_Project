-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## Ethereum Blockchain Data Analysis - <a href=https://github.com/blockchain-etl/ethereum-etl-airflow/tree/master/dags/resources/stages/raw/schemas>Table Schemas</a>
-- MAGIC - **Transactions** - Each block in the blockchain is composed of zero or more transactions. Each transaction has a source address, a target address, an amount of Ether transferred, and an array of input bytes. This table contains a set of all transactions from all blocks, and contains a block identifier to get associated block-specific information associated with each transaction.
-- MAGIC - **Blocks** - The Ethereum blockchain is composed of a series of blocks. This table contains a set of all blocks in the blockchain and their attributes.
-- MAGIC - **Receipts** - the cost of gas for specific transactions.
-- MAGIC - **Traces** - The trace module is for getting a deeper insight into transaction processing. Traces exported using <a href=https://openethereum.github.io/JSONRPC-trace-module.html>Parity trace module</a>
-- MAGIC - **Tokens** - Token data including contract address and symbol information.
-- MAGIC - **Token Transfers** - The most popular type of transaction on the Ethereum blockchain invokes a contract of type ERC20 to perform a transfer operation, moving some number of tokens from one 20-byte address to another 20-byte address. This table contains the subset of those transactions and has further processed and denormalized the data to make it easier to consume for analysis of token transfer events.
-- MAGIC - **Contracts** - Some transactions create smart contracts from their input bytes, and this smart contract is stored at a particular 20-byte address. This table contains a subset of Ethereum addresses that contain contract byte-code, as well as some basic analysis of that byte-code. 
-- MAGIC - **Logs** - Similar to the token_transfers table, the logs table contains data for smart contract events. However, it contains all log data, not only ERC20 token transfers. This table is generally useful for reporting on any logged event type on the Ethereum blockchain.
-- MAGIC 
-- MAGIC ### Rubric for this module
-- MAGIC Answer the quetions listed below.

-- COMMAND ----------

-- MAGIC %run ./includes/utilities

-- COMMAND ----------

-- MAGIC %run ./includes/configuration

-- COMMAND ----------

-- MAGIC %python
-- MAGIC # Grab the global variables
-- MAGIC wallet_address,start_date = Utils.create_widgets()
-- MAGIC print(wallet_address,start_date)
-- MAGIC spark.conf.set('wallet.address',wallet_address)
-- MAGIC spark.conf.set('start.date',start_date)

-- COMMAND ----------

-- MAGIC %python
-- MAGIC spark.conf.set("spark.sql.shuffle.partitions", "auto")
-- MAGIC spark.conf.set("spark.sql.execution.arrow.enabled", "true")

-- COMMAND ----------

-- MAGIC %sql
-- MAGIC use ethereumetl;

-- COMMAND ----------

-- MAGIC %python
-- MAGIC blocks_df = spark.sql("select * from blocks")
-- MAGIC contracts_df = spark.sql("select * from contracts")
-- MAGIC logs_df = spark.sql("select * from logs")
-- MAGIC receipts_df = spark.sql("select * from receipts")
-- MAGIC tokentransfers_df = spark.sql("select * from token_transfers")
-- MAGIC tokens_df = spark.sql("select * from tokens")
-- MAGIC tokenpricesusd_df = spark.sql("select * from token_prices_usd")
-- MAGIC transactions_df = spark.sql("select * from transactions")

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: What is the maximum block number and date of block in the database

-- COMMAND ----------

-- MAGIC %python
-- MAGIC # Use block table
-- MAGIC block_max = blocks_df.agg({"number": "max"}).collect()[0][0]
-- MAGIC print("The maximum block number is "+ str(block_max))
-- MAGIC timestampDF = blocks_df.withColumn("timestamp", (col("timestamp")).cast(TimestampType()))
-- MAGIC stamp_max = timestampDF.agg({"timestamp": "max"}).collect()[0][0]
-- MAGIC print("The maximum date of bloack is "+ str(stamp_max))

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: At what block did the first ERC20 transfer happen?

-- COMMAND ----------

select blocks.number from blocks 
inner join g09_db.erc20_token_transfers on blocks.number = g09_db.erc20_token_transfers.block_number 
order by blocks.timestamp 
limit 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: How many ERC20 compatible contracts are there on the blockchain?

-- COMMAND ----------

-- TBD
select count(*) from silver_contracts where is_erc20 = True;

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC ## Q: What percentage of transactions are calls to contracts

-- COMMAND ----------

-- TBD
select (count(*)/(select count(*) from transactions))*100 from silver_contracts join transactions on silver_contracts.address = transactions.to_address;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: What are the top 100 tokens based on transfer count?

-- COMMAND ----------

-- TBD
select distinct tokens.name, token_address, num_transfer from ((select token_address, count(*) as num_transfer from token_transfers group by token_address order by num_transfer desc limit 100) as top_100) left join tokens on top_100.token_address = tokens.address order by num_transfer desc;
-- the reason the query showing 102 rows is that the same token address has two different token names.(that's wired but we actually find the top100 tokens based on transfer count)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: What fraction of ERC-20 transfers are sent to new addresses
-- MAGIC (i.e. addresses that have a transfer count of 1 meaning there are no other transfers to this address for this token this is the first)

-- COMMAND ----------

-- TBD
select (count(*)/(select count(*) from g09_db.erc20_token_transfers))*100 as fraction from
(select token_address, count(*) as num_transfer from g09_db.erc20_token_transfers group by token_address, to_address having num_transfer = 1)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: In what order are transactions included in a block in relation to their gas price?
-- MAGIC - hint: find a block with multiple transactions 

-- COMMAND ----------

-- TBD
select count(*) as num_of_transactions, block_number from transactions group by block_number;

-- COMMAND ----------

select * from transactions where block_number = "3089527";

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Decreasing order

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: What was the highest transaction throughput in transactions per second?
-- MAGIC hint: assume 15 second block time

-- COMMAND ----------

-- TBD
SELECT transaction_count/15 from blocks order by transaction_count desc limit 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: What is the total Ether volume?
-- MAGIC Note: 1x10^18 wei to 1 eth and value in the transaction table is in wei

-- COMMAND ----------

-- TBD
select sum(value)/1000000000000000000 as total_ether_volume from transactions;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: What is the total gas used in all transactions?

-- COMMAND ----------

select sum(gas) as total_gas from transactions;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: Maximum ERC-20 transfers in a single transaction

-- COMMAND ----------

-- TBD
select count(*) as num_transactions from g09_db.erc20_token_transfers where is_erc20 = True group by transaction_hash order by num_transactions desc limit 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Q: Token balance for any address on any date?

-- COMMAND ----------

-- MAGIC %python
-- MAGIC from pyspark.sql.functions import to_date, col
-- MAGIC timestampDF = blocks_df.withColumn("timestamp", to_date(col("timestamp").cast("timestamp")))
-- MAGIC display(timestampDF)

-- COMMAND ----------

-- MAGIC %python
-- MAGIC conversionsDF = timestampDF.join(tokentransfers_df,timestampDF.number == tokentransfers_df.block_number,"inner").filter((col("timestamp") < start_date) & ((col("to_address") == wallet_address) | (col("from_address") == wallet_address)))
-- MAGIC display(conversionsDF)

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Viz the transaction count over time (network use)

-- COMMAND ----------

use g09_db;
CREATE VIEW IF NOT EXISTS blocks_date AS
(SELECT *, FROM_UNIXTIME(timestamp,'y-M-d') AS time_date FROM ethereumetl.blocks);

-- COMMAND ----------

-- TBD
use ethereumetl;
select time_date, count(*) as trans_count from g09_db.blocks_date join transactions 
where g09_db.blocks_date.number = transactions.block_number group by time_date order by time_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Viz ERC-20 transfer count over time
-- MAGIC interesting note: https://blog.ins.world/insp-ins-promo-token-mixup-clarified-d67ef20876a3

-- COMMAND ----------

-- TBD
select time_date, count(*) as transfer_count from g09_db.blocks_date join g09_db.erc20_token_transfers 
where g09_db.blocks_date.number = g09_db.erc20_token_transfers.block_number group by time_date order by time_date;

-- COMMAND ----------

-- MAGIC %python
-- MAGIC # Return Success
-- MAGIC dbutils.notebook.exit(json.dumps({"exit_code": "OK"}))

-- COMMAND ----------


