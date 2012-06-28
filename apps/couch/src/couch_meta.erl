% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

-module(couch_meta).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([maybe_create_meta/2]).
-export([maybe_delete_meta/1]).
-export([get_meta/1]).
-export([update_meta/2]).
-export([ensure_meta_db_exists/0]).

-include("couch_db.hrl").

-define(SYSTEM_KEY, <<"system">>).
-define(DB_KEY, <<"db">>).
-define(CREATED_KEY, <<"created">>).
-define(LAST_UPDATED_AT_KEY, <<"last_updated_at">>).
-define(COUCH_ID_KEY, <<"_id">>).
-define(COUCH_REV_KEY, <<"_rev">>).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

maybe_create_meta(DbName, Meta) ->
    {ok, Db} = ensure_meta_db_exists(),
    JsonDoc = case Meta of
        undefined ->
            create_default_meta_for_db(DbName);
        _ ->
            Meta
    end,
    Doc = couch_doc:from_json_obj(JsonDoc),
    Doc2 = Doc#doc{id=DbName, revs={0, []}},
    ?LOG_INFO("Doc to be created for db ~p: ~p~n",[DbName, Doc2]),
    case (catch couch_db:update_doc(Db, Doc2, [full_commit])) of
        {ok, _} -> ok;
        Error ->
            ?LOG_INFO("Meta doc error (~s): ~p",[DbName, Error]),
            Error
    end.

maybe_delete_meta(DbName) ->
    {ok, Db} = ensure_meta_db_exists(),
    DocId = DbName,
    case couch_db:open_doc(Db, DocId, []) of
        {ok, Doc} ->
            Doc2 = Doc#doc{deleted=true},
            case (catch couch_db:update_doc(Db, Doc2, [full_commit])) of
                {ok, _} -> ok;
                Error ->
                    ?LOG_INFO("Can't delete the meta doc for the db: ~p. Error: ~p!~n", [DbName, Error]),
                    Error
            end;
        Error ->
            ?LOG_INFO("Can't find the meta doc for Db: ~p. Error: ~p!~n", [DbName, Error]),
            Error
    end. 

get_meta(DbName) ->
    {ok, Db} = ensure_meta_db_exists(),
    DocId = DbName,
    couch_db:open_doc(Db, DocId, []).

update_meta(DbName, Meta) ->
    ?LOG_INFO("Updating meta for Db ~p with: ~p~n", [DbName, Meta]),
    {ok, Db} = ensure_meta_db_exists(),
    DocId = DbName,
    case couch_db:open_doc(Db, DocId, [ejson_body]) of
        {ok, Doc} ->
            % updating the doc
            Body = Doc#doc.body,
            UpdatedBodyWithNewMeta = { update_doc_with(Body, Meta) },
            UpdatedBodyWithSystem  = update_system(DbName, UpdatedBodyWithNewMeta),
            Doc2 = Doc#doc{body=UpdatedBodyWithSystem},
            case (catch couch_db:update_doc(Db, Doc2, [full_commit])) of
                {ok, _} -> ok;
                Error ->
                    ?LOG_INFO("Can't update the meta doc for the db: ~p. Error: ~p!~n", [DbName, Error]),
                    Error
            end;
        Error ->
            ?LOG_INFO("Couldn't find the meta doc for the db ~p!", [DbName]),
            Error
    end.

ensure_meta_db_exists() ->
    DbName = ?l2b(couch_config:get("meta", "db", "rc_dbs")),
    case get_db(DbName) of
    {ok, Db} ->
        Db;
    _Error ->
        UserCtx = #user_ctx{roles = [<<"_admin">>, DbName]},
        {ok, Db} = couch_db:create(DbName, [sys_db, {user_ctx, UserCtx}])
    end,
    {ok, Db}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

create_default_meta_for_db(DbName) ->
    Now = ?l2b(httpd_util:rfc1123_date()),
    {[
        { ?SYSTEM_KEY, create_default_system_property(DbName, Now) }
    ]}.

create_default_system_property(DbName, Timestamp) ->
    create_system_property(DbName, Timestamp, Timestamp).

create_system_property(DbName, CreateTimestamp, UpdateTimestamp) ->
    {[
        { ?DB_KEY,              DbName          },
        { ?CREATED_KEY,         CreateTimestamp },
        { ?LAST_UPDATED_AT_KEY, UpdateTimestamp }
    ]}.

get_db(DbName) ->
    UserCtx = #user_ctx{roles = [<<"_admin">>, DbName]},
    couch_db:open_int(DbName, [sys_db, {user_ctx, UserCtx}]).

update_doc_with({DocBody}, {KVs}) ->
    lists:foldl(
        fun ({?SYSTEM_KEY, _}, Body) ->
                % ignoring any system property: reserved
                Body;
            ({?COUCH_ID_KEY, _}, Body) ->
                % ignoring _id: can't be changed
                Body;
            ({?COUCH_REV_KEY, _}, Body) ->
                % ignoring _rev: can't be changed
                Body;
            ({K, undefined}, Body) ->
                lists:keydelete(K, 1, Body);
            ({K, _V} = KV, Body) ->
                lists:keystore(K, 1, Body, KV) 
        end,
        DocBody,
        KVs
    ).

update_property(Props, Key, Value) ->
    case lists:keymember(Key, 1, Props) of
        false ->
            lists:keystore(Key, 1, Props, {Key, Value});
        true  ->
            lists:keyreplace(Key, 1, Props, {Key, Value})
    end.

update_system(DbName, {Meta}) ->
    Now = ?l2b(httpd_util:rfc1123_date()),

    case lists:keymember(?SYSTEM_KEY, 1, Meta) of
        false ->
            % no system prop :-/
            ?LOG_INFO("No system property for meta doc ~p! Repairing!~n", [DbName]),
            DefaultSystemProp = create_system_property(DbName, <<"unknown">>, Now),
            UpdatedMeta = update_property(Meta, ?SYSTEM_KEY, DefaultSystemProp),
            {UpdatedMeta};
        true  ->
            {?SYSTEM_KEY, Value} = lists:keyfind(?SYSTEM_KEY, 1, Meta),
            case Value of
                {Props} ->
                    % updating the last_updated_at property with the timestamp
                    UpdatedProps = update_property(Props, ?LAST_UPDATED_AT_KEY, Now),
                    UpdatedMeta = update_property(Meta, ?SYSTEM_KEY, {UpdatedProps}),
                    {UpdatedMeta};
                _ ->
                    % system seems corrupted .. time to repair
                    ?LOG_INFO("Wrong system property for meta doc ~p! Repairing!~n", [DbName]),
                    DefaultSystemProp = create_system_property(DbName, <<"unknown">>, Now),
                    UpdatedMeta = update_property(Meta, ?SYSTEM_KEY, DefaultSystemProp),
                    {UpdatedMeta}
            end
    end.

