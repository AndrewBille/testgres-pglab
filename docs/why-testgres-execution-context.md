# Why PgLab needs Testgres target execution contexts

PgLab deliberately does **not** implement PostgreSQL lifecycle, backup or
physical replication itself.  Those jobs belong to Testgres.  PgLab adds Linux
isolation around a normal `PostgresNode`: each node gets its own network
namespace and server cgroup, while the host filesystem remains shared.

A typical lab looks like this:

```text
Linux host

  p1 netns                         r1 netns
  10.203.0.10:5432                 10.203.0.11:5432
  cgroup: pglab/p1                 cgroup: pglab/r1
       |                                  |
       |                                  | pg_basebackup runs here
       |<---------- PostgreSQL TCP -------|
       |                                  |
   primary                            replica
```

The two PostgreSQL servers may even use the same TCP port because the sockets
live in different network namespaces.

## What was missing in Testgres

Historically, cloning/spawning a node inherited the source node's execution
context.  That is fine when primary and replica live in the same host/network
context, but it is too late for PgLab to fix after the clone: PostgreSQL
utilities, port allocation and connection settings have already been selected.

PgLab originally had to work around this by creating a placeholder node and
then trying to mutate the spawned node into the replica's namespace.  Besides
using private state, that model cannot make `pg_basebackup` execute in the
replica's context.

The required abstraction is not "PgLab support" in Testgres.  It is a generic
**target execution context** for a spawned node.

Current Testgres exposes that directly:

```python
replica = primary.replicate(
    target_os_ops=replica_ops,
    target_host="10.203.0.11",
    target_port=5432,
    base_dir="/var/tmp/pglab/r1",
)
```

For PgLab, `replica_ops` is a `LocalOperations` derivative that wraps PostgreSQL
commands in the replica namespace:

```text
ip netns exec <namespace> runuser -u <os_user> -- <postgres command>
```

Commands that start the server also join the node cgroup before entering the
network namespace, so the postmaster and its descendants inherit the intended
I/O controls.

## Why the backup context matters

`replicate(target_os_ops=...)` creates the backup in the target execution
context.  In current Testgres this means `NodeBackup` uses that `os_ops` to run
`pg_basebackup` and to store/copy the backup.

For PgLab the sequence is therefore:

```text
1. primary is already running in p1's namespace
2. Testgres invokes pg_basebackup through r1's NamespaceOperations
3. pg_basebackup connects to p1 over TCP
4. backup/PGDATA is written under r1's base_dir
5. Testgres spawns the replica with r1's os_ops, host and port
6. PgLab starts it; Testgres still owns PostgreSQL lifecycle
```

This is also why the change is useful beyond network namespaces.  The source
and target may be any two execution contexts supported by `OsOperations`, as
long as the target can reach the source PostgreSQL endpoint and has the needed
PostgreSQL utilities.

## What PgLab gets from this API

With target execution contexts, PgLab no longer needs to modify private
`PostgresNode` fields or reimplement physical replication.  Testgres remains
responsible for:

- `pg_basebackup` and recovery configuration;
- node lifecycle and SQL helpers;
- PostgreSQL version/binary discovery;
- replication catchup and process inspection.

PgLab remains responsible only for Linux-specific isolation/fault injection:

- netns/veth/bridge setup;
- cgroup I/O limits;
- partitions and `tc netem`;
- freeze/unfreeze;
- cleanup of Linux isolation objects.

That separation is the reason the Testgres execution-context changes were
introduced in the first place.
