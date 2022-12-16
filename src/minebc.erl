%%%-------------------------------------------------------------------
%%% @author user
%%% @copyright (C) 2022, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. Sep 2022 1:40 PM
%%%-------------------------------------------------------------------
-module(minebc).
-author("Ayesha Naikodi - Siju Sakaria").

-import(string,[equal/2,sub_string/3, copies/2]).

%% API
-export([hash/1, get_random_string/2, check/4, serverListen/3, server/2, startWorker/1, startServer/1, worker/1, workerListen/1, check/6, stop/0]).

hash(String) ->
  io_lib:format("~64.16.0b", [binary:decode_unsigned(crypto:hash(sha256, String))]).


get_random_string(Length, AllowedChars) ->
  lists:foldl(fun(_, Acc) ->
    [lists:nth(rand:uniform(length(AllowedChars)), AllowedChars)]
    ++ Acc
              end, [], lists:seq(1, Length)).


check(_,0,_,10000000) ->
  serverListen ! finished;
check(String,K, Zeros, Count) ->
  Nonce = get_random_string(rand:uniform(12),"qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890"),
  HashReturned = hash(String++Nonce),
  HashPrefix = sub_string(HashReturned,1,K),
  if
    HashPrefix == Zeros ->
      serverListen ! {found, String++Nonce, HashReturned},
      check(String,K, Zeros, Count+1);
%%   check(0,0,0, 10000000);
%%      io:fwrite("Hash found!\n"),
%%      io:fwrite("~p \t ~p\n",[String++Nonce, HashReturned]),
    true ->
%%      io:fwrite("Not found - String is: ~p\n", [String++Nonce]),
      check(String,K, Zeros, Count+1)
  end.


check(_,0,_,_,WorkerNode,10000000) ->
  WorkerNode ! finished;
check(String,K, Zeros, ServerNode,WorkerNode,Count) ->
  Nonce = get_random_string(rand:uniform(12),"qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890"),
  HashReturned = hash(String++Nonce),
  HashPrefix = sub_string(HashReturned,1,K),
  if
    HashPrefix == Zeros ->
      {serverListen,ServerNode} ! {found, String++Nonce, HashReturned},
%%      io:fwrite("Hash found! Sent to boss\n"),
%%      check(0,0,0,0,WorkerNode, 10000000);
      check(String,K, Zeros, ServerNode,WorkerNode,Count+1);
    true ->
%%      io:fwrite("Not found - String is: ~p\n", [String++Nonce]),
      check(String,K, Zeros, ServerNode,WorkerNode,Count+1)
  end.

calculateTimeTaken() ->
  {_, Time1} = statistics(runtime),
  {_, Time2} = statistics(wall_clock),
  [{_,X}] = ets:lookup(my_table, runtime),
  [{_,Y}] = ets:lookup(my_table, clock),

  io:format("Lookup runtime ~p , clock ~p~n",[X, Y]),

  io:format("New runtime ~p , clock ~p~n",[Time1, Time2]),

  RuntimeDiff = Time1 - X,
  ClockDiff = abs(Time2 - Y),
  U1 = RuntimeDiff/1000,
  U2 = ClockDiff/1000,
  Ratio = RuntimeDiff / ClockDiff,
  io:format("CPU time=~p Clock time(~p) seconds~nRatio=~p", [U1,U2, Ratio]).

server(String, K) ->
  Zeros = copies("0",K),
  spawn(minebc,check,[String, K, Zeros,1]),
  register(serverListen,spawn(minebc,serverListen,[String,K,Zeros])).

serverListen(String, K, Zeros) ->
  receive
    {givework,WorkerNode} ->
%%      io:fwrite("Got request for work from worker\n"),
      WorkerNode ! {work,String, K, Zeros},
      io:fwrite("Sent work to worker\n"),
      serverListen(String, K, Zeros);
    {found, StringRet, HashReturned} ->
      io:fwrite("~p \t ~p\n",[StringRet, HashReturned]),
      serverListen(String,K,Zeros);
    finished ->
      done
  end.

worker(ServerNode) ->
  PId = spawn(minebc,workerListen,[ServerNode]),
  {serverListen,ServerNode} ! {givework,PId}.

workerListen(ServerNode) ->
  receive
    {work,String,K,Zeros} ->
%%      io:fwrite("Got work to do!\n"),
      spawn(minebc,check,[String,K, Zeros,ServerNode,self(),1]),
      workerListen(ServerNode);
    finished ->
      done
  end.

startServer(K) ->
  {_, Time1} = statistics(runtime),
  {_, Time2} = statistics(wall_clock),
  io:format("CPU time=~p Clock time(~p) ms~n", [Time1,Time2]),

  ets:new(my_table, [named_table]),
  ets:insert(my_table, {runtime, Time1}),
  ets:insert(my_table, {clock, Time2}),

  spawn(minebc, server,["ma.naikodi", K]).

startWorker(ServerNode) ->
  spawn(minebc,worker,[ServerNode]).

stop() ->
  calculateTimeTaken(),
  halt().
