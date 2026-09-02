-module(erl_stdlib_uriString@foreign).

-export([ parse/1
        , recompose/1
        , resolve/2
        , normalize/1
        ]).

parse(Uri) ->
  guarded(fun() -> uri_string:parse(Uri) end, fun toRecord/1).

recompose(Uri) ->
  guarded(fun() -> uri_string:recompose(fromRecord(Uri)) end, fun id/1).

resolve(Reference, Base) ->
  guarded(fun() -> uri_string:resolve(Reference, Base) end, fun id/1).

normalize(Uri) ->
  guarded(fun() -> uri_string:normalize(Uri) end, fun id/1).

%% `uri_string` reports bad input two different ways, and both have to become
%% the same Left. It *returns* {error, Reason, Detail} for input it recognises
%% as malformed -- but it *raises* function_clause on a byte it has no clause
%% for, which on OTP 28 includes any non-ASCII byte (uri_string.erl:1186, via
%% parse_segment/2). A purerl String is a UTF-8 binary, so that is reachable
%% from ordinary PureScript -- a playlist naming a segment with an accented
%% character is enough -- and without the try it would take the caller down
%% rather than returning the Either the type promises.
guarded(Run, Ok) ->
  try Run() of
    {error, Reason, Detail} -> {left, err(Reason, Detail)};
    Result -> {right, Ok(Result)}
  catch
    Class:Reason -> {left, err(uncaught, io_lib:format("~p:~p", [Class, Reason]))}
  end.

id(X) -> X.

err(Reason, Detail) ->
  #{ reason => Reason, detail => detail(Detail) }.

detail(D) when is_binary(D) -> D;
detail(D) when is_list(D) ->
  case unicode:characters_to_binary(D) of
    B when is_binary(B) -> B;
    _ -> format(D)
  end;
detail(D) -> format(D).

format(D) -> erlang:iolist_to_binary(io_lib:format("~p", [D])).

%% A component OTP omitted is Nothing, and so is the empty-but-present port in
%% "//host:/p", which it reports as the atom `undefined`. Every component it
%% does give back is a binary (the input was one), so `undefined` is
%% unambiguous.
toRecord(M) ->
  #{ scheme => toMaybe(maps:get(scheme, M, undefined))
   , userinfo => toMaybe(maps:get(userinfo, M, undefined))
   , host => toMaybe(maps:get(host, M, undefined))
   , port => toMaybe(maps:get(port, M, undefined))
   , path => maps:get(path, M, <<>>)
   , query => toMaybe(maps:get(query, M, undefined))
   , fragment => toMaybe(maps:get(fragment, M, undefined))
   }.

fromRecord(R) ->
  maps:fold(fun (_K, {nothing}, Acc) -> Acc;
                (K, {just, V}, Acc) -> Acc#{K => V};
                (K, V, Acc) -> Acc#{K => V}
            end, #{}, R).

toMaybe(undefined) -> {nothing};
toMaybe(V) -> {just, V}.
