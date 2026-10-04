unit IB.MCP.DatasetHelper;

interface

uses
  System.Classes,
  Data.DB,
  Data.DBJson,
  FireDAC.Comp.Client;

const
  SQL_GET_TABLES =
    'select ' +
    '  r.rdb$relation_name as table_name, ' +
    '  r.rdb$description as description ' +
    'from rdb$relations r ' +
    'where coalesce(r.rdb$system_flag, 0) = 0 ' +
    '  and r.rdb$view_source is null ' +
    'order by r.rdb$relation_name';

  SQL_GET_DATABASE_INFO =
    'select ' +
    '  rdb$description as description, ' +
    '  rdb$relation_id as relation_id, ' +
    '  rdb$security_class as security_class, ' +
    '  rdb$character_set_name as character_set_name, ' +
    '  rdb$page_cache as page_cache, ' +
    '  rdb$procedure_cache as procedure_cache, ' +
    '  rdb$trigger_cache as trigger_cache, ' +
    '  rdb$relation_cache as relation_cache, ' +
    '  rdb$flush_interval as flush_interval, ' +
    '  rdb$linger_interval as linger_interval, ' +
    '  rdb$reclaim_interval as reclaim_interval, ' +
    '  rdb$sweep_interval as sweep_interval, ' +
    '  rdb$group_commit as group_commit, ' +
    '  rdb$password_digest as password_digest ' +
    'from rdb$database';

  SQL_GET_COLUMNS =
    'select ' +
    '  rf.rdb$relation_name as table_name, ' +
    '  rf.rdb$field_name as column_name, ' +
    '  f.rdb$field_type as field_type, ' +
    '  f.rdb$field_length as field_length, ' +
    '  f.rdb$field_precision as field_precision, ' +
    '  f.rdb$field_scale as field_scale, ' +
    '  case when rf.rdb$null_flag = 1 then 0 else 1 end as nullable, ' +
    '  rf.rdb$default_source as default_source, ' +
    '  cs.rdb$character_set_name as charset_name ' +
    'from rdb$relation_fields rf ' +
    'join rdb$fields f on f.rdb$field_name = rf.rdb$field_source ' +
    'left join rdb$character_sets cs on cs.rdb$character_set_id = f.rdb$character_set_id ' +
    'where rf.rdb$relation_name = :table_name ' +
    'order by rf.rdb$field_position';

  SQL_GET_INDEXES =
    'select ' +
    '  i.rdb$relation_name as table_name, ' +
    '  i.rdb$index_name as index_name, ' +
    '  s.rdb$field_name as column_name, ' +
    '  i.rdb$unique_flag as unique_flag, ' +
    '  i.rdb$index_inactive as inactivated, ' +
    '  s.rdb$field_position as field_position ' +
    'from rdb$indices i ' +
    'join rdb$index_segments s on s.rdb$index_name = i.rdb$index_name ' +
    'where i.rdb$relation_name = :table_name ' +
    'order by i.rdb$index_name, s.rdb$field_position';

  SQL_GET_FOREIGN_KEYS =
    'select ' +
    '  rc.rdb$relation_name as table_name, ' +
    '  rc.rdb$constraint_name as constraint_name, ' +
    '  rc.rdb$index_name as index_name, ' +
    '  refc.rdb$const_name_uq as referenced_constraint ' +
    'from rdb$relation_constraints rc ' +
    'join rdb$ref_constraints refc on refc.rdb$constraint_name = rc.rdb$constraint_name ' +
    'where rc.rdb$constraint_type = ''FOREIGN KEY'' ' +
    '  and rc.rdb$relation_name = :table_name ' +
    'order by rc.rdb$constraint_name';

  SQL_GET_VIEWS =
    'select ' +
    '  r.rdb$relation_name as view_name, ' +
    '  r.rdb$view_source as source ' +
    'from rdb$relations r ' +
    'where coalesce(r.rdb$system_flag, 0) = 0 ' +
    '  and r.rdb$view_source is not null ' +
    'order by r.rdb$relation_name';

  SQL_GET_CHECK_CONSTRAINTS =
    'select ' +
    '  cc.rdb$constraint_name as constraint_name, ' +
    '  t.rdb$relation_name as table_name, ' +
    '  t.rdb$trigger_source as source ' +
    'from rdb$check_constraints cc ' +
    'join rdb$triggers t on t.rdb$trigger_name = cc.rdb$trigger_name ' +
    'order by cc.rdb$constraint_name';

  SQL_GET_USER_PRIVILEGES =
    'select ' +
    '  rdb$user as user_name, ' +
    '  rdb$relation_name as object_name, ' +
    '  rdb$privilege as privilege, ' +
    '  rdb$object_type as object_type ' +
    'from rdb$user_privileges ' +
    'where rdb$user = :user_name';

  SQL_LIST_ROLES =
    'select ' +
    '  rdb$role_name as role_name, ' +
    '  rdb$owner_name as owner_name, ' +
    '  rdb$description as description ' +
    'from rdb$roles ' +
    'order by rdb$role_name';

  SQL_GET_ROLE_MEMBERS =
    'select ' +
    '  rdb$user as member_name, ' +
    '  rdb$relation_name as role_name ' +
    'from rdb$user_privileges ' +
    'where rdb$object_type = 13';

  SQL_GET_ROLE_MEMBERS_BY_ROLE =
    SQL_GET_ROLE_MEMBERS +
    '  and rdb$relation_name = :role_name';

  SQL_GET_TRIGGERS =
    'select ' +
    '  t.rdb$trigger_name as trigger_name, ' +
    '  t.rdb$relation_name as table_name, ' +
    '  t.rdb$trigger_sequence as trigger_sequence, ' +
    '  t.rdb$trigger_inactive as inactivated, ' +
    '  t.rdb$trigger_type as trigger_type, ' +
    '  t.rdb$trigger_source as source ' +
    'from rdb$triggers t ' +
    'where coalesce(t.rdb$system_flag, 0) = 0 ' +
    '  and t.rdb$trigger_source LIKE ''AS%''' +
    'order by t.rdb$relation_name, t.rdb$trigger_name';

  SQL_GET_TRIGGERS_BY_TABLE =
    'select ' +
    '  t.rdb$trigger_name as trigger_name, ' +
    '  t.rdb$relation_name as table_name, ' +
    '  t.rdb$trigger_sequence as trigger_sequence, ' +
    '  t.rdb$trigger_inactive as inactivated, ' +
    '  t.rdb$trigger_type as trigger_type, ' +
    '  t.rdb$trigger_source as source ' +
    'from rdb$triggers t ' +
    'where coalesce(t.rdb$system_flag, 0) = 0 ' +
    '  and t.rdb$trigger_source LIKE ''AS%''' +
    '  and t.rdb$relation_name = :table_name ' +
    'order by t.rdb$relation_name, t.rdb$trigger_name';

  SQL_GET_PROCEDURES =
    'select ' +
    '  p.rdb$procedure_name as procedure_name, ' +
    '  p.rdb$procedure_source as source, ' +
    '  p.rdb$description as description ' +
    'from rdb$procedures p ' +
    'where coalesce(p.rdb$system_flag, 0) = 0 ' +
    'order by p.rdb$procedure_name';

  SQL_GET_PROCEDURES_BY_NAME =
    'select ' +
    '  p.rdb$procedure_name as procedure_name, ' +
    '  p.rdb$procedure_source as source, ' +
    '  p.rdb$description as description ' +
    'from rdb$procedures p ' +
    'where coalesce(p.rdb$system_flag, 0) = 0 ' +
    '  and p.rdb$procedure_name containing :name_filter ' +
    'order by p.rdb$procedure_name';

  SQL_GET_FUNCTIONS =
    'select ' +
    '  f.rdb$function_name as function_name, ' +
    '  f.rdb$module_name as module, ' +
    '  f.rdb$description as description ' +
    'from rdb$functions f ' +
    'where coalesce(f.rdb$system_flag, 0) = 0 ' +
    'order by f.rdb$function_name';

  SQL_GET_EXCEPTIONS =
    'select ' +
    '  e.rdb$exception_name as exception_name, ' +
    '  e.rdb$message as exception_message, ' +
    '  e.rdb$description as description ' +
    'from rdb$exceptions e ' +
    'order by e.rdb$exception_name';

  SQL_GET_GENERATORS =
    'select ' +
    '  g.rdb$generator_name as generator_name, ' +
    '  g.rdb$generator_id as generator_id, ' +
    '  g.rdb$description as description ' +
    'from rdb$generators g ' +
    'where coalesce(g.rdb$system_flag, 0) = 0 ' +
    'order by g.rdb$generator_name';

  SQL_GET_DOMAINS =
    'select ' +
    '  f.rdb$field_name as domain_name, ' +
    '  f.rdb$field_type as field_type, ' +
    '  f.rdb$field_length as field_length, ' +
    '  f.rdb$field_precision as field_precision, ' +
    '  f.rdb$field_scale as field_scale, ' +
    '  f.rdb$validation_source as validation_source, ' +
    '  f.rdb$default_source as default_source, ' +
    '  f.rdb$description as description ' +
    'from rdb$fields f ' +
    'where coalesce(f.rdb$system_flag, 0) = 0 ' +
    '  and f.rdb$field_name not starting with ''RDB$'' ' +
    'order by f.rdb$field_name';

  SQL_MONITOR_ATTACHMENTS =
    'select ' +
    '  tmp$attachment_id as attachment_id, ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$pool_memory as pool_memory, ' +
    '  tmp$statements as statements, ' +
    '  tmp$transactions as transactions, ' +
    '  tmp$timestamp as timestamp_, ' +
    '  tmp$quantum as quantum, ' +
    '  tmp$user as user_name, ' +
    '  tmp$user_ip_addr as user_ip_addr, ' +
    '  tmp$user_host as user_host, ' +
    '  tmp$user_process as user_process, ' +
    '  tmp$state as state, ' +
    '  tmp$priority as priority, ' +
    '  tmp$dbkey_id as dbkey_id, ' +
    '  tmp$active_sorts as active_sorts, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_selects as record_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts ' +
    'from tmp$attachments ' +
    'order by tmp$timestamp desc, tmp$attachment_id';

  SQL_MONITOR_DATABASE =
    'select ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$database_path as database_path, ' +
    '  tmp$attachments as attachments, ' +
    '  tmp$statements as statements, ' +
    '  tmp$allocated_pages as allocated_pages, ' +
    '  tmp$pools as pools, ' +
    '  tmp$procedures as procedures, ' +
    '  tmp$relations as relations, ' +
    '  tmp$triggers as triggers, ' +
    '  tmp$active_threads as active_threads, ' +
    '  tmp$sort_memory as sort_memory, ' +
    '  tmp$current_memory as current_memory, ' +
    '  tmp$maximum_memory as maximum_memory, ' +
    '  tmp$permanent_pool_memory as permanent_pool_memory, ' +
    '  tmp$cache_pool_memory as cache_pool_memory, ' +
    '  tmp$transactions as transactions, ' +
    '  tmp$transaction_commits as transaction_commits, ' +
    '  tmp$transaction_rollbacks as transaction_rollbacks, ' +
    '  tmp$transaction_prepares as transaction_prepares, ' +
    '  tmp$transaction_deadlocks as transaction_deadlocks, ' +
    '  tmp$transaction_conflicts as transaction_conflicts, ' +
    '  tmp$transaction_waits as transaction_waits, ' +
    '  tmp$next_transaction as next_transaction, ' +
    '  tmp$oldest_interesting as oldest_interesting, ' +
    '  tmp$oldest_active as oldest_active, ' +
    '  tmp$oldest_snapshot as oldest_snapshot, ' +
    '  tmp$cache_buffers as cache_buffers, ' +
    '  tmp$cache_precedence as cache_precedence, ' +
    '  tmp$cache_latch_waits as cache_latch_waits, ' +
    '  tmp$cache_free_waits as cache_free_waits, ' +
    '  tmp$cache_free_writes as cache_free_writes, ' +
    '  tmp$sweep_interval as sweep_interval, ' +
    '  tmp$sweep_active as sweep_active, ' +
    '  tmp$sweep_relation as sweep_relation, ' +
    '  tmp$sweep_records as sweep_records, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_selects as record_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts, ' +
    '  tmp$state as state, ' +
    '  tmp$transaction_timeouts as transaction_timeouts, ' +
    '  tmp$cache_pinned_buffers as cache_pinned_buffers, ' +
    '  tmp$cache_precedence_writes as cache_precedence_writes ' +
    'from tmp$database ' +
    'order by tmp$database_path';

  SQL_MONITOR_HEAPS =
    'select ' +
    '  tmp$heap_type as heap_type, ' +
    '  tmp$hex_address as hex_address, ' +
    '  tmp$address as address, ' +
    '  tmp$free_memory as free_memory ' +
    'from tmp$heaps ' +
    'order by tmp$heap_type, tmp$address';

  SQL_MONITOR_INDICES =
    'select ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$relation_name as table_name, ' +
    '  tmp$index_name as index_name, ' +
    '  tmp$index_type as index_type, ' +
    '  tmp$index_segments as index_segments, ' +
    '  tmp$index_max_keysize as index_max_keysize, ' +
    '  tmp$index_depth as index_depth, ' +
    '  tmp$invocations as invocations, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_splits as page_splits, ' +
    '  tmp$page_reverse_splits as page_reverse_splits, ' +
    '  tmp$page_navigations as page_navigations, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$node_walks as node_walks, ' +
    '  tmp$nonleaf_node_walks as nonleaf_node_walks, ' +
    '  tmp$leaf_node_walks as leaf_node_walks, ' +
    '  tmp$equality_matches as equality_matches, ' +
    '  tmp$range_matches as range_matches ' +
    'from tmp$indices ' +
    'order by tmp$relation_name, tmp$index_name';

  SQL_MONITOR_POOL_BLOCKS =
    'select ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$acc as acc, ' +
    '  tmp$arr as arr, ' +
    '  tmp$att as att, ' +
    '  tmp$bcb as bcb, ' +
    '  tmp$bdb as bdb, ' +
    '  tmp$blb as blb, ' +
    '  tmp$blf as blf, ' +
    '  tmp$bms as bms, ' +
    '  tmp$btb as btb, ' +
    '  tmp$btc as btc, ' +
    '  tmp$charset as charset, ' +
    '  tmp$csb as csb, ' +
    '  tmp$csconvert as csconvert, ' +
    '  tmp$dbb as dbb, ' +
    '  tmp$dcc as dcc, ' +
    '  tmp$dfw as dfw, ' +
    '  tmp$dls as dls, ' +
    '  tmp$ext as ext, ' +
    '  tmp$fil as fil, ' +
    '  tmp$fld as fld, ' +
    '  tmp$fmt as fmt, ' +
    '  tmp$frb as frb, ' +
    '  tmp$fun as fun, ' +
    '  tmp$hnk as hnk, ' +
    '  tmp$idb as idb, ' +
    '  tmp$idl as idl, ' +
    '  tmp$irb as irb, ' +
    '  tmp$irl as irl, ' +
    '  tmp$lck as lck, ' +
    '  tmp$lwt as lwt, ' +
    '  tmp$map as map, ' +
    '  tmp$mfb as mfb, ' +
    '  tmp$nod as nod, ' +
    '  tmp$opt as opt, ' +
    '  tmp$prc as prc, ' +
    '  tmp$pre as pre, ' +
    '  tmp$prm as prm, ' +
    '  tmp$rec as rec, ' +
    '  tmp$rel as rel, ' +
    '  tmp$req as req, ' +
    '  tmp$riv as riv, ' +
    '  tmp$rsb as rsb, ' +
    '  tmp$rsc as rsc, ' +
    '  tmp$sav as sav, ' +
    '  tmp$sbm as sbm, ' +
    '  tmp$scl as scl, ' +
    '  tmp$sdw as sdw, ' +
    '  tmp$smb as smb, ' +
    '  tmp$srpb as srpb, ' +
    '  tmp$str as str, ' +
    '  tmp$svc as svc, ' +
    '  tmp$sym as sym, ' +
    '  tmp$texttype as texttype, ' +
    '  tmp$tfb as tfb, ' +
    '  tmp$tpc as tpc, ' +
    '  tmp$tra as tra, ' +
    '  tmp$usr as usr, ' +
    '  tmp$vcl as vcl, ' +
    '  tmp$vct as vct, ' +
    '  tmp$vcx as vcx, ' +
    '  tmp$xcp as xcp, ' +
    '  tmp$database_id as database_id ' +
    'from tmp$pool_blocks ' +
    'order by tmp$database_id, tmp$pool_id';

  SQL_MONITOR_POOLS =
    'select ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$type as type_, ' +
    '  tmp$pool_memory as pool_memory, ' +
    '  tmp$free_memory as free_memory, ' +
    '  tmp$extend_memory as extend_memory, ' +
    '  tmp$free_stack_nodes as free_stack_nodes, ' +
    '  tmp$free_bitmap_buckets as free_bitmap_buckets, ' +
    '  tmp$free_bitmap_segments as free_bitmap_segments, ' +
    '  tmp$database_id as database_id ' +
    'from tmp$pools ' +
    'order by tmp$database_id, tmp$type, tmp$pool_id';

  SQL_MONITOR_PROCEDURES =
    'select ' +
    '  tmp$procedure_id as procedure_id, ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$procedure_name as procedure_name, ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$pool_memory as pool_memory, ' +
    '  tmp$clone as clone, ' +
    '  tmp$timestamp as timestamp_, ' +
    '  tmp$use_count as use_count, ' +
    '  tmp$quantum as quantum, ' +
    '  tmp$invocations as invocations, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_selects as record_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts ' +
    'from tmp$procedures ' +
    'order by tmp$procedure_name, tmp$procedure_id';

  SQL_MONITOR_RELATIONS =
    'select ' +
    '  tmp$relation_id as relation_id, ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$relation_name as table_name, ' +
    '  tmp$use_count as use_count, ' +
    '  tmp$sweep_count as sweep_count, ' +
    '  tmp$scan_count as scan_count, ' +
    '  tmp$formats as formats, ' +
    '  tmp$pointer_pages as pointer_pages, ' +
    '  tmp$data_pages as data_pages, ' +
    '  tmp$garbage_collect_pages as garbage_collect_pages, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_idx_selects as record_idx_selects, ' +
    '  tmp$record_seq_selects as record_seq_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts ' +
    'from tmp$relations ' +
    'order by tmp$relation_name, tmp$relation_id';

  SQL_MONITOR_STATEMENTS =
    'select ' +
    '  tmp$statement_id as statement_id, ' +
    '  tmp$attachment_id as attachment_id, ' +
    '  tmp$transaction_id as transaction_id, ' +
    '  tmp$sql as sql, ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$pool_memory as pool_memory, ' +
    '  tmp$clone as clone, ' +
    '  tmp$timestamp as timestamp_, ' +
    '  tmp$quantum as quantum, ' +
    '  tmp$invocations as invocations, ' +
    '  tmp$state as state, ' +
    '  tmp$priority as priority, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_selects as record_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts, ' +
    '  tmp$database_id as database_id ' +
    'from tmp$statements ' +
    'order by tmp$timestamp desc, tmp$attachment_id, tmp$statement_id';

  SQL_MONITOR_TRANSACTIONS =
    'select ' +
    '  tmp$transaction_id as transaction_id, ' +
    '  tmp$attachment_id as attachment_id, ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$pool_memory as pool_memory, ' +
    '  tmp$timestamp as timestamp_, ' +
    '  tmp$snapshot as snapshot_, ' +
    '  tmp$quantum as quantum, ' +
    '  tmp$savepoints as savepoints, ' +
    '  tmp$readonly as readonly, ' +
    '  tmp$write as write_, ' +
    '  tmp$nowait as nowait, ' +
    '  tmp$commit_retaining as commit_retaining, ' +
    '  tmp$state as state, ' +
    '  tmp$priority as priority, ' +
    '  tmp$type as type_, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_selects as record_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts, ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$wait_time as wait_time ' +
    'from tmp$transactions ' +
    'order by tmp$timestamp desc, tmp$attachment_id, tmp$transaction_id';

  SQL_MONITOR_TRIGGERS =
    'select ' +
    '  tmp$trigger_id as trigger_id, ' +
    '  tmp$database_id as database_id, ' +
    '  tmp$relation_name as table_name, ' +
    '  tmp$trigger_name as trigger_name, ' +
    '  tmp$trigger_type as trigger_type, ' +
    '  tmp$trigger_sequence as trigger_sequence, ' +
    '  tmp$trigger_order as trigger_order, ' +
    '  tmp$trigger_order as trigger_order, ' +
    '  tmp$trigger_operation as trigger_operation, ' +
    '  tmp$pool_id as pool_id, ' +
    '  tmp$pool_memory as pool_memory, ' +
    '  tmp$clone as clone, ' +
    '  tmp$timestamp as timestamp_, ' +
    '  tmp$quantum as quantum, ' +
    '  tmp$invocations as invocations, ' +
    '  tmp$page_reads as page_reads, ' +
    '  tmp$page_writes as page_writes, ' +
    '  tmp$page_fetches as page_fetches, ' +
    '  tmp$page_marks as page_marks, ' +
    '  tmp$record_selects as record_selects, ' +
    '  tmp$record_inserts as record_inserts, ' +
    '  tmp$record_updates as record_updates, ' +
    '  tmp$record_deletes as record_deletes, ' +
    '  tmp$record_purges as record_purges, ' +
    '  tmp$record_expunges as record_expunges, ' +
    '  tmp$record_backouts as record_backouts ' +
    'from tmp$triggers ' +
    'order by tmp$relation_name, tmp$trigger_type, tmp$trigger_sequence, tmp$trigger_name';

type
  /// <summary>
  /// Converts datasets to JSON.
  /// </summary>
  TIBMCPDatasetHelper = class
  public
    /// <summary>
    /// Converts a query to JSON.
    /// </summary>
    /// <param name="ADataSet">Source query.</param>
    /// <returns>JSON array text.</returns>
    class function DatasetToJson(const ADataSet: TFDQuery): string; static;
  end;

implementation

uses
  FireDAC.Stan.Intf,
  FireDAC.Stan.StorageJSON;

  { TIBMCPDatasetHelper }

class function TIBMCPDatasetHelper.DatasetToJson(const ADataSet: TFDQuery): string;
begin
  var LStr := TStringStream.Create('');
  try
    ADataSet.SaveToStream(LStr, sfJSON);
    Result := LStr.DataString;
  finally
    LStr.Free;
  end;
end;

end.
