module Test.Main where

import Prelude

import Control.Monad.Free (Free)
import Data.Either (isRight)
import Data.Maybe (Maybe, fromMaybe')
import Effect (Effect)
import Effect.Class (liftEffect)
import Erl.Kernel.Filename (Filename, filename, filenameToString)
import Erl.Stdlib.FileLib (ensureDir, ensurePath, isDir, mkTempDir, tmpDir)
import Erl.Test.EUnit (TestF, runTests, suite, test)
import Partial.Unsafe (unsafeCrashWith)
import Test.Assert (assertEqual, assertTrue)

main :: Effect Unit
main = void $ runTests fileLibTests

fileLibTests :: Free TestF Unit
fileLibTests =
  suite "filelib tests" do
    test "mkTempDir makes a directory that is one" $ liftEffect do
      tmp <- mkTempDir
      assertTrue =<< isDir tmp

    test "tmpDir is a directory" $ liftEffect do
      t <- tmpDir
      assertTrue =<< isDir t

    test "ensurePath creates the directory it is named, and its parents" $ liftEffect do
      base <- pathOf =<< mkTempDir
      let target = fn $ base <> "/a/b/c"
      res <- ensurePath target
      assertTrue $ isRight res
      assertTrue =<< isDir (fn $ base <> "/a/b")
      assertTrue =<< isDir target

    -- ensureDir creates the *container* of what it is given, so the trailing
    -- separator is load-bearing: it is how the caller says "this name is a
    -- directory". Passing a pathy Dir used to supply it automatically.
    test "ensureDir without a trailing separator treats the name as a file" $ liftEffect do
      base <- pathOf =<< mkTempDir
      let target = fn $ base <> "/x/y/z"
      res <- ensureDir target
      assertTrue $ isRight res
      assertTrue =<< isDir (fn $ base <> "/x/y")
      madeTarget <- isDir target
      assertEqual { expected: false, actual: madeTarget }

    test "ensureDir with a trailing separator creates the named directory" $ liftEffect do
      base <- pathOf =<< mkTempDir
      res <- ensureDir (fn $ base <> "/p/q/r/")
      assertTrue $ isRight res
      assertTrue =<< isDir (fn $ base <> "/p/q/r")

fn :: String -> Filename
fn = unsafeFromJust "must be a valid filename" <<< filename

pathOf :: Filename -> Effect String
pathOf = pure <<< unsafeFromJust "temp dir must be valid UTF-8" <<< filenameToString

unsafeFromJust :: forall a. String -> Maybe a -> a
unsafeFromJust s = fromMaybe' (\_ -> unsafeCrashWith s)
