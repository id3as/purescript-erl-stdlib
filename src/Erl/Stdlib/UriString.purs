-- | RFC 3986 URI handling, bound from OTP's `uri_string` (stdlib).
-- |
-- | The reason this exists is `resolve`: reference resolution (RFC 3986 §5) is
-- | the one piece of URI handling that is fiddly to get right and that no
-- | PureScript package here provides. OTP has had it since OTP 22.
-- |
-- | Not bound: `quote`/`unquote`. They take and return *unicode chardata*, not
-- | UTF-8, so on a purerl `String` — which is a UTF-8 binary — they are a
-- | mojibake trap rather than a percent-codec. Measured on OTP 28:
-- | `quote "ä"` is `{error, invalid_input, "ä"}` (the UTF-8 bytes are not
-- | ASCII, so it refuses), and `unquote "%C3%A4"` is `"Ã¤"` (each escape
-- | becomes a codepoint, and the codepoints are then UTF-8 encoded). Anything
-- | wanting those should say what encoding it means at the call site.
module Erl.Stdlib.UriString
  ( Uri
  , UriError
  , parse
  , recompose
  , resolve
  , normalize
  ) where

import Data.Either (Either)
import Data.Maybe (Maybe)
import Erl.Atom (Atom)

-- | A URI decomposed into its RFC 3986 components.
-- |
-- | `path` is always present and may be empty (`parse "http://h"` gives `""`);
-- | every other component is `Nothing` when the URI does not carry it. `port`
-- | is also `Nothing` for the empty-but-present port in `//host:/p`, which OTP
-- | reports as the atom `undefined`.
type Uri =
  { scheme :: Maybe String
  , userinfo :: Maybe String
  , host :: Maybe String
  , port :: Maybe Int
  , path :: String
  , query :: Maybe String
  , fragment :: Maybe String
  }

-- | `reason` is OTP's error atom — `invalid_uri`, `invalid_scheme`,
-- | `invalid_map`, … — and `detail` the fragment of input it objected to.
type UriError = { reason :: Atom, detail :: String }

-- | Decompose a URI. Note this parses a URI *reference*: a bare `"a/b"` is
-- | accepted and yields nothing but a path.
foreign import parse :: String -> Either UriError Uri

-- | The inverse of `parse`. Fails (`invalid_map`) on a combination that is not
-- | a URI — an authority with no scheme, say.
foreign import recompose :: Uri -> Either UriError String

-- | `resolve reference base` — RFC 3986 §5 reference resolution, in OTP's
-- | argument order. The `base` must be absolute (it needs a scheme).
-- |
-- | Total over dot segments: `resolve "../v/s.ts" "http://h/a/b/p.m3u8"` is
-- | `"http://h/a/v/s.ts"`, and an ascent past the root clamps rather than
-- | failing. The query comes from the reference, not the base.
foreign import resolve :: String -> String -> Either UriError String

-- | Syntax-based normalisation (RFC 3986 §6.2.2): lowercases scheme and host,
-- | removes dot segments, decodes unreserved percent-escapes.
foreign import normalize :: String -> Either UriError String
