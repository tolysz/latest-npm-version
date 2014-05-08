{-# LANGUAGE OverloadedStrings #-}
module Npm.Latest.Internal (
    extractVersion,
    buildRequest,
    makeVersionRequest
) where

import Control.Lens ((^?), _Right)
import Control.Monad.Trans.State.Strict (evalStateT)
import Data.Aeson (json', Value)
import Data.Aeson.Lens (key, _String, AsValue)
import Data.Text.Format (Format, format)
import Network.URI (escapeURIString, isUnreserved)
import Pipes.Attoparsec (parse, ParsingError)
import Pipes.HTTP (parseUrl, withManager, tlsManagerSettings, withHTTP, responseBody, Request)

import qualified Data.Text as T
import qualified Data.Text.Lazy as TL

extractVersion :: AsValue s => Maybe (Either t s) -> Maybe T.Text
extractVersion json =
    json >>= (^? _Right . key "version" . _String)

buildRequest :: String -> Format -> IO Request
buildRequest name urlFormat =
    parseUrl $ TL.unpack $ format urlFormat [escapeURIString isUnreserved name]

makeVersionRequest :: Request -> IO (Maybe (Either ParsingError Value))
makeVersionRequest req =
    withManager tlsManagerSettings $ \mngr ->
        withHTTP req mngr $ \resp ->
            evalStateT (parse json') (responseBody resp)