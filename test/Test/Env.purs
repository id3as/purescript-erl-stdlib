-- | Test-only access to the process environment and the filesystem, so the
-- | temp-file tests can point TMPDIR somewhere they own and look at what was
-- | made there.
module Test.Env
  ( withEnv
  , freshDir
  , parentDir
  , normalise
  , isRegularFile
  , cwdNamesStartingWith
  , modeBits
  , removeAll
  , leftInMailboxTrappingExits
  ) where

import Prelude (Unit)

import Data.Tuple (Tuple)

import Data.Maybe (Maybe)
import Effect (Effect)
import Erl.Kernel.Filename (Filename)

-- | Runs the action with the variable set (or unset, given Nothing), and puts
-- | back whatever was there before, even if the action throws.
foreign import withEnv :: forall a. String -> Maybe String -> Effect a -> Effect a

-- | A new, empty directory that nothing under test made, so a test can point
-- | TMPDIR at it.
foreign import freshDir :: Effect String

-- | `filename:dirname/1`.
foreign import parentDir :: Filename -> String

-- | The name without a trailing separator (`filename:join/1` of it alone).
foreign import normalise :: String -> String

foreign import isRegularFile :: Filename -> Effect Boolean

-- | How many names in the current working directory start with the prefix.
foreign import cwdNamesStartingWith :: String -> Effect Int

-- | The permission bits (mode band 8#777) of the named file or directory.
foreign import modeBits :: Filename -> Effect Int

-- | Deletes the file, or the directory and everything in it.
foreign import removeAll :: Filename -> Effect Unit

-- | Runs the action in a fresh process that traps exits, and gives back its
-- | result and how many messages were left in that process's mailbox shortly
-- | afterwards.
foreign import leftInMailboxTrappingExits :: forall a. Effect a -> Effect (Tuple a Int)
