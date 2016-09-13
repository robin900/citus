--
-- MULTI_NAME_LENGTHS
--

ALTER SEQUENCE pg_catalog.pg_dist_shardid_seq RESTART 225000;
ALTER SEQUENCE pg_catalog.pg_dist_jobid_seq RESTART 225000;

-- Verify that a too-long-named table cannot be distributed.
CREATE TABLE too_long_12345678901234567890123456789012345678901234567890 (
        col1 integer not null,
        col2 integer not null);
SELECT master_create_distributed_table('too_long_12345678901234567890123456789012345678901234567890', 'col1', 'hash');

-- Table to use for rename checks.
CREATE TABLE name_lengths (
	col1 integer not null,
        col2 integer not null,
        constraint constraint_a UNIQUE (col1)
        );
SELECT master_create_distributed_table('name_lengths', 'col1', 'hash');
SELECT master_create_worker_shards('name_lengths', '4', '2');

-- Verify that we CAN add columns with "too-long names", because
-- the columns' names are not extended in the corresponding shard tables.

ALTER TABLE name_lengths ADD COLUMN float_col_12345678901234567890123456789012345678901234567890 FLOAT;
ALTER TABLE name_lengths ADD COLUMN date_col_12345678901234567890123456789012345678901234567890 DATE;
ALTER TABLE name_lengths ADD COLUMN int_col_12345678901234567890123456789012345678901234567890 INTEGER DEFAULT 1;

-- add constraints with implicit names that are likely too long
ALTER TABLE name_lengths ADD UNIQUE (float_col_12345678901234567890123456789012345678901234567890);
ALTER TABLE name_lengths ADD EXCLUDE (int_col_12345678901234567890123456789012345678901234567890 WITH =);
ALTER TABLE name_lengths ADD CHECK (date_col_12345678901234567890123456789012345678901234567890 > '2014-01-01'::date);

-- add constraints with EXPLICIT names that are too long
ALTER TABLE name_lengths ADD CONSTRAINT unique_12345678901234567890123456789012345678901234567890 UNIQUE (float_col_12345678901234567890123456789012345678901234567890);
ALTER TABLE name_lengths ADD CONSTRAINT exclude_12345678901234567890123456789012345678901234567890 EXCLUDE (int_col_12345678901234567890123456789012345678901234567890 WITH =);
ALTER TABLE name_lengths ADD CONSTRAINT checky_12345678901234567890123456789012345678901234567890 CHECK (date_col_12345678901234567890123456789012345678901234567890 >= '2014-01-01'::date);

-- Placeholders for RENAME operation
ALTER TABLE name_lengths RENAME TO name_len_12345678901234567890123456789012345678901234567890;
ALTER TABLE name_lengths RENAME CONSTRAINT unique_12345678901234567890123456789012345678901234567890 TO unique2_12345678901234567890123456789012345678901234567890;

-- Verify that CREATE INDEX and other CREATEs can't sneak in too-long names
-- for objects related to already distributed tables.

CREATE INDEX tmp_idx_12345678901234567890123456789012345678901234567890 ON name_lengths(col2);

-- Verify that non-distributed tables with too-long names 
-- for CHECK constraints are no trouble.
CREATE TABLE sneaky_name_lengths (
	col1 integer not null,
        col2 integer not null,
        int_col_12345678901234567890123456789012345678901234567890 integer not null,
        CHECK (int_col_12345678901234567890123456789012345678901234567890 > 100)
        );
SELECT master_create_distributed_table('sneaky_name_lengths', 'col1', 'hash');
DROP TABLE sneaky_name_lengths CASCADE;

CREATE TABLE sneaky_name_lengths (
	col1 integer not null,
        col2 integer not null,
        int_col_12345678901234567890123456789012345678901234567890 integer not null,
        CONSTRAINT checky_12345678901234567890123456789012345678901234567890 CHECK (int_col_12345678901234567890123456789012345678901234567890 > 100)
        );
SELECT master_create_distributed_table('sneaky_name_lengths', 'col1', 'hash');
SELECT master_create_worker_shards('sneaky_name_lengths', '4', '2');
DROP TABLE sneaky_name_lengths CASCADE;

-- Verify that non-distributed tables with indexes, index-backed constraints
-- whose names are too long cause the table not to be distributable.
CREATE TABLE sneaky_name_lengths (
	col1 integer not null,
        col2 integer not null,
        int_col_12345678901234567890123456789012345678901234567890 integer not null,
        EXCLUDE (int_col_12345678901234567890123456789012345678901234567890 WITH =)
        );
SELECT master_create_distributed_table('sneaky_name_lengths', 'col1', 'hash');
DROP TABLE sneaky_name_lengths CASCADE;

CREATE TABLE sneaky_name_lengths (
	col1 integer not null,
        col2 integer not null,
        int_col_12345678901234567890123456789012345678901234567890 integer not null,
        constraint unique_12345678901234567890123456789012345678901234567890 UNIQUE (col1)
        );
SELECT master_create_distributed_table('sneaky_name_lengths', 'col1', 'hash');
DROP TABLE sneaky_name_lengths CASCADE;

-- Clean up.
DROP TABLE name_lengths;
