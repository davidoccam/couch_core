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

-module(couch_stats_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).


%% Helper macro for declaring children of supervisor
-define(CHILD(I), {I, {I, start_link, []}, permanent, 5000, worker, [I]}).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    Aggregator = ?CHILD(couch_stats_aggregator),
    Collector = ?CHILD(couch_stats_collector),
    {ok, {{one_for_one, 10, 3600}, [Aggregator, Collector]}}.
