module Hasura.Backends.MSSQL.DDL.Source
  ( resolveSourceConfig,
    resolveDatabaseMetadata,
    postDropSourceHook,
  )
where

import Control.Monad.Trans.Control (MonadBaseControl)
import Data.Environment qualified as Env
import Database.MSSQL.Transaction qualified as Tx
import Hasura.Backends.MSSQL.Connection
import Hasura.Backends.MSSQL.Meta
import Hasura.Base.Error
import Hasura.Prelude
import Hasura.RQL.Types.Common
import Hasura.RQL.Types.Source
import Hasura.RQL.Types.SourceCustomization
import Hasura.SQL.Backend

resolveSourceConfig ::
  (MonadIO m) =>
  SourceName ->
  MSSQLConnConfiguration ->
  Env.Environment ->
  m (Either QErr MSSQLSourceConfig)
resolveSourceConfig _name (MSSQLConnConfiguration connInfo) env = runExceptT do
  (connString, mssqlPool) <- createMSSQLPool connInfo env
  pure $ MSSQLSourceConfig connString mssqlPool

resolveDatabaseMetadata ::
  (MonadIO m, MonadBaseControl IO m) =>
  MSSQLSourceConfig ->
  SourceTypeCustomization ->
  m (Either QErr (ResolvedSource 'MSSQL))
resolveDatabaseMetadata config customization = runExceptT do
  dbTablesMetadata <- withMSSQLPool pool $ Tx.runTxE fromMSSQLTxError loadDBMetadata
  pure $ ResolvedSource config customization dbTablesMetadata mempty mempty
  where
    MSSQLSourceConfig _connString pool = config

postDropSourceHook ::
  (MonadIO m) =>
  MSSQLSourceConfig ->
  m ()
postDropSourceHook (MSSQLSourceConfig _ pool) =
  -- Close the connection
  liftIO $ drainMSSQLPool pool
