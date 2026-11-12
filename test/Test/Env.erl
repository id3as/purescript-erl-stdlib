-module(test_env@foreign).

-include_lib("kernel/include/file.hrl").

-export([withEnv/3, freshDir/0, parentDir/1, normalise/1, isRegularFile/1,
         cwdNamesStartingWith/1, modeBits/1]).

withEnv(Name, Value, Action) ->
  fun() ->
    Var = binary_to_list(Name),
    Old = os:getenv(Var),
    set(Var, Value),
    try Action()
    after
      case Old of
        false -> os:unsetenv(Var);
        _ -> os:putenv(Var, Old)
      end
    end
  end.

set(Var, {just, V}) -> os:putenv(Var, binary_to_list(V));
set(Var, {nothing}) -> os:unsetenv(Var).

freshDir() ->
  fun() ->
    Base = case os:getenv("TMPDIR") of
             false -> "/tmp";
             "" -> "/tmp";
             T -> T
           end,
    Dir = filename:join(Base, "erl-stdlib-test-" ++ os:getpid() ++ "-"
                        ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = file:make_dir(Dir),
    unicode:characters_to_binary(Dir)
  end.

parentDir(Name) ->
  unicode:characters_to_binary(filename:dirname(Name)).

normalise(Name) ->
  unicode:characters_to_binary(filename:join([Name])).

isRegularFile(Name) ->
  fun() -> filelib:is_regular(Name) end.

cwdNamesStartingWith(Prefix) ->
  fun() ->
    {ok, Cwd} = file:get_cwd(),
    {ok, Names} = file:list_dir(Cwd),
    P = binary_to_list(Prefix),
    length([N || N <- Names, lists:prefix(P, N)])
  end.

modeBits(Name) ->
  fun() ->
    {ok, #file_info{mode = Mode}} = file:read_file_info(Name),
    Mode band 8#777
  end.
