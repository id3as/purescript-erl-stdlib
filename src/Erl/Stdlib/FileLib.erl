-module(erl_stdlib_fileLib@foreign).

-export([ mkTemp_/0
        , tmpDir_/0
        , isDir_/1
        , ensureDir_/1
        ]).

mkTemp_() -> fun() ->
  case os:type() of
    {unix, _} ->
      erlang:list_to_binary(string:chomp(os:cmd("mktemp -t -d -q pserl.XXXXXXXX")));
    _ ->
      Temp = case os:getenv("TEMP") of
                false -> file:get_cwd();
                Val -> Val
             end,

      Rand = integer_to_list(base64:encode(crypto:strong_rand_bytes(16))),
      Path = filename:join(Temp, Rand),
      ok = filelib:ensure_dir(Path),
      erlang:list_to_binary(Path)
  end
end.

tmpDir_() ->
  fun() ->
    R = case os:type() of
      {unix, _} ->
        case os:getenv("TMPDIR") of
            false -> "/tmp";
            Val -> Val
        end;
      _ ->
        case os:getenv("TEMP") of
          false ->
            %% If there's a better choice, please PR!
            file:get_cwd();
          Val -> Val
        end
    end,
    erlang:list_to_binary(R)
  end.

isDir_(Dir) ->
  fun() ->
      filelib:is_dir(Dir)
  end.

ensureDir_(Dir) ->
  fun() ->
    case filelib:ensure_dir(Dir) of
      ok -> {right, unit};
      {error, Err} -> {left, Err}
    end
  end.

