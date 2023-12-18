module Erl.Stdlib.FileLib
  ( mkTemp
  , tmpDir
  , isDir
  , ensureDir
  ) where

import Prelude

import Data.Bifunctor (lmap)
import Data.Either (Either)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Erl.Kernel.File (FileError, dirToString, fileErrorToPurs)
import Erl.Types (SandboxedDir)
import Foreign (Foreign)
import Partial.Unsafe (unsafeCrashWith)
import Pathy (AbsDir, parseAbsDir, posixParser)

-- mkTemp_ and tmpDir_ return binaries which do not end with a path separator. Pathy expects directories to end with a path separator.
-- assertDir_ adds a path separator to the end of the string if it doesn't already have one.

mkTemp :: Effect AbsDir
mkTemp = do
  tmp <- mkTemp_
  case parseAbsDir posixParser $ assertDir_ tmp  of
    Just path -> pure path
    Nothing -> unsafeCrashWith "mkTemp will always return a good path"

tmpDir :: Effect AbsDir
tmpDir = do
  tmp <- tmpDir_
  case parseAbsDir posixParser $ assertDir_ tmp of
    Just path -> pure path
    Nothing -> unsafeCrashWith "tmpDir will always return a good path"

isDir
  :: SandboxedDir
  -> Effect Boolean
isDir = isDir_ <<< dirToString

ensureDir
  :: SandboxedDir
  -> Effect (Either FileError Unit)
ensureDir = (map $ lmap fileErrorToPurs) <<< ensureDir_ <<< dirToString

foreign import mkTemp_ :: Effect String
foreign import tmpDir_ :: Effect String
foreign import isDir_ :: String -> Effect Boolean
foreign import ensureDir_ :: String -> Effect (Either Foreign Unit)

foreign import assertDir_ :: String -> String

