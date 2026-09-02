module Erl.Stdlib.FileLib
  ( mkTempDir
  , mkTempFile
  , tmpDir
  , isDir
  , ensureDir
  , ensurePath
  ) where

import Prelude

import Data.Bifunctor (lmap)
import Data.Either (Either)
import Effect (Effect)
import Erl.Kernel.File (FileError, fileErrorToPurs)
import Erl.Kernel.Filename (Filename, rawFilename)
import Erl.Data.Binary (Binary)
import Foreign (Foreign)

mkTempDir :: Effect Filename
mkTempDir = rawFilename <$> mkTempDir_

mkTempFile :: Effect Filename
mkTempFile = rawFilename <$> mkTempFile_

tmpDir :: Effect Filename
tmpDir = rawFilename <$> tmpDir_

isDir :: Filename -> Effect Boolean
isDir = isDir_

-- | Creates the named directory and every parent it needs. This is
-- | `filelib:ensure_path/1`, and it is almost certainly the one you want.
ensurePath :: Filename -> Effect (Either FileError Unit)
ensurePath = (map $ lmap fileErrorToPurs) <<< ensurePath_

-- | `filelib:ensure_dir/1`: creates the directory that will *contain* the
-- | given name, and its parents. Takes a file or a directory, and the trailing
-- | separator is how you say which:
-- |
-- | ```
-- | ensureDir "/a/b/c"    -- a file: creates /a/b
-- | ensureDir "/a/b/c/"   -- a directory: creates /a/b/c
-- | ```
-- |
-- | The name is OTP's and stays OTP's. This used to take a pathy `Dir`, and
-- | printing a `Dir` always appended the separator, so callers got the second
-- | form without having to think about it; a `Filename` carries whatever it was
-- | given, so a caller meaning a directory has to keep the separator on. See
-- | `ensurePath` for the form that does not depend on it.
ensureDir :: Filename -> Effect (Either FileError Unit)
ensureDir = (map $ lmap fileErrorToPurs) <<< ensureDir_

foreign import mkTempFile_ :: Effect Binary
foreign import mkTempDir_ :: Effect Binary
foreign import tmpDir_ :: Effect Binary
foreign import isDir_ :: Filename -> Effect Boolean
foreign import ensurePath_ :: Filename -> Effect (Either Foreign Unit)
foreign import ensureDir_ :: Filename -> Effect (Either Foreign Unit)
