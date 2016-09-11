--
-- MULTI_NAME_LENGTHS
--

ALTER SEQUENCE pg_catalog.pg_dist_shardid_seq RESTART 225000;
ALTER SEQUENCE pg_catalog.pg_dist_jobid_seq RESTART 225000;

-- Verify that a too-long-named table cannot be distributed.
CREATE TABLE too_long_name_12345678901234567890123456789012345678901234567890 (
        col1 integer not null,
        col2 integer not null);
SELECT master_create_distributed_table('too_long_name_12345678901234567890123456789012345678901234567890', 'col1', 'hash');

-- Table to use for rename checks.
CREATE TABLE name_lengths (
	col1 integer not null,
        col2 integer not null,
        constraint constraint_a UNIQUE (col1)
        );
SELECT master_create_distributed_table('name_lengths', 'col1', 'append');

-- Verify that we cannot add columns with too-long names

ALTER TABLE name_lengths ADD COLUMN float_col_12345678901234567890123456789012345678901234567890 FLOAT;
ALTER TABLE name_lengths ADD COLUMN date_col_12345678901234567890123456789012345678901234567890 DATE;
ALTER TABLE name_lengths ADD COLUMN int_col_12345678901234567890123456789012345678901234567890 INTEGER DEFAULT 1;

-- Verify that RENAME TO can't sneak a too-long name in there
ALTER TABLE name_lengths ADD COLUMN float_column FLOAT;
ALTER TABLE name_lengths RENAME COLUMN float_column TO float_col_12345678901234567890123456789012345678901234567890;

-- Verify that we cannot sneak too-long names in by executing commands with multiple subcommands

ALTER TABLE name_lengths ADD COLUMN int_column1 INTEGER,
	ADD COLUMN int_column2 INTEGER;

ALTER TABLE name_lengths RENAME COLUMN int_column1 TO int_col_12345678901234567890123456789012345678901234567890,
	RENAME COLUMN int_column2 TO int_col2_12345678901234567890123456789012345678901234567890;

-- TODO add constraints with long names
-- name a CHECK constraint too long, but column itself has nice name?
-- Verify that we can't rename tables or constraints to too-long names

ALTER TABLE name_lengths RENAME TO name_len_12345678901234567890123456789012345678901234567890;
ALTER TABLE name_lengths RENAME CONSTRAINT constraint_a TO const_a_12345678901234567890123456789012345678901234567890;

-- Verify that CREATE INDEX and other CREATEs can't sneak in too-long names
-- for objects related to already distributed tables.

CREATE INDEX tmp_idx_12345678901234567890123456789012345678901234567890 ON name_lengths(col2);

-- Verify that non-distributed tables with indexes, constraints, etc.
-- whose names are too long cause the table not to be distributable.

-- Clean up.
DROP TABLE name_lengths CASCADE;
