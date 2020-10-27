-module(worker).

-compile(export_all).

start(Addr, Port) ->
    register(?MODULE, Pid = spawn(?MODULE, init, [Addr, Port])),
    Pid.

start_link(Addr, Port) ->
    register(?MODULE, Pid = spawn_link(?MODULE, init, [Addr, Port])),
    Pid.

loop(Sock) ->
    receive
      {error, Msg} ->
          io:format("~s~p", Msg),
          exit(shutdown);
      {Pid, Ref, Cmd} ->
          gen_tcp:send(Sock, Cmd),
          {ok, Resp} = gen_tcp:recv(Sock, 0),
          Pid ! {Ref, list_to_binary(Resp)},
          loop(Sock)
    end.

init(Addr, Port) ->
    {ok, Sock} = gen_tcp:connect(Addr, Port, [{active, false}]),
    loop(Sock).

request(Raw) ->
    Ref = make_ref(),
    M = string:tokens(Raw, " "),
    Msg = list_to_binary(["*",
                          integer_to_list(length(M)),
                          "\r\n",
                          [["$", integer_to_list(length(X)), "\r\n", X, "\r\n"] || X <- M]]),
    ?MODULE ! {self(), Ref, Msg},
    receive
      {Ref, <<$+, Resp/binary>>} ->
          {string:tokens(binary_to_list(Resp), "\r\n")};
      {Ref, <<$$, Count/integer, "\r\n", Resp/binary>>} ->
          {Count, string:tokens(binary_to_list(Resp), "\r\n")};
      {Ref, <<$:, Resp/binary>>} ->
          {Resp};
      {Ref, <<$-, Resp/binary>>} ->
          {Resp};
      {Ref, Resp} ->
          {Resp}
      after 1000 ->
                timeout
    end.

