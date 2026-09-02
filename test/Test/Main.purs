module Test.Main where

import Prelude

import Control.Monad.Free (Free)
import Data.Either (Either(..), isLeft, isRight)
import Data.Maybe (Maybe(..), fromMaybe')
import Effect (Effect)
import Effect.Class (liftEffect)
import Erl.Kernel.Filename (Filename, filename, filenameToString)
import Erl.Stdlib.FileLib (ensureDir, ensurePath, isDir, mkTempDir, tmpDir)
import Erl.Stdlib.UriString as UriString
import Erl.Test.EUnit (TestF, runTests, suite, test)
import Partial.Unsafe (unsafeCrashWith)
import Test.Assert (assertEqual, assertTrue)

main :: Effect Unit
main = void $ runTests do
  fileLibTests
  uriStringTests

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

uriStringTests :: Free TestF Unit
uriStringTests =
  suite "uri_string tests" do
    suite "resolve" do
      test "a bare name resolves against the base's directory" do
        assertEqual
          { expected: Right "https://cdn.example.com/720/seg0.ts"
          , actual: UriString.resolve "seg0.ts" "https://cdn.example.com/720/index.m3u8"
          }

      -- The reason this module exists: the .. that a filesystem path parser
      -- must reject is ordinary in an HLS playlist, and RFC 3986 resolves it
      -- rather than failing.
      test "dot segments resolve" do
        assertEqual
          { expected: Right "https://cdn.example.com/video/seg.ts"
          , actual: UriString.resolve "../video/seg.ts" "https://cdn.example.com/720/index.m3u8"
          }

      test "ascending past the root clamps rather than failing" do
        assertEqual
          { expected: Right "https://cdn.example.com/x"
          , actual: UriString.resolve "../../../x" "https://cdn.example.com/720/index.m3u8"
          }

      test "the query comes from the reference, not the base" do
        assertEqual
          { expected: Right "https://cdn.example.com/720/seg.ts?tok=1"
          , actual: UriString.resolve "seg.ts?tok=1" "https://cdn.example.com/720/index.m3u8?old=9"
          }

      test "an absolute reference replaces the base entirely" do
        assertEqual
          { expected: Right "http://other:8080/x/y.ts"
          , actual: UriString.resolve "http://other:8080/x/y.ts" "https://cdn.example.com/720/index.m3u8"
          }

      test "a base with no scheme is an error, not a crash" do
        assertTrue $ isLeft $ UriString.resolve "seg.ts" "/720/index.m3u8"

    suite "parse" do
      test "every component" do
        assertEqual
          { expected: Right
              { scheme: Just "http"
              , userinfo: Just "u:pw"
              , host: Just "h"
              , port: Just 8080
              , path: "/a/b"
              , query: Just "q=1"
              , fragment: Just "f"
              }
          , actual: UriString.parse "http://u:pw@h:8080/a/b?q=1#f"
          }

      test "an absent port is Nothing, not a default" do
        assertEqual
          { expected: Right (Just "h")
          , actual: _.host <$> UriString.parse "http://h/a"
          }
        assertEqual
          { expected: Right Nothing
          , actual: _.port <$> UriString.parse "http://h/a"
          }

      -- "?" with nothing after it is a present-but-empty query, and has to
      -- stay distinguishable from no query at all: a caller reassembling the
      -- URI has to put the "?" back.
      test "an empty query is present, an absent one is not" do
        assertEqual
          { expected: Right (Just "")
          , actual: _.query <$> UriString.parse "http://h/a?"
          }
        assertEqual
          { expected: Right Nothing
          , actual: _.query <$> UriString.parse "http://h/a"
          }

      test "a bare path is a URI reference with nothing else in it" do
        assertEqual
          { expected: Right "a/b.ts"
          , actual: _.path <$> UriString.parse "a/b.ts"
          }

      test "malformed input is a Left" do
        assertTrue $ isLeft $ UriString.parse "::::"

      -- OTP raises function_clause on a non-ASCII byte rather than returning
      -- an error; the binding has to turn that into the Left the type says.
      test "a non-ASCII byte is a Left, not a crash" do
        assertTrue $ isLeft $ UriString.parse "http://h/\xe4"

    suite "recompose" do
      test "round-trips a parse" do
        assertEqual
          { expected: Right (Right "https://h:8443/a/b?q=1")
          , actual: UriString.recompose <$> UriString.parse "https://h:8443/a/b?q=1"
          }

      -- An authority with no scheme is legal ("//h"); a port with no host is
      -- not, and OTP raises rather than returning an error for it, so this is
      -- the guard on the recompose side.
      test "a port with no host is a Left, not a crash" do
        assertTrue $ isLeft $ UriString.recompose
          { scheme: Nothing
          , userinfo: Nothing
          , host: Nothing
          , port: Just 80
          , path: "a"
          , query: Nothing
          , fragment: Nothing
          }

    suite "normalize" do
      test "lowercases the scheme and host and removes dot segments" do
        assertEqual
          { expected: Right "http://host/b/c"
          , actual: UriString.normalize "HTTP://HOST/a/../b/./c"
          }

fn :: String -> Filename
fn = unsafeFromJust "must be a valid filename" <<< filename

pathOf :: Filename -> Effect String
pathOf = pure <<< unsafeFromJust "temp dir must be valid UTF-8" <<< filenameToString

unsafeFromJust :: forall a. String -> Maybe a -> a
unsafeFromJust s = fromMaybe' (\_ -> unsafeCrashWith s)
