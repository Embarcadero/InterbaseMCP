unit IB.DatasetHelper;

interface

uses
  Data.DB;

const
  SQL_GET_TABLES =
    'select ' +
    '  ltrim(rtrim(r.rdb$relation_name)) as table_name, ' +
    '  r.rdb$description as description ' +
    'from rdb$relations r ' +
    'where coalesce(r.rdb$system_flag, 0) = 0 ' +
    '  and r.rdb$view_source is null ' +
    'order by r.rdb$relation_name';

  SQL_GET_DATABASE_INFO =
    'select ' +
    '  rdb$description as description, ' +
    '  rdb$relation_id as relation_id, ' +
    '  ltrim(rtrim(rdb$security_class)) as security_class, ' +
    '  ltrim(rtrim(rdb$character_set_name)) as character_set_name, ' +
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
    '  ltrim(rtrim(rf.rdb$relation_name)) as table_name, ' +
    '  ltrim(rtrim(rf.rdb$field_name)) as column_name, ' +
    '  ltrim(rtrim(f.rdb$field_type)) as field_type, ' +
    '  f.rdb$field_length as field_length, ' +
    '  f.rdb$field_precision as field_precision, ' +
    '  f.rdb$field_scale as field_scale, ' +
    '  case when rf.rdb$null_flag = 1 then 0 else 1 end as nullable, ' +
    '  rf.rdb$default_source as default_source, ' +
    '  ltrim(rtrim(cs.rdb$character_set_name)) as charset_name ' +
    'from rdb$relation_fields rf ' +
    'join rdb$fields f on f.rdb$field_name = rf.rdb$field_source ' +
    'left join rdb$character_sets cs on cs.rdb$character_set_id = f.rdb$character_set_id ' +
    'where rf.rdb$relation_name = :table_name ' +
    'order by rf.rdb$field_position';

  SQL_GET_INDEXES =
    'select ' +
    '  ltrim(rtrim(i.rdb$relation_name)) as table_name, ' +
    '  ltrim(rtrim(i.rdb$index_name)) as index_name, ' +
    '  ltrim(rtrim(s.rdb$field_name)) as column_name, ' +
    '  i.rdb$unique_flag as unique_flag, ' +
    '  i.rdb$index_inactive as inactivated, ' +
    '  s.rdb$field_position as field_position ' +
    'from rdb$indices i ' +
    'join rdb$index_segments s on s.rdb$index_name = i.rdb$index_name ' +
    'where i.rdb$relation_name = :table_name ' +
    'order by i.rdb$index_name, s.rdb$field_position';

  SQL_GET_FOREIGN_KEYS =
    'select ' +
    '  ltrim(rtrim(rc.rdb$relation_name)) as table_name, ' +
    '  ltrim(rtrim(rc.rdb$constraint_name)) as constraint_name, ' +
    '  ltrim(rtrim(rc.rdb$index_name)) as index_name, ' +
    '  ltrim(rtrim(refc.rdb$const_name_uq)) as referenced_constraint ' +
    'from rdb$relation_constraints rc ' +
    'join rdb$ref_constraints refc on refc.rdb$constraint_name = rc.rdb$constraint_name ' +
    'where rc.rdb$constraint_type = ''FOREIGN KEY'' ' +
    '  and rc.rdb$relation_name = :table_name ' +
    'order by rc.rdb$constraint_name';

  SQL_GET_VIEWS =
    'select ' +
    '  ltrim(rtrim(r.rdb$relation_name)) as view_name, ' +
    '  r.rdb$view_source as source ' +
    'from rdb$relations r ' +
    'where coalesce(r.rdb$system_flag, 0) = 0 ' +
    '  and r.rdb$view_source is not null ' +
    'order by r.rdb$relation_name';

  SQL_GET_CHECK_CONSTRAINTS =
    'select ' +
    '  ltrim(rtrim(cc.rdb$constraint_name)) as constraint_name, ' +
    '  ltrim(rtrim(t.rdb$relation_name)) as table_name, ' +
    '  t.rdb$trigger_source as source ' +
    'from rdb$check_constraints cc ' +
    'join rdb$triggers t on t.rdb$trigger_name = cc.rdb$trigger_name ' +
    'order by cc.rdb$constraint_name';

  SQL_GET_USER_PRIVILEGES =
    'select ' +
    '  ltrim(rtrim(rdb$user)) as user_name, ' +
    '  ltrim(rtrim(rdb$relation_name)) as object_name, ' +
    '  rdb$privilege as privilege, ' +
    '  rdb$object_type as object_type ' +
    'from rdb$user_privileges ' +
    'where rdb$user = :user_name';

  SQL_LIST_ROLES =
    'select ' +
    '  ltrim(rtrim(rdb$role_name)) as role_name, ' +
    '  ltrim(rtrim(rdb$owner_name)) as owner_name, ' +
    '  rdb$description as description ' +
    'from rdb$roles ' +
    'order by rdb$role_name';

  SQL_GET_ROLE_MEMBERS =
    'select ' +
    '  ltrim(rtrim(rdb$user)) as member_name, ' +
    '  ltrim(rtrim(rdb$relation_name)) as role_name ' +
    'from rdb$user_privileges ' +
    'where rdb$object_type = 13';

  SQL_GET_ROLE_MEMBERS_BY_ROLE =
    SQL_GET_ROLE_MEMBERS +
    '  and rdb$relation_name = :role_name';

  SQL_GET_TRIGGERS =
    'select ' +
    '  ltrim(rtrim(t.rdb$trigger_name)) as trigger_name, ' +
    '  ltrim(rtrim(t.rdb$relation_name)) as table_name, ' +
    '  t.rdb$trigger_sequence as trigger_sequence, ' +
    '  t.rdb$trigger_inactive as inactivated, ' +
    '  t.rdb$trigger_type as trigger_type, ' +
    '  t.rdb$trigger_source as source ' +
    'from rdb$triggers t ' +
    'where coalesce(t.rdb$system_flag, 0) = 0 ' +
    '  and substr(t.rdb$trigger_source, 1, 2) = ''AS'' ' +
    'order by t.rdb$relation_name, t.rdb$trigger_name';

  SQL_GET_TRIGGERS_BY_TABLE =
    'select ' +
    '  ltrim(rtrim(t.rdb$trigger_name)) as trigger_name, ' +
    '  ltrim(rtrim(t.rdb$relation_name)) as table_name, ' +
    '  t.rdb$trigger_sequence as trigger_sequence, ' +
    '  t.rdb$trigger_inactive as inactivated, ' +
    '  t.rdb$trigger_type as trigger_type, ' +
    '  t.rdb$trigger_source as source ' +
    'from rdb$triggers t ' +
    'where coalesce(t.rdb$system_flag, 0) = 0 ' +
    '  and substr(t.rdb$trigger_source, 1, 2) = ''AS'' ' +
    '  and t.rdb$relation_name = :table_name ' +
    'order by t.rdb$relation_name, t.rdb$trigger_name';

  SQL_GET_PROCEDURES =
    'select ' +
    '  ltrim(rtrim(p.rdb$procedure_name)) as procedure_name, ' +
    '  p.rdb$procedure_source as source, ' +
    '  p.rdb$description as description ' +
    'from rdb$procedures p ' +
    'where coalesce(p.rdb$system_flag, 0) = 0 ' +
    'order by p.rdb$procedure_name';

  SQL_GET_PROCEDURES_BY_NAME =
    'select ' +
    '  ltrim(rtrim(p.rdb$procedure_name)) as procedure_name, ' +
    '  p.rdb$procedure_source as source, ' +
    '  p.rdb$description as description ' +
    'from rdb$procedures p ' +
    'where coalesce(p.rdb$system_flag, 0) = 0 ' +
    '  and p.rdb$procedure_name containing :name_filter ' +
    'order by p.rdb$procedure_name';

  SQL_GET_FUNCTIONS =
    'select ' +
    '  ltrim(rtrim(f.rdb$function_name)) as function_name, ' +
    '  ltrim(rtrim(f.rdb$module_name)) as module, ' +
    '  f.rdb$description as description ' +
    'from rdb$functions f ' +
    'where coalesce(f.rdb$system_flag, 0) = 0 ' +
    'order by f.rdb$function_name';

  SQL_GET_EXCEPTIONS =
    'select ' +
    '  ltrim(rtrim(e.rdb$exception_name)) as exception_name, ' +
    '  e.rdb$message as exception_message, ' +
    '  e.rdb$description as description ' +
    'from rdb$exceptions e ' +
    'order by e.rdb$exception_name';

  SQL_GET_GENERATORS =
    'select ' +
    '  ltrim(rtrim(g.rdb$generator_name)) as generator_name, ' +
    '  g.rdb$generator_id as generator_id, ' +
    '  g.rdb$description as description ' +
    'from rdb$generators g ' +
    'where coalesce(g.rdb$system_flag, 0) = 0 ' +
    'order by g.rdb$generator_name';

  SQL_GET_DOMAINS =
    'select ' +
    '  ltrim(rtrim(f.rdb$field_name)) as domain_name, ' +
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
    '  tmp$attachment_id, ' +
    '  tmp$database_id, ' +
    '  tmp$pool_id, ' +
    '  tmp$pool_memory, ' +
    '  tmp$statements, ' +
    '  tmp$transactions, ' +
    '  tmp$timestamp, ' +
    '  tmp$quantum, ' +
    '  tmp$user, ' +
    '  tmp$user_ip_addr, ' +
    '  tmp$user_host, ' +
    '  tmp$user_process, ' +
    '  tmp$state, ' +
    '  tmp$priority, ' +
    '  tmp$dbkey_id, ' +
    '  tmp$active_sorts, ' +
    '  tmp$page_reads, ' +
    '  tmp$page_writes, ' +
    '  tmp$page_fetches, ' +
    '  tmp$page_marks, ' +
    '  tmp$record_selects, ' +
    '  tmp$record_inserts, ' +
    '  tmp$record_updates, ' +
    '  tmp$record_deletes, ' +
    '  tmp$record_purges, ' +
    '  tmp$record_expunges, ' +
    '  tmp$record_backouts ' +
    'from tmp$attachments ' +
    'order by tmp$timestamp desc, tmp$attachment_id';

  SQL_MONITOR_DATABASE =
    'select ' +
    '  tmp$database_id, tmp$database_path, tmp$attachments, tmp$statements, ' +
    '  tmp$allocated_pages, tmp$pools, tmp$procedures, tmp$relations, ' +
    '  tmp$triggers, tmp$active_threads, tmp$sort_memory, tmp$current_memory, ' +
    '  tmp$maximum_memory, tmp$permanent_pool_memory, tmp$cache_pool_memory, ' +
    '  tmp$transactions, tmp$transaction_commits, tmp$transaction_rollbacks, ' +
    '  tmp$transaction_prepares, tmp$transaction_deadlocks, tmp$transaction_conflicts, ' +
    '  tmp$transaction_waits, tmp$next_transaction, tmp$oldest_interesting, ' +
    '  tmp$oldest_active, tmp$oldest_snapshot, tmp$cache_buffers, ' +
    '  tmp$cache_precedence, tmp$cache_latch_waits, tmp$cache_free_waits, ' +
    '  tmp$cache_free_writes, tmp$sweep_interval, tmp$sweep_active, ' +
    '  tmp$sweep_relation, tmp$sweep_records, tmp$page_reads, tmp$page_writes, ' +
    '  tmp$page_fetches, tmp$page_marks, tmp$record_selects, tmp$record_inserts, ' +
    '  tmp$record_updates, tmp$record_deletes, tmp$record_purges, ' +
    '  tmp$record_expunges, tmp$record_backouts, tmp$state, ' +
    '  tmp$transaction_timeouts, tmp$cache_pinned_buffers, ' +
    '  tmp$cache_precedence_writes ' +
    'from tmp$database ' +
    'order by tmp$database_path';

  SQL_MONITOR_HEAPS =
    'select ' +
    '  tmp$heap_type, ' +
    '  tmp$hex_address, ' +
    '  tmp$address, ' +
    '  tmp$free_memory ' +
    'from tmp$heaps ' +
    'order by tmp$heap_type, tmp$address';

  SQL_MONITOR_INDICES =
    'select ' +
    '  tmp$database_id, tmp$relation_name, tmp$index_name, tmp$index_type, ' +
    '  tmp$index_segments, tmp$index_max_keysize, tmp$index_depth, ' +
    '  tmp$invocations, tmp$page_reads, tmp$page_writes, tmp$page_fetches, ' +
    '  tmp$page_splits, tmp$page_reverse_splits, tmp$page_navigations, ' +
    '  tmp$record_inserts, tmp$record_updates, tmp$record_deletes, ' +
    '  tmp$node_walks, tmp$nonleaf_node_walks, tmp$leaf_node_walks, ' +
    '  tmp$equality_matches, tmp$range_matches ' +
    'from tmp$indices ' +
    'order by tmp$relation_name, tmp$index_name';

  SQL_MONITOR_POOL_BLOCKS =
    'select ' +
    '  tmp$pool_id, tmp$acc, tmp$arr, tmp$att, tmp$bcb, tmp$bdb, tmp$blb, ' +
    '  tmp$blf, tmp$bms, tmp$btb, tmp$btc, tmp$charset, tmp$csb, ' +
    '  tmp$csconvert, tmp$dbb, tmp$dcc, tmp$dfw, tmp$dls, tmp$ext, tmp$fil, ' +
    '  tmp$fld, tmp$fmt, tmp$frb, tmp$fun, tmp$hnk, tmp$idb, tmp$idl, ' +
    '  tmp$irb, tmp$irl, tmp$lck, tmp$lwt, tmp$map, tmp$mfb, tmp$nod, ' +
    '  tmp$opt, tmp$prc, tmp$pre, tmp$prm, tmp$rec, tmp$rel, tmp$req, ' +
    '  tmp$riv, tmp$rsb, tmp$rsc, tmp$sav, tmp$sbm, tmp$scl, tmp$sdw, ' +
    '  tmp$smb, tmp$srpb, tmp$str, tmp$svc, tmp$sym, tmp$texttype, ' +
    '  tmp$tfb, tmp$tpc, tmp$tra, tmp$usr, tmp$vcl, tmp$vct, tmp$vcx, ' +
    '  tmp$xcp, tmp$database_id ' +
    'from tmp$pool_blocks ' +
    'order by tmp$database_id, tmp$pool_id';

  SQL_MONITOR_POOLS =
    'select ' +
    '  tmp$pool_id, ' +
    '  tmp$type, ' +
    '  tmp$pool_memory, ' +
    '  tmp$free_memory, ' +
    '  tmp$extend_memory, ' +
    '  tmp$free_stack_nodes, ' +
    '  tmp$free_bitmap_buckets, ' +
    '  tmp$free_bitmap_segments, ' +
    '  tmp$database_id ' +
    'from tmp$pools ' +
    'order by tmp$database_id, tmp$type, tmp$pool_id';

  SQL_MONITOR_PROCEDURES =
    'select ' +
    '  tmp$procedure_id, tmp$database_id, tmp$procedure_name, tmp$pool_id, ' +
    '  tmp$pool_memory, tmp$clone, tmp$timestamp, tmp$use_count, ' +
    '  tmp$quantum, tmp$invocations, tmp$page_reads, tmp$page_writes, ' +
    '  tmp$page_fetches, tmp$page_marks, tmp$record_selects, tmp$record_inserts, ' +
    '  tmp$record_updates, tmp$record_deletes, tmp$record_purges, ' +
    '  tmp$record_expunges, tmp$record_backouts ' +
    'from tmp$procedures ' +
    'order by tmp$procedure_name, tmp$procedure_id';

  SQL_MONITOR_RELATIONS =
    'select ' +
    '  tmp$relation_id, tmp$database_id, tmp$relation_name, tmp$use_count, ' +
    '  tmp$sweep_count, tmp$scan_count, tmp$formats, tmp$pointer_pages, ' +
    '  tmp$data_pages, tmp$garbage_collect_pages, tmp$page_reads, ' +
    '  tmp$page_writes, tmp$page_fetches, tmp$page_marks, ' +
    '  tmp$record_idx_selects, tmp$record_seq_selects, tmp$record_inserts, ' +
    '  tmp$record_updates, tmp$record_deletes, tmp$record_purges, ' +
    '  tmp$record_expunges, tmp$record_backouts ' +
    'from tmp$relations ' +
    'order by tmp$relation_name, tmp$relation_id';

  SQL_MONITOR_STATEMENTS =
    'select ' +
    '  tmp$statement_id, tmp$attachment_id, tmp$transaction_id, tmp$sql, ' +
    '  tmp$pool_id, tmp$pool_memory, tmp$clone, tmp$timestamp, tmp$quantum, ' +
    '  tmp$invocations, tmp$state, tmp$priority, tmp$page_reads, ' +
    '  tmp$page_writes, tmp$page_fetches, tmp$page_marks, tmp$record_selects, ' +
    '  tmp$record_inserts, tmp$record_updates, tmp$record_deletes, ' +
    '  tmp$record_purges, tmp$record_expunges, tmp$record_backouts, ' +
    '  tmp$database_id ' +
    'from tmp$statements ' +
    'order by tmp$timestamp desc, tmp$attachment_id, tmp$statement_id';

  SQL_MONITOR_TRANSACTIONS =
    'select ' +
    '  tmp$transaction_id, tmp$attachment_id, tmp$pool_id, tmp$pool_memory, ' +
    '  tmp$timestamp, tmp$snapshot, tmp$quantum, tmp$savepoints, tmp$readonly, ' +
    '  tmp$write, tmp$nowait, tmp$commit_retaining, tmp$state, tmp$priority, ' +
    '  tmp$type, tmp$page_reads, tmp$page_writes, tmp$page_fetches, tmp$page_marks, ' +
    '  tmp$record_selects, tmp$record_inserts, tmp$record_updates, ' +
    '  tmp$record_deletes, tmp$record_purges, tmp$record_expunges, ' +
    '  tmp$record_backouts, tmp$database_id, tmp$wait_time ' +
    'from tmp$transactions ' +
    'order by tmp$timestamp desc, tmp$attachment_id, tmp$transaction_id';

  SQL_MONITOR_TRIGGERS =
    'select ' +
    '  tmp$trigger_id, tmp$database_id, tmp$relation_name, tmp$trigger_name, ' +
    '  tmp$trigger_type, tmp$trigger_sequence, tmp$trigger_order, ' +
    '  tmp$trigger_operation, tmp$pool_id, tmp$pool_memory, tmp$clone, ' +
    '  tmp$timestamp, tmp$quantum, tmp$invocations, tmp$page_reads, ' +
    '  tmp$page_writes, tmp$page_fetches, tmp$page_marks, tmp$record_selects, ' +
    '  tmp$record_inserts, tmp$record_updates, tmp$record_deletes, ' +
    '  tmp$record_purges, tmp$record_expunges, tmp$record_backouts ' +
    'from tmp$triggers ' +
    'order by tmp$relation_name, tmp$trigger_type, tmp$trigger_sequence, tmp$trigger_name';

