{-# LANGUAGE OverloadedStrings #-}

module GoogleDrive where

import Control.Monad.IO.Class
import Control.Monad.Trans.Maybe     (MaybeT (..), runMaybeT)
import Data.Aeson
import Data.ByteString.Lazy          (ByteString)
import Data.Foldable                 (fold)
import Data.Monoid                   ((<>))
import Data.Text                     (pack)
import Database
import GHC.Generics                  (Generic)
import GoogleDrive.OAuth
import GoogleDrive.Types
import Network.HTTP.Simple
import Snap.Core                     (Method (..), method, writeLBS)
import Snap.Snaplet
import Snap.Snaplet.PostgresqlSimple
import System.Environment            (lookupEnv)
import System.Exit                   (exitFailure)

-- Config

getGDriveConfig :: MonadIO m => m (Maybe Config)
getGDriveConfig = liftIO . runMaybeT $ do
  cId <- MaybeT $ lookupEnv "CLIENT_ID"
  cSc <- MaybeT $ lookupEnv "CLIENT_SECRET"
  rDu <- MaybeT $ lookupEnv "REDIRECT_URI"
  return $ Config (pack cId) (pack cSc) (pack rDu)

loadGDriveConfig :: MonadIO m => m Config
loadGDriveConfig =
  getGDriveConfig >>= maybe fail return
  where
    fail   = liftIO $ putStrLn errMsg >> exitFailure
    errMsg = "please set CLIENT_ID, CLIENT_SECRET & REDIRECT_URI env vars"


-- Snaplet Init

gDriveInit :: SnapletInit b GoogleDrive
gDriveInit = makeSnaplet "google-drive" "google drive snaplet" Nothing $ do
  gDriveConfig <- loadGDriveConfig
  dbConfig     <- liftIO pgsConfig
  d            <- nestSnaplet "db" db $ pgsInit' dbConfig
  addRoutes [ ("/sign-in",       method GET $ signInHandler gDriveConfig)
            , ("/redirect-auth", method GET $ redirectHandler gDriveConfig)
            , ("/auth-success",  method GET authSuccessHandler)
            ]
  return $ GoogleDrive d
