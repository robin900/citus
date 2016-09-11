--
-- MULTI_NAME_LENGTHS
--

ALTER SEQUENCE pg_catalog.pg_dist_shardid_seq RESTART 225000;
ALTER SEQUENCE pg_catalog.pg_dist_jobid_seq RESTART 225000;

CREATE TABLE lineitem_alter (
	l_orderkey bigint not null,
	l_partkey integer not null,
	l_suppkey integer not null,
	l_linenumber integer not null,
	l_quantity decimal(15, 2) not null,
	l_extendedprice decimal(15, 2) not null,
	l_discount decimal(15, 2) not null,
	l_tax decimal(15, 2) not null,
	l_returnflag char(1) not null,
	l_linestatus char(1) not null,
	l_shipdate date not null,
	l_commitdate date not null,
	l_receiptdate date not null,
	l_shipinstruct char(25) not null,
	l_shipmode char(10) not null,
	l_comment varchar(44) not null
	);
SELECT master_create_distributed_table('lineitem_alter', 'l_orderkey', 'append');

-- Verify that we cannot add columns with too-long names

ALTER TABLE lineitem_alter ADD COLUMN float_column_12345678901234567890123456789012345678901234567890 FLOAT;
ALTER TABLE lineitem_alter ADD COLUMN date_column_12345678901234567890123456789012345678901234567890 DATE;
ALTER TABLE lineitem_alter ADD COLUMN int_column1_12345678901234567890123456789012345678901234567890 INTEGER DEFAULT 1;

-- Verify that RENAME TO can't sneak a too-long name in there
ALTER TABLE lineitem_alter ADD COLUMN float_column FLOAT;
ALTER TABLE lineitem_alter RENAME COLUMN float_column TO float_column_12345678901234567890123456789012345678901234567890;

-- Verify that we cannot sneak too-long names in by executing commands with multiple subcommands

ALTER TABLE lineitem_alter ADD COLUMN int_column1 INTEGER,
	ADD COLUMN int_column2 INTEGER;

ALTER TABLE lineitem_alter RENAME COLUMN int_column1 TO int_column1_12345678901234567890123456789012345678901234567890,
	RENAME COLUMN int_column2 TO int_column2_12345678901234567890123456789012345678901234567890;

-- Verify that we can't rename tables or constraints to too-long names

ALTER TABLE lineitem_alter RENAME TO lineitem_renamed_12345678901234567890123456789012345678901234567890;
ALTER TABLE lineitem_alter RENAME COLUMN l_orderkey TO l_orderkey_renamed_12345678901234567890123456789012345678901234567890;
ALTER TABLE lineitem_alter RENAME CONSTRAINT constraint_a TO constraint_a_12345678901234567890123456789012345678901234567890;

-- Verify that CREATE INDEX and other CREATEs can't sneak in too-long names
-- for objects related to already distributed tables.
CREATE INDEX temp_index_2 ON lineitem_alter(l_orderkey);

-- Verify that non-distributed tables with indexes, constraints, etc.
-- whose names are too long cause the table not to be distributable.