type
  /// <summary>
  /// Utility class providing helper methods for dataset manipulation and JSON conversion.
  /// </summary>
  TIBDatasetHelper = class
  public
    /// <summary>
    /// Converts a TDataSet to a JSON string representation.
    /// </summary>
    /// <param name="ADataSet">The dataset to be converted.</param>
    /// <param name="AMaxRows">Maximum number of rows to include (default: 200). Use 0 for no limit.</param>
    /// <returns>A JSON array string containing the dataset records.</returns>
    class function DatasetToJson(const ADataSet: TDataSet; AMaxRows: Integer = 200): string; static;
    
    /// <summary>
    /// Overloaded shorthand for DatasetToJson with default parameters.
    /// </summary>
    /// <param name="ADataSet">The dataset to be converted.</param>
    /// <returns>A JSON array string representing the dataset.</returns>
    class function ToJson(const ADataSet: TDataSet): string; static;
  end;

implementation

uses
  System.JSON,
  FireDAC.Comp.BatchMove,
  FireDAC.Comp.BatchMove.DataSet,
  FireDAC.Comp.BatchMove.JSON;

type
  TBatchMoveRowLimiter = class
  private
    FMaxRows: Integer;
    FRowCount: Integer;
  public
    constructor Create(AMaxRows: Integer);
    procedure WriteRecord(ASender: TObject; var AAction: TFDBatchMoveAction);
  end;

