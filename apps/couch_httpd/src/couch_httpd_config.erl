%% @doc module to keep couch_httpd config
%%
-module(couch_httpd_config).

-behaviour(gen_server).

-export([set_protocol_options/0, get_protocol_options/1,
         set_protocol_options/2,
         restart_httpd/0, restart_listener/1,
         start_listener/1, stop_listener/1]).

-export([start_link/0, config_change/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).


set_protocol_options() ->
    {ok, Options} = couch_httpd:get_protocol_options(),
    lists:foreach(fun(Binding) ->
                set_protocol_options(Binding, Options)
        end, couch_httpd:get_bindings()).

restart_httpd() ->
    lists:foreach(fun(Binding) ->
                restart_listener(Binding)
        end, couch_httpd:get_bindings()).

restart_listener(Ref) ->
    stop_listener(Ref),
    supervisor:start_child(ranch_sup, couch_httpd:child_spec(Ref)).


start_listener(Ref) ->
    supervisor:start_child(ranch_sup, couch_httpd:child_spec(Ref)).

stop_listener(Ref) ->
	ranch:stop_listener(Ref).


%% @doc Return the current protocol options for the given listener.
-spec get_protocol_options(any()) -> any().
get_protocol_options(Ref) ->
    ranch:get_protocol_options(Ref).

%% @doc Upgrade the protocol options for the given listener.
%%
%% The upgrade takes place at the acceptor level, meaning that only the
%% newly accepted connections receive the new protocol options. This has
%% no effect on the currently opened connections.
-spec set_protocol_options(any(), any()) -> ok.
set_protocol_options(Ref, ProtoOpts) ->
    ranch:set_protocol_options(Ref, ProtoOpts).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_) ->
    %% register to config changes
    ok = couch_config:register(fun ?MODULE:config_change/2),
    {ok, nil}.

handle_call(_Msg, _From, State) ->
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

config_change("httpd", "bind_address") ->
    restart_httpd();
config_change("httpd", "port") ->
    restart_listener(http);
config_change("httpd", "default_handler") ->
    set_protocol_options();
config_change("httpd", "server_options") ->
    set_protocol_options();
config_change("httpd", "socket_options") ->
    set_protocol_options();
config_change("httpd", "authentication_handlers") ->
    couch_httpd:set_auth_handlers();
config_change("httpd_global_handlers", _) ->
    set_protocol_options();
config_change("httpd_db_handlers", _) ->
    set_protocol_options();
config_change("ssl", _) ->
    restart_listener(https).
