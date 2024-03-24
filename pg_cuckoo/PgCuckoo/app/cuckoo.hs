{-# LANGUAGE ForeignFunctionInterface #-}


module Cuckoo where

import Foreign.C.String
-- import System.Environment
-- import Data.ConfigFile
-- import Data.Either.Utils
import Control.Monad
import Control.Exception (try, SomeException, evaluate)
import Data.List

import           Database.PgCuckoo.Lib as L
import           Database.PgCuckoo.Validate as V
import           Database.PgCuckoo.GetTable
import           Database.PgCuckoo.Inference as I
import           Database.PgCuckoo.Extract as E
import           Database.PgCuckoo.GPrint
import           Database.PgCuckoo.InAST as A
import           Database.PgCuckoo.PgPlan as P
    

-- !!!  USING  !!!
-- operatorToPlan :: CString -> IO CString
-- operatorToPlan cstr = do
--   let authStr = "user=postgres password=123456 host=127.0.0.1 dbname=fuzz port=5432"

--   str <- peekCString cstr 
--   opResult <- try(evaluate(read str :: A.Operator)) :: IO (Either SomeException A.Operator) 
--   case opResult of
--     Left _ -> do
--       -- putStrLn $ "*** HASKELL: Parse plan error! ***\n"
--       -- newCString("*parse error*")
--       newCString("*error1*")
--     Right op -> do
--       -- errResult <- try(evaluate(V.validateOperator op)) :: IO (Either SomeException A.Operator)
--       let errs = V.validateOperator op
--       case null errs of
--         False -> do
--           -- putStrLn $ "*** HASKELL: Validate operator error! ***\n"
--           -- newCString("*validate error*")
--           newCString("*error2*")
--         True -> do
--           tableDataR <- getTableData authStr
--           let consts = E.extract op
--           -- consts' <- mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts
--           constsResult <- try(mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts) :: IO (Either SomeException [(A.Expr,P.Expr)])
--           case constsResult of
--             Left _ -> do
--               -- putStrLn $ "*** HASKELL: Parse const error! ***\n"
--               -- newCString("*const error*")
--               newCString("*error3*")
--             Right consts' -> do
--               let infered = generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op [])
     
--                   -- constsResult1 <- try(evaluate(E.extract op)) :: IO (Either SomeException E.Log) 
--                   -- case constsResult1 of
--                   --   Left _ -> do
--                   --     putStrLn $ "extract op error!"
--                   --   Right consts -> do
--                   --     constsResult2 <- try(mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts) :: IO (Either SomeException [(A.Expr,P.Expr)])
--                   --     case constsResult2 of
--                   --       Left _ -> do
--                   --         putStrLn $ "parseConst error!"
--                   --       Right consts' -> do
--                   --         inferedResult <- try(evaluate(generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op []))) :: IO (Either SomeException P.PLANNEDSTMT)
--                   --         case inferedResult of
--                   --           Left _ -> do
--                   --             putStrLn $ "infered error!"
--                   --           Right infered -> do
                              
--               let pgplan = gprint infered
--               -- eitherResult <- try(newCString ("select plan_execute_print('" ++ pgplan ++ "');")) :: IO (Either MyException CString)
--               eitherResult <- try(newCString ("select plan_execute_print('" ++ pgplan ++ "');")) :: IO (Either SomeException CString)
--               case eitherResult of
--                 Left e -> do 
--                   -- putStrLn $ "*** HASKELL: Fill plan error! ***"
--                   -- newCString("*fill error*")
--                   newCString("*error4*")
--                 Right plan -> do
--                   return plan

-- withCString  
-- operatorToPlan :: CString -> IO CString
-- operatorToPlan cstr = do
--   let authStr = "user=postgres password=123456 host=127.0.0.1 dbname=fuzz port=5432"
--   str <- peekCString cstr
--   result <- try (do
--     let op = read str :: A.Operator
--     let errs = V.validateOperator op
--     tableDataR <- getTableData authStr
--     let consts = E.extract op
--     consts' <- mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts
--     let infered = generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op [])
--     let pgplan = gprint infered
--     withCString ("select plan_execute_print('" ++ pgplan ++ "');") $ \plan -> do
--       return plan) :: IO (Either SomeException CString)
--   case result of
--     Left _ -> do
--       newCString("")
--     Right plan -> do
--       return plan

-- CString  ->  free
foreign export ccall operatorToPlan :: CString -> CString  -> IO CString
operatorToPlan :: CString -> CString -> IO CString 
operatorToPlan cstr1 cstr2 = do 
  str_op <- peekCString cstr1 
  -- let authStr = "user=postgres password=123456 host=127.0.0.1 dbname=fuzz port=5432"
  authStr <- peekCString cstr2
  result <- try (do 
   
    let op = read str_op :: A.Operator
    let errs = V.validateOperator op
    tableDataR <- getTableData authStr
    let consts = E.extract op
    consts' <- mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts
    let infered = generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op [])
    let pgplan = gprint infered

    plan <- newCString ("select plan_execute_print('" ++ pgplan ++ "');") 
    return plan) :: IO (Either SomeException CString) 
  case result of 
    Left _ -> do 
      newCString("") 
    Right plan -> do 
      return plan
