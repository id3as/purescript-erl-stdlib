-module(erl_stdlib_fileLib@foreign).

-export([ mkTempFile_/0
        , mkTempDir_/0
        , tmpDir_/0
        , isDir_/1
        , ensurePath_/1
        , ensureDir_/1
        ]).

%% Temp files and directories are made here, in Erlang, under tmpDir_ -- not by
%% shelling out to mktemp. `mktemp -t` is not portable: GNU takes -t as a flag
%% meaning "under $TMPDIR", BSD (macOS) takes the next word as a prefix, so the
%% old `mktemp -t -q pserl.XXXXXXXX` made its file relative to the working
%% directory there, which for a release is the release root (id3as/norsk#969).
%% Like mktemp, the name is pserl. and eight random alphanumerics, it is made
%% exclusively (an existing name is retried, never reused), and it is private
%% to the owner: 0600 for a file, 0700 for a directory.
mkTempFile_() -> fun() -> mkTemp(fun makeFile/1) end.

mkTempDir_() -> fun() -> mkTemp(fun makeDir/1) end.

mkTemp(Make) -> mkTemp(Make, 100).

mkTemp(_Make, 0) ->
  erlang:error({mktemp, failed});
mkTemp(Make, Tries) ->
  Path = filename:join(tmpDirName(), "pserl." ++ randomSuffix(8)),
  case Make(Path) of
    ok -> unicode:characters_to_binary(Path);
    {error, eexist} -> mkTemp(Make, Tries - 1);
    {error, Reason} -> erlang:error({mktemp, Reason})
  end.

makeFile(Path) ->
  case file:open(Path, [write, exclusive, raw]) of
    {ok, Fd} ->
      ok = file:close(Fd),
      file:change_mode(Path, 8#600);
    Error -> Error
  end.

makeDir(Path) ->
  case file:make_dir(Path) of
    ok -> file:change_mode(Path, 8#700);
    Error -> Error
  end.

randomSuffix(N) ->
  Chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
  [lists:nth(rand:uniform(length(Chars)), Chars) || _ <- lists:seq(1, N)].

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
      case os:getenv("TEMP") of
        false ->
          %% If there's a better choice, please PR!
          {ok, Cwd} = file:get_cwd(),
          Cwd;
        Val -> Val
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