{ TBatchMoveRowLimiter }

constructor TBatchMoveRowLimiter.Create(AMaxRows: Integer);
begin
  inherited Create;
  FMaxRows := AMaxRows;
end;

procedure TBatchMoveRowLimiter.WriteRecord(ASender: TObject; var AAction: TFDBatchMoveAction);
begin
  if (FMaxRows > 0) and (FRowCount >= FMaxRows) then begin
    AAction := paSkip;
    TFDBatchMove(ASender).AbortJob;
    Exit;
  end;

  Inc(FRowCount);
end;

{ TIBDatasetHelper }

class function TIBDatasetHelper.DatasetToJson(const ADataSet: TDataSet; AMaxRows: Integer): string;
var
  BatchMove: TFDBatchMove;
  JsonArray: TJSONArray;
  Limiter: TBatchMoveRowLimiter;
  Reader: TFDBatchMoveDataSetReader;
  Writer: TFDBatchMoveJSONWriter;
begin
  JsonArray := TJSONArray.Create;
  try
    if Assigned(ADataSet) then begin
      BatchMove := TFDBatchMove.Create(nil);
      try
        Reader := TFDBatchMoveDataSetReader.Create(BatchMove);
        Reader.DataSet := ADataSet;

        Writer := TFDBatchMoveJSONWriter.Create(BatchMove);
        Writer.JsonArray := JsonArray;
        Writer.JsonFormat := jfJSON;

        BatchMove.Reader := Reader;
        BatchMove.Writer := Writer;
        if AMaxRows > 0 then begin
          Limiter := TBatchMoveRowLimiter.Create(AMaxRows);
          try
            BatchMove.OnWriteRecord := Limiter.WriteRecord;
            BatchMove.Execute;
          finally
            Limiter.Free;
          end;
        end
        else
          BatchMove.Execute;
      finally
        BatchMove.Free;
      end;
    end;

    Result := JsonArray.ToJSON;
  finally
    JsonArray.Free;
  end;
end;

class function TIBDatasetHelper.ToJson(const ADataSet: TDataSet): string;
begin
  Result := DatasetToJson(ADataSet);
end;

end.
