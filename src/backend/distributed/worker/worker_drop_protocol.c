/*-------------------------------------------------------------------------
 *
 * worker_drop_protocol.c
 *
 * Routines for dropping distributed tables and their metadata on worker nodes.
 *
 * Copyright (c) 2016, Citus Data, Inc.
 *
 * $Id$
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "access/genam.h"
#include "access/heapam.h"
#include "access/xact.h"
#include "catalog/dependency.h"
#include "catalog/pg_foreign_server.h"
#include "distributed/citus_ruleutils.h"
#include "distributed/distribution_column.h"
#include "distributed/master_metadata_utility.h"
#include "distributed/metadata_cache.h"
#include "foreign/foreign.h"
#include "utils/fmgroids.h"


PG_FUNCTION_INFO_V1(worker_drop_distributed_table);


static void DeletePartitionRow(Oid distributedRelationId);


/*
 * worker_drop_distributed_table drops the distributed table with the given oid,
 * then, removes the associated rows from pg_dist_partition, pg_dist_shard and
 * pg_dist_shard_placement. The function also drops the server for foreign tables.
 *
 * Note that drop fails if any dependent objects are present for any of the
 * distributed tables. Also, shard placements of the distributed tables are
 * not dropped as in the case of "DROP TABLE distributed_table;" command.
 *
 * The function errors out if the input relation Oid is not a regular or foreign table.
 */
Datum
worker_drop_distributed_table(PG_FUNCTION_ARGS)
{
	Datum relationIdDatum = PG_GETARG_OID(0);
	Oid relationId = DatumGetObjectId(relationIdDatum);

	ObjectAddress distributedTableObject = { InvalidOid, InvalidOid, 0 };
	Relation distributedRelation = NULL;
	List *shardList = LoadShardList(relationId);
	ListCell *shardCell = NULL;
	char relationKind = '\0';

	/* first check the relation type */
	distributedRelation = relation_open(relationId, AccessShareLock);
	relationKind = distributedRelation->rd_rel->relkind;
	if (relationKind != RELKIND_RELATION && relationKind != RELKIND_FOREIGN_TABLE)
	{
		char *relationName = generate_relation_name(relationId, NIL);
		ereport(ERROR, (errcode(ERRCODE_WRONG_OBJECT_TYPE),
						errmsg("%s is not a regular or foreign table", relationName)));
	}

	/* close the relation since we do not need anymore */
	relation_close(distributedRelation, AccessShareLock);

	/* prepare distributedTableObject for dropping the table */
	distributedTableObject.classId = RelationRelationId;
	distributedTableObject.objectId = relationId;
	distributedTableObject.objectSubId = 0;

	/* drop the server for the foreign relations */
	if (relationKind == RELKIND_FOREIGN_TABLE)
	{
		ObjectAddresses *objects = new_object_addresses();
		ObjectAddress foreignServerObject = { InvalidOid, InvalidOid, 0 };
		ForeignTable *foreignTable = GetForeignTable(relationId);
		Oid serverId = foreignTable->serverid;

		/* prepare foreignServerObject for dropping the server */
		foreignServerObject.classId = ForeignServerRelationId;
		foreignServerObject.objectId = serverId;
		foreignServerObject.objectSubId = 0;

		/* add the addresses that are going to be dropped */
		add_exact_object_address(&distributedTableObject, objects);
		add_exact_object_address(&foreignServerObject, objects);

		/* drop both the table and the server */
		performMultipleDeletions(objects, DROP_RESTRICT,
								 PERFORM_DELETION_INTERNAL);
	}
	else
	{
		/* drop the table only */
		performDeletion(&distributedTableObject, DROP_RESTRICT,
						PERFORM_DELETION_INTERNAL);
	}

	/* iterate over shardList to delete the corresponding rows */
	foreach(shardCell, shardList)
	{
		List *shardPlacementList = NIL;
		ListCell *shardPlacementCell = NULL;
		uint64 *shardIdPointer = (uint64 *) lfirst(shardCell);
		uint64 shardId = (*shardIdPointer);

		shardPlacementList = ShardPlacementList(shardId);
		foreach(shardPlacementCell, shardPlacementList)
		{
			ShardPlacement *placement = (ShardPlacement *) lfirst(shardPlacementCell);
			char *workerName = placement->nodeName;
			uint32 workerPort = placement->nodePort;

			/* delete the row from pg_dist_shard_placement */
			DeleteShardPlacementRow(shardId, workerName, workerPort);
		}

		/* delete the row from pg_dist_shard */
		DeleteShardRow(shardId);
	}

	/* delete the row from pg_dist_partition */
	DeletePartitionRow(relationId);

	PG_RETURN_VOID();
}


/*
 * DeletePartitionRow removes the row from pg_dist_partition where the logicalrelid
 * field equals to distributedRelationId. Then, the function invalidates the
 * metadata cache.
 */
void
DeletePartitionRow(Oid distributedRelationId)
{
	Relation pgDistPartition = NULL;
	HeapTuple heapTuple = NULL;
	SysScanDesc scanDescriptor = NULL;
	ScanKeyData scanKey[1];
	int scanKeyCount = 1;

	pgDistPartition = heap_open(DistPartitionRelationId(), RowExclusiveLock);

	ScanKeyInit(&scanKey[0], Anum_pg_dist_partition_logicalrelid,
				BTEqualStrategyNumber, F_OIDEQ, ObjectIdGetDatum(distributedRelationId));

	scanDescriptor = systable_beginscan(pgDistPartition, InvalidOid, false, NULL,
										scanKeyCount, scanKey);

	heapTuple = systable_getnext(scanDescriptor);
	if (!HeapTupleIsValid(heapTuple))
	{
		ereport(ERROR, (errmsg("could not find valid entry for partition %d",
							   distributedRelationId)));
	}

	simple_heap_delete(pgDistPartition, &heapTuple->t_self);

	systable_endscan(scanDescriptor);

	/* invalidate the cache */
	CitusInvalidateRelcacheByRelid(distributedRelationId);

	/* increment the counter so that next command can see the row */
	CommandCounterIncrement();

	heap_close(pgDistPartition, RowExclusiveLock);
}
