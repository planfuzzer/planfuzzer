{-|
Module      : GetTable
Description : This module extracts data from PSQL
Copyright   : © Denis Hirn <denis.hirn@uni-tuebingen.de>
License     : AllRightsReserved
Maintainer  : Denis Hirn
-}

{-# LANGUAGE FlexibleContexts #-}

module Database.PgCuckoo.GetTable
    ( getTable
    , getTableData
    , findRow
    , fromSql
    , checkPlugin
    , Table
    , Row
    , TableData(..)
    ) where


import Data.Convertible
import Database.HDBC

import Database.HDBC.PostgreSQL (connectPostgreSQL, withPostgreSQL)
-- 强制求值
import Control.DeepSeq
import qualified Data.Sequence as Seq
import Data.Foldable (toList)
import Control.Exception (evaluate)

import qualified Data.Map as M
import qualified Data.List as L

type Row = M.Map String SqlValue
type Table = [Row]

data TableData = TableData
               { pg_operators :: Table
               , pg_type      :: Table
               , pg_proc      :: Table
               , pg_class     :: Table
               , pg_attribute :: Table
               , pg_aggregate :: Table
               , pg_indexes   :: Table
               }
    deriving (Show)

-- | Get rows that match oid
findRow :: (Convertible a SqlValue) => String -> a -> Table -> [Row]
findRow idx val t = filter (\x -> x M.! idx == (toSql val)) t

-- | Transform a row into a Data.Map
rowToMap :: [(String, SqlValue)] -> Row
rowToMap row = M.fromList row

-- | Transform a table into a list of rows
tableToMap :: [[(String, SqlValue)]] -> Table
tableToMap rows = map rowToMap rows

-- | Fetch tables from DB
getTableData :: String -> IO TableData
getTableData auth = do
    data_pg_operators <- getTable auth "SELECT oid, oprname, oprleft, oprright, oprresult, oprcode FROM pg_operator"
    data_pg_type      <- getTable auth "SELECT oid, typname, typcategory, typelem, typrelid, typcollation FROM pg_type"
   
    -- docker pg 10
    data_pg_proc      <- getTable auth "SELECT oid, proname, proargtypes, prorettype, proretset, array_to_string(proallargtypes , ' ') as proallargtypes, array_to_string(proargmodes, ' ') as proargmodes, array_to_string(proargnames, ' ') as proargnames, provariadic=0 as provariadic, pronargs, proisagg FROM pg_proc"
    -- localhost pg 12 
    -- data_pg_proc      <- getTable auth "SELECT oid, proname, proargtypes, prorettype, proretset, array_to_string(proallargtypes , ' ') as proallargtypes, array_to_string(proargmodes, ' ') as proargmodes, array_to_string(proargnames, ' ') as proargnames, provariadic=0 as provariadic, pronargs, case prokind when 'a' then TRUE else FALSE end as proisagg FROM pg_proc"
    
    data_pg_class     <- getTable auth "SELECT oid, relname, relkind FROM pg_class"
    data_pg_attribute <- getTable auth "SELECT attrelid, attnum, atttypid, attname, attlen, atttypmod, attcollation FROM pg_attribute WHERE attnum > 0"
    data_pg_aggregate <- getTable auth "SELECT aggfnoid :: OID as oid, * FROM pg_aggregate"
    data_pg_indexes   <- getTable auth "SELECT * FROM pg_indexes"

    let tOperators = tableToMap data_pg_operators
    let tType      = tableToMap data_pg_type
    let tProc      = tableToMap data_pg_proc
    let tClass     = tableToMap data_pg_class
    let tAttribute = tableToMap data_pg_attribute
    let tAggregate = tableToMap data_pg_aggregate
    let tIndexes   = tableToMap data_pg_indexes
    return $! TableData tOperators tType tProc tClass tAttribute tAggregate tIndexes

checkPlugin :: String -> String -> IO (Either String ())
checkPlugin auth expected = do
    let query = "select extname, extversion from pg_extension where extname = 'cuckoo' limit 1"

    res <- getTable auth query
    let res' = tableToMap res
    case res' of
      []  -> return $ Left "ERROR: parse_query is not installed!"
      x:_ -> do
          let version = fromSql $ x M.! "extversion" :: String
          if version == expected
            then return $ Right ()
            else return $ Left $ "ERROR: parse_query version mismatch. Expected version: "
                              ++ expected ++ " but got: " ++ version

-- | Execute a query and return the result
-- getTable :: String -> String -> IO [[(String, SqlValue)]]
-- getTable auth query = do
--     -- 1
--     -- conn <- handleSql (fail . seErrorMsg) $ connectPostgreSQL auth
--     -- stmt <- prepare conn $ query
--     -- _ <- handleSql (fail . seErrorMsg) $ execute stmt []
--     -- res <- fetchAllRowsAL stmt
--     -- -- disconnect conn
--     -- return res

--     -- 2
--     conn <- handleSqlError (connectPostgreSQL auth) -- 使用handleSqlError处理连接错误
--     stmt <- prepare conn query -- 不需要$符号
--     execute stmt [] -- 不需s要接收返回值
--     res <- fetchAllRowsAL stmt

--     print(res[0])
--     -- !res <- fetchAllRowsAL stmt 

--     -- seq res (disconnect conn)
--     -- res `deepseq` (disconnect conn)
--     -- disconnect conn
--     return res


-- getTable :: String -> String -> IO [[(String, SqlValue)]]
-- getTable auth query = do
--     conn <- handleSqlError (connectPostgreSQL auth) 
--     stmt <- prepare conn query 
--     execute stmt []
--     res <- fetchAllRowsAL stmt
--     disconnect conn
--     print(res)
--     return res


-- ！有效，勿删 ！
getTable :: String -> String -> IO [[(String, SqlValue)]]
getTable auth query = do
    conn <- handleSqlError (connectPostgreSQL auth)
    stmt <- prepare conn query
    execute stmt []
    res <- fetchAllRowsAL stmt
    let resSeq = Seq.fromList res
    _ <- evaluate resSeq  -- 强制求值整个列表
    disconnect conn
    return (toList resSeq)
-- ！有效，勿删 ！


-- forceList :: [a] -> IO ()
-- forceList [] = return ()
-- forceList (x:xs) = do
--   force x
--   forceList xs

-- getTable :: String -> String -> IO [[(String, SqlValue)]]
-- getTable auth query = do
--     conn <- handleSqlError (connectPostgreSQL auth)
--     stmt <- prepare conn query
--     execute stmt []
--     res <- fetchAllRowsAL stmt
--     forceList res
--     disconnect conn
--     return res



-- getTable :: String -> String -> IO [[(String, SqlValue)]]
-- getTable auth query = bracket (connectPostgreSQL auth) disconnect $ \conn -> do
--     stmt <- prepare conn query
--     execute stmt []
--     res <- fetchAllRowsAL stmt
--     return res