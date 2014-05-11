{-# LANGUAGE OverloadedStrings, ScopedTypeVariables, DataKinds #-}
module Npm.Latest.Internal (
    extractVersion,
    buildRequest,
    makeVersionRequest
) where

import Control.Lens ((^?), _Right)
import Control.Exception (catchJust)
import Control.Monad (guard)
import Control.Monad.Trans.State.Strict (evalStateT)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe (fromMaybe)
import Data.Aeson (json', Value)
import Data.Aeson.Lens (key, _String, AsValue)
import Data.Text.Format (Format, format)
import Network.URI (escapeURIString, isUnreserved)
import Network.HTTP.Client (HttpException(StatusCodeException))
import Pipes.Attoparsec (parse, ParsingError)
import Pipes.HTTP (parseUrl, withManager, tlsManagerSettings, withHTTP, responseBody, Request, Manager)

import qualified Data.Text as T
import qualified Data.Text.Lazy as TL

data NpmError = HttpError HttpException | JsonError ParsingError

extractVersion :: AsValue s => Maybe (Either t s) -> Maybe T.Text
extractVersion json =
    json >>= (^? _Right . key "version" . _String)

buildRequest :: String -> Format -> IO Request
buildRequest name urlFormat =
    parseUrl $ TL.unpack $ format urlFormat [escapeURIString isUnreserved name]

makeVersionRequest :: Request -> IO (Either ParsingError Value)
makeVersionRequest req = undefined
    -- withManager tlsManagerSettings $ \mngr -> executeHTTPRequest req mngr

executeHTTPRequest :: Request -> Manager -> IO (Either NpmError Value)
executeHTTPRequest req mngr = do
     -- TODO: simplify
     catchJust (guard . isStatusCodeException)
               (withHTTP req mngr $ \resp -> parseResponse resp >>=
                return . unwrapMaybe)
               (\ex -> return $ Left $ HttpError (ex :: HttpException))
     where
        unwrapMaybe :: Maybe (Either a Value) -> Either a Value
        unwrapMaybe v = fromMaybe (Right "nothing") v

        parseResponse resp = evalStateT (parse json') (responseBody resp)

isStatusCodeException :: HttpException -> Bool
isStatusCodeException (StatusCodeException _ _ _) = True
isStatusCodeException _ = False
