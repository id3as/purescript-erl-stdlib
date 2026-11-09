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
%% release.
%%
%% Both are created exclusively (O_CREAT|O_EXCL for a file, mkdir(2) for a
%% directory), so nothing already there is ever reused. The mode is then set
%% to mktemp's (0600 for a file, 0700 for a directory) straight after that
%% create. That is not mktemp's create-with-mode: until change_mode lands,
%% the entry has the umask's mode (typically 0644 / 0755), but in that window
%% the file is still empty, and the directory is an empty one that others can
%% list but not write to. If the mode cannot be set, the entry is removed
%% before raising, so a failed call leaves nothing behind.
%%
%% The name returned is absolute. Failure raises, as an empty name must never
%% reach rawFilename.
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
    ok -> toBinary(Path);
    {error, eexist} -> mkTemp(Create, Dir, N - 1);
    {error, Reason} -> erlang:error({mktemp, failed, Dir, Reason})
  end.

createFile(Path) ->
  %% exclusive is O_CREAT|O_EXCL: it fails with eexist rather than open
  %% something that is already there.
  case file:open(Path, [write, exclusive, raw]) of
    {ok, Fd} ->
      ok = file:close(Fd),
      restrict(Path, 8#600, fun file:delete/1);
    {error, _} = Err -> Err
  end.

createDir(Path) ->
  case file:make_dir(Path) of
    ok -> restrict(Path, 8#700, fun file:del_dir/1);
    {error, _} = Err -> Err
  end.

restrict(Path, Mode, Remove) ->
  case os:type() of
    {unix, _} ->
      case file:change_mode(Path, Mode) of
        ok -> ok;
        {error, Reason} ->
          _ = Remove(Path),
          erlang:error({mktemp, failed, Path, Reason})
      end;
    _ -> ok
  end.

%% One strong random byte per character. 62 does not divide 256, so bytes of
%% 248 and above are drawn again rather than folded in, which would favour
%% the first eight characters.
randomSuffix(Len) ->
  randomSuffix(Len, []).

randomSuffix(0, Acc) ->
  Acc;
randomSuffix(Len, Acc) ->
  case crypto:strong_rand_bytes(1) of
    <<B>> when B < 248 ->
      Chars = <<"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789">>,
      randomSuffix(Len - 1, [binary:at(Chars, B rem 62) | Acc]);
    _ ->
      randomSuffix(Len, Acc)
  end.

%% os:getenv/1 returns code points, which list_to_binary/1 rejects (badarg)
%% past Latin-1. Filenames here are UTF-8, as the emulator encodes them.
toBinary(Name) ->
  case unicode:characters_to_binary(Name) of
    Bin when is_binary(Bin) -> Bin;
    Err -> erlang:error({unencodable_filename, Name, Err})
  end.

tmpDir_() ->
  fun() -> toBinary(tmpDir_raw()) end.

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
