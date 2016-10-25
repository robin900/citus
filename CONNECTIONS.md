## Connection Contexts

### Synchronized Worker Connections

Each node -- including the coordinator node to which the client is connected -- has
exactly one connection. The connections' transaction boundaries are synchronized:
a `BEGIN` statement issued by the client results in a `BEGIN` statement being executed
for all of the connections.

*Allowed when:* All queries and transaction contexts
*Compatible executors:* router, real-time. Task tracker possible?

### Shard Placement Connections

Several connections are obtained from the coordinator node; each connection will
execute task queries, each query targeting a single shard placement. How many 
connections are obtained depends on configuration and connections available in the pool.
The already available Synchronized Worker Connections will participate in query
execution by serving as shard placement connections; their transaction state will
be unaffected by task query execution, so that a subsequent query sent by the client,
if it requires a Synchronized Worker Connection context, will be able to use it.

The effective user role of the shard-placement connections -- excluding
the synchronized worker connections serving a shard-placement role -- is a highly 
privileged role, "citus", and all objects and rows are visible to it. (Or should
instead the

*Allowed when:* No uncommitted DDL and no uncommitted DML, and `READ UNCOMMITTED` mode
*Compatible executors:* real-time, task tracker. router executor possible, but unneeded.

### Shard Placement Connections with Broadcast Pulls

Same set of connections are obtained as above, but individual task queries, when executing,
may perform a "broadcast pull" from other worker nodes or connections to perform
a broadcast-pull join. The broadcast pull is accomplished with a special connection,
with no relevant transaction context, either via dblink. 

The effective user role of the broadcast-pull connections is a highly privileged role, 
"citus", and all objects and rows are visible to it.

## Executors

### "Router" Executor: single shard affected

Used when a query is known to relate to only one shard placement of one distributed table;
many common DML statements meet these conditions, as do some SELECTs. 

If a logical shard has a replication_factor > 1, may the router executor be used to write
to all the shard's placements, since they reside on multiple workers? Seems like no.

*Compatible connection contexts:* synchronized worker (relevant worker connection used)

### Real-time Executor: serialized tasks, executed without delay

XXX

### Task-tracker Executor: serialized tasks, executed by background processes, with delay

XXX

## Multi-Transaction Context

### Uncommitted DDL

Forbids any connection context except synchronized worker.
Forbids task-tracker executor?
Forbids the creation of temp tables during task query processing. (Note: a sequence of CTEs
can do a lot of work in this context.)

### Uncommitted DML

Note: we track which distributed relations (or local relations?) have undergone DML;
so that queries not touching those relations have more flexibility in connection
use.

Note that SQL UDFs called in a query might reference relations not explicitly referenced
in the query; but their embedded SQL might be inspectable. Non-SQL UDFs, however,
may reference such relations and likely don't offer any introspection. So a safe rule
is "if query calls any UDF not in a cleared whitelist, consider it to be referencing
any and all relations with uncommitted DML".

Clients must be able, in all cases, to read their uncommitted writes. No exceptions.

### Isolation Level

`READ UNCOMMITTED`: any use for this? Was thinking that this level can indicate
whether shard placement connections are allowed; or whether task tracker executor
is allowed; 

`READ COMMITTED`, the default isolation, means that if there is not uncommitted DDL,
and there is not uncommitted DML on relations referenced in the query, then XXX.

`REPEATABLE READ`: means that only the synchronized worker connections may be used; 
their isolation level is set to `REPEATABLE READ` when the client sets it.

`SERIALIZABLE`: unsupported isolation level, i.e. error raised when set? 
or supported with caveats, and no error raised? 

## Role Issues

The client connection to coordinator node is always as the client's role.
Synchronized connections to other nodes might be initiated with a special role, "citus",
that implicitly has every other role (including login roles) granted to it, so these
connections can perform a `SET ROLE foo` to act as the client's role.

Can we apply this role treatment to all connections, even shard-placement connections?
After acquiring a connection, preceding any task queries, a `SET ROLE foo` is performed?
Or it's performed if the effective role on a connection can be detected in C and we
detect that it's different?

