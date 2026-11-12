-module(erl_stdlib_fileLib@foreign).

-export([ mkTempFile_/0
        , mkTempDir_/0
        , tmpDir_/0
        , isDir_/1
        , ensurePath_/1
        , ensureDir_/1
        ]).

%% On unix, temp files and directories come from mktemp, so they are created
%% atomically with mode 0600 (file) or 0700 (directory). Erlang cannot do that
%% itself: file:open/make_dir take no mode and Erlang cannot set the umask, so
%% create-then-chmod leaves a window in which another user can open the entry.
%%
%% The template is explicit and absolute, `<tmpDir>/pserl.XXXXXXXX`, which GNU
%% and BSD mktemp read the same way. `mktemp -t` is not portable: GNU takes it
%% as a flag meaning "under $TMPDIR", BSD (macOS) takes the next word as a
%% prefix, so the old `mktemp -t -q pserl.XXXXXXXX` made its file relative to
%% the working directory there, which for a release is the release root
%% (id3as/norsk#969). mktemp is run directly, not through a shell, so the
%% directory name is never interpolated.
mkTempFile_() -> fun() -> mkTemp(file) end.

mkTempDir_() -> fun() -> mkTemp(dir) end.

mkTemp(Kind) ->
  case os:type() of
    {unix, _} -> mkTempUnix(Kind);
    _ -> mkTempOther(Kind, 100)
  end.

mkTempUnix(Kind) ->
  Exe = case os:find_executable("mktemp") of
          false -> erlang:error({mktemp, not_found});
          E -> E
        end,
  Template = filename:join(tmpDirName(), "pserl.XXXXXXXX"),
  Flags = case Kind of
            file -> ["-q"];
            dir -> ["-q", "-d"]
          end,
  Port = open_port({spawn_executable, Exe},
                   [{args, Flags ++ ["--", Template]},
                    binary, exit_status, use_stdio, hide]),
  %% `mktemp -q` is silent on failure, so the exit status is what says it
  %% failed; an empty name is rejected as well, because the PureScript side
  %% wraps this with rawFilename, and "" is not a name.
  case collect(Port, <<>>) of
    {0, Out} ->
      case string:trim(Out, trailing, "\n") of
        <<>> -> erlang:error({mktemp, failed});
        Name -> Name
      end;
    {_, _} -> erlang:error({mktemp, failed})
  end.

collect(Port, Acc) ->
  receive
    {Port, {data, Data}} -> collect(Port, <<Acc/binary, Data/binary>>);
    {Port, {exit_status, Status}} -> {Status, Acc}
  end.

%% Off unix there is no mktemp, and no owner-only mode to give: the name is
%% made exclusively (an existing one is retried, never reused) under tmpDir.
mkTempOther(_Kind, 0) ->
  erlang:error({mktemp, failed});
mkTempOther(Kind, Tries) ->
  Path = filename:join(tmpDirName(), "pserl." ++ randomSuffix()),
  Made = case Kind of
           file ->
             case file:open(Path, [write, exclusive, raw]) of
               {ok, Fd} -> file:close(Fd);
               Error -> Error
             end;
           dir -> file:make_dir(Path)
         end,
  case Made of
    ok -> unicode:characters_to_binary(Path);
    {error, eexist} -> mkTempOther(Kind, Tries - 1);
    {error, Reason} -> erlang:error({mktemp, Reason})
  end.

randomSuffix() ->
  B = base64:encode(crypto:strong_rand_bytes(12)),
  [C || <<C>> <= B, C =/= $/, C =/= $+].

tmpDir_() ->
  fun() -> unicode:characters_to_binary(tmpDirName()) end.

tmpDirName() ->
  case os:type() of
    {unix, _} ->
      %% An exported-but-empty TMPDIR is not false, and must not be taken
      %% as a directory name.
      case os:getenv("TMPDIR") of
        false -> "/tmp";
        "" -> "/tmp";
        Val -> Val
      end;
    _ ->
      case {os:getenv("TEMP"), os:getenv("TMP")} of
        {T, _} when T =/= false, T =/= "" -> T;
        {_, T} when T =/= false, T =/= "" -> T;
        _ ->
          %% If there's a better choice, please PR!
          {ok, Cwd} = file:get_cwd(),
          Cwd
      end
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
