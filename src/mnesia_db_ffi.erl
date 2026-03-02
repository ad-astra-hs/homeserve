-module(mnesia_db_ffi).
-export([initialize/1, get_doc/2, put_doc/3, delete_doc/2, get_all_docs/1, table_info/1, clear_table/1]).

%% Convert a format string + args to a binary (Gleam String-compatible).
%% Gleam strings are Erlang binaries; io_lib:format returns a charlist,
%% so we must convert before returning to Gleam.
-define(FMT(Fmt, Args), erlang:iolist_to_binary(io_lib:format(Fmt, Args))).

%% Initialize Mnesia and create tables
%% DataDir is either: none (atom) or {some, BinaryString}
initialize(DataDir) ->
    try
        %% Set data directory if provided
        case DataDir of
            {some, Dir} when is_binary(Dir) -> 
                application:set_env(mnesia, dir, binary_to_list(Dir));
            _ -> 
                ok
        end,
        
        %% Start mnesia if not already running
        case mnesia:start() of
            ok -> ok;
            {error, {already_started, _}} -> ok
        end,
        
        %% Check if we need to recreate the schema for disc_copies
        case node() of
            nonode@nohost -> 
                %% Running without node name, use ram_copies
                create_tables(ram_copies);
            Node -> 
                %% Running with node name, try disc_copies
                case check_schema_supports_disc(Node) of
                    true -> 
                        create_tables(disc_copies);
                    false -> 
                        %% Schema doesn't support disc_copies for this node
                        %% We need to recreate it
                        case recreate_schema_for_node(Node) of
                            ok -> create_tables(disc_copies);
                            {error, _} -> 
                                %% Fallback to ram_copies if schema recreation fails
                                create_tables(ram_copies)
                        end
                end
        end
    catch
        throw:{error, Msg} -> {error, erlang:iolist_to_binary(Msg)};
        Class:Reason ->
            {error, ?FMT("Mnesia initialization failed: ~p:~p", [Class, Reason])}
    end.

%% Check if the current schema supports disc_copies for the given node
check_schema_supports_disc(Node) ->
    try
        DiscNodes = mnesia:table_info(schema, disc_copies),
        lists:member(Node, DiscNodes)
    catch
        _:_ -> false
    end.

%% Recreate the Mnesia schema to support disc_copies for the current node
recreate_schema_for_node(Node) ->
    try
        io:format("Recreating Mnesia schema for node ~p to enable disc_copies...~n", [Node]),
        
        %% Delete existing tables
        catch mnesia:delete_table(panel),
        catch mnesia:delete_table(volunteer),
        
        %% Stop mnesia
        mnesia:stop(),
        
        %% Delete and recreate schema
        case mnesia:delete_schema([Node]) of
            ok -> ok;
            {error, _} -> ok  %% Schema might not exist
        end,
        
        case mnesia:create_schema([Node]) of
            ok -> 
                mnesia:start(),
                io:format("Schema recreated successfully~n"),
                ok;
            {error, Reason} -> 
                mnesia:start(),
                {error, ?FMT("Failed to create schema: ~p", [Reason])}
        end
    catch
        ErrClass:ErrReason ->
            catch mnesia:start(),
            {error, ?FMT("Schema recreation failed: ~p:~p", [ErrClass, ErrReason])}
    end.

%% Create tables with the specified storage type
create_tables(StorageType) ->
    %% Create panel table if it doesn't exist
    case create_table_internal(panel, StorageType) of
        ok -> ok;
        {error, Msg1} -> throw({error, Msg1})
    end,
    
    %% Create volunteer table if it doesn't exist
    case create_table_internal(volunteer, StorageType) of
        ok -> ok;
        {error, Msg2} -> throw({error, Msg2})
    end,
    
    %% Wait for tables
    case mnesia:wait_for_tables([panel, volunteer], 5000) of
        ok -> {ok, nil};
        {timeout, Tables} ->
            throw({error, ?FMT("Timeout waiting for tables: ~p", [Tables])});
        {error, Reason3} ->
            throw({error, ?FMT("Error waiting for tables: ~p", [Reason3])})
    end.

%% Helper function to create table with proper error handling
create_table_internal(Table, StorageType) ->
    case mnesia:create_table(Table, [
        {attributes, [key, data]},
        {StorageType, [node()]},
        {type, set}
    ]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, Table}} -> ok;
        {aborted, {bad_type, Table, disc_copies, _Node}} when StorageType == disc_copies ->
            %% Schema doesn't support disc_copies for this node
            %% Fall back to ram_copies
            case mnesia:create_table(Table, [
                {attributes, [key, data]},
                {ram_copies, [node()]},
                {type, set}
            ]) of
                {atomic, ok} -> ok;
                {aborted, {already_exists, Table}} -> ok;
                {aborted, Reason} -> 
                    {error, ?FMT("Failed to create ~p table (even with ram_copies): ~p", [Table, Reason])}
            end;
        {aborted, Reason} ->
            {error, ?FMT("Failed to create ~p table: ~p", [Table, Reason])}
    end.

%% Get a document by key
%% Returns {ok, Value} | {error, "not_found"} | {error, Msg}
get_doc(Table, Key) ->
    try
        case mnesia:dirty_read(Table, Key) of
            [{Table, _Key, Value}] -> {ok, Value};
            [] -> {error, <<"not_found">>};
            ErrorResult ->
                {error, ?FMT("Read failed: ~p", [ErrorResult])}
        end
    catch
        Class:Reason ->
            {error, ?FMT("Get failed: ~p:~p", [Class, Reason])}
    end.

%% Put a document
%% Returns {ok, nil} | {error, Msg}
put_doc(Table, Key, Value) ->
    try
        Record = {Table, Key, Value},
        ok = mnesia:dirty_write(Record),
        {ok, nil}
    catch
        Class:Reason ->
            {error, ?FMT("Put failed: ~p:~p", [Class, Reason])}
    end.

%% Delete a document
%% Returns {ok, nil} | {error, Msg}
delete_doc(Table, Key) ->
    try
        ok = mnesia:dirty_delete(Table, Key),
        {ok, nil}
    catch
        Class:Reason ->
            {error, ?FMT("Delete failed: ~p:~p", [Class, Reason])}
    end.

%% Get all documents from a table
%% Returns {ok, Docs} | {error, Msg}
get_all_docs(Table) ->
    try
        Keys = mnesia:dirty_all_keys(Table),
        Docs = lists:filtermap(
            fun(Key) ->
                case mnesia:dirty_read(Table, Key) of
                    [{Table, _Key, Value}] -> {true, Value};
                    _ -> false
                end
            end,
            Keys
        ),
        {ok, Docs}
    catch
        Class:Reason ->
            {error, ?FMT("Get all failed: ~p:~p", [Class, Reason])}
    end.

%% Get table size
%% Returns {ok, Size} | {error, Msg}
table_info(Table) ->
    try
        Size = mnesia:table_info(Table, size),
        {ok, Size}
    catch
        Class:Reason ->
            {error, ?FMT("Table info failed: ~p:~p", [Class, Reason])}
    end.

%% Clear all data from a table
%% Returns {ok, nil} | {error, Msg}
clear_table(Table) ->
    try
        %% Get all keys and delete them one by one
        Keys = mnesia:dirty_all_keys(Table),
        lists:foreach(fun(Key) -> mnesia:dirty_delete(Table, Key) end, Keys),
        {ok, nil}
    catch
        Class:Reason ->
            {error, ?FMT("Clear table failed: ~p:~p", [Class, Reason])}
    end.
