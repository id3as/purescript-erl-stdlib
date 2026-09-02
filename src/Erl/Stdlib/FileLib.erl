-module(erl_stdlib_fileLib@foreign).

-export([ mkTempFile_/0
        , mkTempDir_/0
        , tmpDir_/0
        , isDir_/1
        , ensurePath_/1
        , ensureDir_/1
        ]).

%% `mktemp -q` is silent on failure and os:cmd gives back "", so the empty
%% result has to be rejected here: the PureScript side wraps this with
%% rawFilename, which is the raw channel for bytes that came off a filesystem,
%% and "" is neither those nor a name. Raising matches what callers got before
%% Filename existed (badarg out of binary:last/1 on the empty binary), and it
%% keeps rawFilename honest -- what it receives really is a path mktemp made.
mkTempFile_() -> fun() ->
  case os:type() of
    {unix, _} ->
      nonEmptyName(mktemp, os:cmd("mktemp -t -q pserl.XXXXXXXX"))
  end
end.

mkTempDir_() -> fun() ->
  case os:type() of
    {unix, _} ->
      nonEmptyName(mktemp, os:cmd("mktemp -t -d -q pserl.XXXXXXXX"));
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

nonEmptyName(What, Raw) ->
  case string:chomp(Raw) of
    "" -> erlang:error({What, failed});
    Name -> erlang:list_to_binary(Name)
  end.

tmpDir_() ->
  fun() ->
    R = case os:type() of
      {unix, _} ->
        %% An exported-but-empty TMPDIR is not false, and must not be taken
        %% as a directory name.
        case os:getenv("TMPDIR") of
            false -> "/tmp";
            "" -> "/tmp";
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

ensurePath_(Dir) ->
  fun() ->
    case filelib:ensure_path(Dir) of
      ok -> {right, unit};
      {error, Err} -> {left, Err}
    end
  end.

ensureDir_(File) ->
  fun() ->
    case filelib:ensure_dir(File) of
      ok -> {right, unit};
      {error, Err} -> {left, Err}
    end
  end.
