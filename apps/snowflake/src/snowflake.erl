%%%-------------------------------------------------------------------
%%% @author 10621
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 24. 三月 2020 10:44
%%%-------------------------------------------------------------------
-module(snowflake).
-author("10621").

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).
-export([get_uuid/0]).

-define(SERVER, ?MODULE).
-define(START_TIME, 1584979200).
-define(MILLISECOND_MAX, 4095).

-define(SEQUENCE_BIT, 12).
-define(MACHINE_BIT, 10).
-define(TIMESTAMP_BIT, 41).

-record(state, {
    last_timestamp = 0
    ,last_id = 0
    ,machine_id = 0
}).

%%%===================================================================
%%% API
%%%===================================================================
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
init([]) ->
    LastTimestamp = erlang:system_time(millisecond),
    LastId = 0,
    {ok, MachineId} = application:get_env(node_id),
    {ok, #state{
        last_timestamp = LastTimestamp
        ,last_id = LastId
        ,machine_id = list_to_integer(MachineId)
    }}.

handle_call(Request, From, State) ->
    try
        do_handle_call(Request, From, State)
    catch
        _E:_R:S ->
            {reply, S, State}
    end.

do_handle_call(get_uuid, _From, #state{last_timestamp = LastTimestamp,last_id = LastId,machine_id = MachineId} = State) ->
    NowTime = erlang:system_time(millisecond),
    {NewLastTimestamp, NewLastId} =
        case NowTime =:= LastTimestamp of
            true ->
                case LastId >= ?MILLISECOND_MAX of
                    true ->
                        throw(error_limit);
                    _ ->
                        {LastTimestamp, LastId + 1}
                end;
            _ ->
                {NowTime, 1}
        end,
    Res = NewLastId +
        (NewLastTimestamp bsl ?SEQUENCE_BIT) +
        (MachineId bsl (?SEQUENCE_BIT + ?MACHINE_BIT)) +
        (1 bsl (?SEQUENCE_BIT + ?MACHINE_BIT + ?TIMESTAMP_BIT)),
    {reply, Res, State#state{last_timestamp = NewLastTimestamp,last_id = NewLastId}};
do_handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
get_uuid() ->
    gen_server:call(?MODULE, get_uuid).