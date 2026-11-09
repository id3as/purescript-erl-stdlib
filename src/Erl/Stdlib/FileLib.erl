-module(erl_stdlib_fileLib@foreign).

-export([ mkTempFile_/0
        , mkTempDir_/0
        , tmpDir_/0
        , isDir_/1
        , ensurePath_/1
        , ensureDir_/1
        ]).

%% Temp files and directories are made here, under tmpDir_/0, rather than by
%% shelling out to mktemp(1). GNU and BSD mktemp disagree on -t: BSD takes it
%% as the prefix argument, so `mktemp -t -q pserl.XXXXXXXX` made the file in
%% the current directory on macOS -- inside the release root, for a relx
%% release. Both are created exclusively, with mktemp's modes (0600 for a
%% file, 0700 for a directory), and an absolute name is returned; failure
%% raises, as an empty name must never reach rawFilename.
mkTempFile_() -> fun() -> mkTemp(fun createFile/1) end.

mkTempDir_() -> fun() -> mkTemp(fun createDir/1) end.

-define(TEMP_ATTEMPTS, 100).

mkTemp(Create) ->
  Dir = filename:absname(tmpDir_raw()),
  mkTemp(Create, Dir, ?TEMP_ATTEMPTS).

mkTemp(_Create, Dir, 0) ->
  erlang:error({mktemp, failed, Dir, eexist});
mkTemp(Create, Dir, N) ->
  Path = filename:join(Dir, "pserl." ++ randomSuffix(8)),
  case Create(Path) of
    ok -> erlang:list_to_binary(Path);
    {error, eexist} -> mkTemp(Create, Dir, N - 1);
    {error, Reason} -> erlang:error({mktemp, failed, Dir, Reason})
  end.

createFile(Path) ->
  %% exclusive is O_CREAT|O_EXCL: it fails with eexist rather than open
  %% something that is already there.
  case file:open(Path, [write, exclusive, raw]) of
    {ok, Fd} ->
      ok = file:close(Fd),
      restrict(Path, 8#600);
    {error, _} = Err -> Err
  end.

createDir(Path) ->
  case file:make_dir(Path) of
    ok -> restrict(Path, 8#700);
    {error, _} = Err -> Err
  end.

restrict(Path, Mode) ->
  case os:type() of
    {unix, _} ->
      case file:change_mode(Path, Mode) of
        ok -> ok;
        {error, Reason} -> erlang:error({mktemp, failed, Path, Reason})
      end;
    _ -> ok
  end.

randomSuffix(Len) ->
  Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
  N = length(Chars),
  [lists:nth(rand:uniform(N), Chars) || _ <- lists:seq(1, Len)].

tmpDir_() ->
  fun() -> erlang:list_to_binary(tmpDir_raw()) end.

tmpDir_raw() ->
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
