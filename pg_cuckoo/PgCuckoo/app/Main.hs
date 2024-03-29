module Main where

import System.Environment
import Data.ConfigFile
import Data.Either.Utils
import Data.Typeable

import Foreign.C.String

import Control.Monad
import Control.Exception (try, SomeException, evaluate)
-- import UnliftIO.Exception

import Text.Show.Pretty as PP hiding (List, Value, Float)

import Data.List

import           Database.PgCuckoo.Lib as L
import           Database.PgCuckoo.Validate as V
import           Database.PgCuckoo.GetTable
import           Database.PgCuckoo.Inference as I
import           Database.PgCuckoo.Extract as E
import           Database.PgCuckoo.Extract  (MyException(MyException))
import           Database.PgCuckoo.GPrint
import qualified Database.PgCuckoo.InAST as A
import           Database.PgCuckoo.PgPlan as P

const1 :: A.Operator
const1 = A.RESULT
          { A.targetlist = 
              [ A.TargetEntry
                { A.targetexpr = A.CONST "42" "int4"
                , A.targetresname = "valid"
                , A.resjunk = False
                }
              ]
          , A.resconstantqual = Nothing
          }

const2 :: A.Operator
const2 = A.RESULT
          { A.targetlist =
            [ A.TargetEntry
              { A.targetexpr =
                A.AND
                { A.args =
                  [ A.CONST "1" "int4"
                  , A.CONST "2" "int4"
                  ]
                }
              , A.targetresname = "foo"
              , A.resjunk = False
              }
            ]
          , A.resconstantqual = Nothing
          }

-- Query would be: select a as "foo", b as "bar" from tb_b
-- seq1 :: A.Operator
-- seq1 = A.SEQSCAN
--         { A.targetlist =
--             [ A.TargetEntry
--                 { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
--                 , A.targetresname = "foo"
--                 , A.resjunk = False
--                 }
--             , A.TargetEntry 
--                 { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="data"}
--                 , A.targetresname = "bar"
--                 , A.resjunk = False
--                 }
--             ]
--         , A.qual = []
--         , A.scanrelation="tb_b"
--         }
-- select id as b_id from tb_b;
seq1 :: A.Operator
seq1 = A.SEQSCAN
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                , A.targetresname = "b_id"
                , A.resjunk = False
                }
            , A.TargetEntry 
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="data"}
                , A.targetresname = "b_data"
                , A.resjunk = False
                }
            ]
        , A.qual = []
        , A.scanrelation="tb_b"
        }


seq2 :: A.Operator
seq2 = A.LIMIT
        { A.operator = seq1
        , A.limitOffset = Nothing
        , A.limitCount  = Just (A.CONST "6" "int8")
        }
-- +

func1 :: A.Operator
func1 = A.RESULT
          { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = 
                    A.FUNCEXPR 
                      { A.funcname="int4pl"
                      , A.funcargs=
                          [ A.CONST "1" "int4"
                          , A.CONST "4" "int4"
                          ]
                      }
                , A.targetresname = "addition"
                , A.resjunk = False
                }
              ]
          , A.resconstantqual = Nothing
          }
-- d, data, int4pl(id, VARIADIC data)
seq3 :: A.Operator
seq3 = A.SEQSCAN
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                , A.targetresname = "b_id"
                , A.resjunk = False
                }
            , A.TargetEntry 
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="data"}
                , A.targetresname = "b_data"
                , A.resjunk = False
                }
            , A.TargetEntry
                { A.targetexpr =
                    A.FUNCEXPR
                      { A.funcname="int4pl"
                      , A.funcargs=
                          [ A.VAR {A.varTable="tb_b", A.varColumn="id"}
                          , A.VAR {A.varTable="tb_b", A.varColumn="data"}
                          ] 
                      }
                , A.targetresname = "baz"
                , A.resjunk = False
                }
            ]
        , A.qual = []
        , A.scanrelation="tb_b"
        }
--cos
seq4 :: A.Operator
seq4 = A.SEQSCAN
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                , A.targetresname = "b_id"
                , A.resjunk = False
                }
            , A.TargetEntry 
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="data"}
                , A.targetresname = "b_data"
                , A.resjunk = False
                }
            , A.TargetEntry
                { A.targetexpr =
                    A.FUNCEXPR
                      { A.funcname="cos"
                      , A.funcargs=
                          [ A.FUNCEXPR
                            { A.funcname="float8"
                            , A.funcargs=
                                [ A.FUNCEXPR
                                  { A.funcname="int4pl"
                                  , A.funcargs=
                                      [ A.VAR {A.varTable="tb_b", A.varColumn="id"}
                                      , A.VAR {A.varTable="tb_b", A.varColumn="data"}
                                      ] 
                                  }
                                ]
                            }
                          ]
                      }
                , A.targetresname = "baz"
                , A.resjunk = False
                }
            ]
        , A.qual = []
        , A.scanrelation="tb_b"
        }

seq5 :: A.Operator
seq5 = A.SEQSCAN
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                , A.targetresname = "foo"
                , A.resjunk = False
                }
            
            ]
        , A.qual =
            [ A.FUNCEXPR 
                { A.funcname = "int4lt"
                , A.funcargs =
                    [ A.VAR {A.varTable="tb_b", A.varColumn="id"}
                    , A.CONST "2" "int4"
                    ]
                }
            ]
        , A.scanrelation="tb_b"
        }
--select 1 < 42
func2 :: A.Operator
func2 = A.RESULT
          { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = 
                    A.OPEXPR
                      { A.oprname="<"
                      , A.oprargs=
                          [ A.CONST "1" "int4"
                          , A.CONST "42" "int4"
                          ]
                      }
                , A.targetresname = "lessThan"
                , A.resjunk = False
                }
              ]
          , A.resconstantqual = Nothing
          }

sort1 :: A.Operator
sort1 = A.SORT
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                , A.targetresname = "b_id"
                , A.resjunk = False
                }
            , A.TargetEntry 
                { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="data"}
                , A.targetresname = "b_data"
                , A.resjunk = False
                }
            ]
        , A.operator =
            A.SEQSCAN
            { A.targetlist =
                [ A.TargetEntry
                    { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                    , A.targetresname = "b_id"
                    , A.resjunk = False
                    }
                , A.TargetEntry 
                    { A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="data"}
                    , A.targetresname = "b_data"
                    , A.resjunk = False
                    }
                ]
            , A.qual = []
            , A.scanrelation="tb_b"
            }
        , A.sortCols = [ A.SortEx 2  True False ]
        }

app1 :: A.Operator
app1 = A.APPEND
        { A.targetlist =
          [ A.TargetEntry
              { A.targetexpr = A.VAR {A.varTable="OUTER_VAR", A.varColumn="lessThan"}
              , A.targetresname = "bar"
              , A.resjunk = False
              }
          ]
        , A.appendplans = [func2, func2]
        }

agg1 :: A.Operator
agg1 = A.AGG
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr =
                    A.AGGREF
                      { A.aggname = "sum"
                      , A.aggargs = [ A.TargetEntry
                                        { A.targetexpr = A.CONST "1" "int4"
                                        , A.targetresname = "foo"
                                        , A.resjunk = False
                                        }
                                    ]
                      , A.aggdirectargs = []
                      , A.aggorder = []
                      , A.aggdistinct = []
                      , A.aggfilter = Nothing
                      , A.aggstar = False
                      }
                , A.targetresname = "foo"
                , A.resjunk = False
                }
            ]
        , A.qual = []
        , A.operator =
            A.RESULT
              { A.targetlist = []
              , A.resconstantqual = Nothing
              }
        , A.groupCols = []
        , A.aggstrategy = A.AGG_PLAIN
        , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
        }

agg2 :: A.Operator
agg2 = A.AGG
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr =
                    A.AGGREF
                      { A.aggname = "sum"
                      , A.aggargs = [ A.TargetEntry
                                        { A.targetexpr = A.VAR "OUTER_VAR" "id"
                                        , A.targetresname = "foo"
                                        , A.resjunk = False
                                        }
                                    ]
                      , A.aggdirectargs = []
                      , A.aggorder = []
                      , A.aggdistinct = []
                      , A.aggfilter = Nothing
                      , A.aggstar = False
                      }
                , A.targetresname = "foo"
                , A.resjunk = False
                }
            , A.TargetEntry
                { A.targetexpr = A.VAR "OUTER_VAR" "data"
                , A.targetresname = "data"
                , A.resjunk = False
                }
            ]
        , A.qual = []
        , A.operator =
            A.SEQSCAN
              { A.targetlist =
                  [ A.TargetEntry
                      { A.targetexpr = A.VAR "tb_b" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                  , A.TargetEntry
                      { A.targetexpr = A.VAR "tb_b" "data"
                      , A.targetresname = "data"
                      , A.resjunk = False
                      }
                  ]
              , A.qual = []
              , A.scanrelation = "tb_b"
              }
        , A.groupCols = []
        , A.aggstrategy = A.AGG_PLAIN
        , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
        }

nestLoop1 :: A.Operator
nestLoop1 = A.NESTLOOP
            { A.targetlist =
                [ A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "id"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                , A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "data"
                    , A.targetresname = "data"
                    , A.resjunk = False
                    }
                , A.TargetEntry
                    { A.targetexpr = A.VAR "INNER_VAR" "id"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                , A.TargetEntry
                    { A.targetexpr = A.VAR "INNER_VAR" "y"
                    , A.targetresname = "y"
                    , A.resjunk = False
                    }
                ]
            , A.joinType = A.INNER
            , A.inner_unique = False
            , A.joinquals = []
            , A.nestParams = []
            , A.lefttree =
                A.SEQSCAN
                  { A.targetlist =
                      [ A.TargetEntry
                          { A.targetexpr = A.VAR "tb_b" "id"
                          , A.targetresname = "id"
                          , A.resjunk = False
                          }
                      , A.TargetEntry
                          { A.targetexpr = A.VAR "tb_b" "data"
                          , A.targetresname = "data"
                          , A.resjunk = False
                          }
                      ]
                  , A.qual = []
                  , A.scanrelation = "tb_b"
                  }
            , A.righttree =
                A.SEQSCAN
                  { A.targetlist =
                      [ A.TargetEntry
                          { A.targetexpr = A.VAR "tb_b" "id"
                          , A.targetresname = "id"
                          , A.resjunk = False
                          }
                      , A.TargetEntry
                          { A.targetexpr = A.VAR "tb_b" "data"
                          , A.targetresname = "y"
                          , A.resjunk = False
                          }
                      ]
                  , A.qual = []
                  , A.scanrelation = "tb_b"
                  }
            }
-- ？？？
unique1 :: A.Operator
unique1 = A.UNIQUE
          { A.operator =
              A.SEQSCAN
                { A.targetlist = 
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "tb_b" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False }
                    ]
                , A.qual = []
                , A.scanrelation = "tb_b"
                }
          , A.uniqueCols = [1]
          }

values1 :: A.Operator
values1 = A.VALUESSCAN
          { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.SCANVAR 1
                , A.targetresname = "id"
                , A.resjunk = False }
              , A.TargetEntry
                { A.targetexpr = A.SCANVAR 2
                , A.targetresname = "data"
                , A.resjunk = False }
              ]
          , A.qual = []
          , A.values_list =
              [ [ A.CONST "1" "int4", A.CONST "2" "int4"]
              , [ A.CONST "3" "int4", A.CONST "4" "int4"]
              ]
        }

projectset1 :: A.Operator
projectset1 = A.PROJECTSET
              { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr =
                        A.FUNCEXPR
                        { A.funcname = "generate_series"
                        , A.funcargs =
                            [ A.CONST "1" "int4"
                            , A.CONST "10" "int4"
                            ]
                        }
                    , A.targetresname = "value"
                    , A.resjunk = False
                    }
                  ]
              , A.operator =
                  A.RESULT
                  { A.targetlist = []
                  , A.resconstantqual = Nothing
                  }
              }

projectset2 :: A.Operator
projectset2 = A.PROJECTSET
              { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr =
                        A.FUNCEXPR
                        { A.funcname = "generate_series"
                        , A.funcargs =
                            [ A.CONST "10" "int4"
                            , A.CONST "1" "int4"
                            , A.CONST "-1" "int4"
                            ]
                        }
                    , A.targetresname = "value"
                    , A.resjunk = False
                    }
                  ]
              , A.operator =
                  A.RESULT
                  { A.targetlist = []
                  , A.resconstantqual = Nothing
                  }
              }

mergeappend1 :: A.Operator
mergeappend1 = A.MERGEAPPEND
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "value"
                    , A.targetresname = "value"
                    , A.resjunk = False
                    }
                  ]
                , A.mergeplans = [projectset1, projectset2]
                , A.sortCols =
                  [ A.SortEx { A.sortTarget = 1, A.sortASC = True, A.sortNullsFirst = False } ]
                }

functionscan1 :: A.Operator
functionscan1 = A.FUNCTIONSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.SCANVAR 1
                      , A.targetresname = "value"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.functions =
                    [ A.FUNCEXPR
                      { A.funcname = "generate_series"
                      , A.funcargs =
                        [ A.CONST "1" "int4"
                        , A.CONST "10" "int4"
                        ]
                      }
                    ]
                  , A.funcordinality = False
                  }

group1 :: A.Operator
group1 = A.GROUP
          { A.targetlist =
            [ A.TargetEntry
              { A.targetexpr = A.VAR "OUTER_VAR" "id"
              , A.targetresname = "id"
              , A.resjunk = False
              }
            ]
          , A.qual = []
          , A.operator =
            A.SEQSCAN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "tb_b" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                ]
              , A.qual = []
              , A.scanrelation = "tb_b"
              }
          , A.groupCols = [1]
          }
hashjoin11 :: A.Operator
hashjoin11 = A.HASHJOIN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VAR "OUTER_VAR" "id"
                , A.targetresname = "id"
                , A.resjunk = False
                }
              ]
            , A.joinType = A.INNER
            , A.inner_unique = True
            , A.joinquals =[]
            , A.hashclauses =
              [ A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "OUTER_VAR" "id"
                  , A.VAR "INNER_VAR" "id"
                  ]
                }
              ]
            , A.lefttree =
              A.SEQSCAN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "tb_b" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                ]
              , A.qual = []
              , A.scanrelation = "tb_b"
              }
            , A.righttree =
              A.HASH
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "OUTER_VAR" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                ]
              , A.operator = 
                  A.SEQSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "tb_c" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.scanrelation = "tb_c"
                  }               
              , A.skewTable = "tb_b"
              , A.skewColumn = 1
              }
            }
hashjoin1 :: A.Operator
hashjoin1 = A.HASHJOIN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VAR "OUTER_VAR" "id"
                , A.targetresname = "id"
                , A.resjunk = False
                }
              , A.TargetEntry
                { A.targetexpr = A.VAR "OUTER_VAR" "data"
                , A.targetresname = "data"
                , A.resjunk = False
                }
              ]
            , A.joinType = A.INNER
            , A.inner_unique = True
            , A.joinquals =
              [ A.OPEXPR
                { A.oprname = ">"
                , A.oprargs =
                  [ A.VAR "INNER_VAR" "id"
                  , A.CONST "2" "int4"
                  ]
                }
              ]
            , A.hashclauses =
              [ A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "OUTER_VAR" "id"
                  , A.VAR "INNER_VAR" "id"
                  ]
                }
              ]
            , A.lefttree =
              A.SEQSCAN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "tb_b" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                , A.TargetEntry
                  { A.targetexpr = A.VAR "tb_b" "data"
                  , A.targetresname = "data"
                  , A.resjunk = False
                  }
                ]
              , A.qual = []
              , A.scanrelation = "tb_b"
              }
            , A.righttree =
              A.HASH
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "OUTER_VAR" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                ]
              , A.operator =
                A.AGG
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "id"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                  ]
                , A.qual = []
                , A.operator =
                  A.SEQSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "tb_c" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.scanrelation = "tb_c"
                  }
                , A.groupCols = [1]
                , A.aggstrategy = A.AGG_HASHED
                , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
                }
              , A.skewTable = "tb_b"
              , A.skewColumn = 1
              }
            }

indexscan1 :: A.Operator
indexscan1 = A.INDEXSCAN
            { A.targetlist =
              [ 
              A.TargetEntry
                { A.targetexpr = A.VAR "tb_a" "id"
                , A.targetresname = "id"
                , A.resjunk = True
                }
              ]
            , A.qual = []
            , A.indexqual = []
            , A.indexorderby = []
            , A.indexorderasc = True
            , A.indexname = "index_id"
            , A.scanrelation = "tb_a"
            }

-- indexonlyscan1 :: A.Operator
-- indexonlyscan1 = A.INDEXONLYSCAN
--                 { A.targetlist =
--                   [ A.TargetEntry
--                     { A.targetexpr = A.VAR "tb_a" "id"
--                     , A.targetresname = "id"
--                     , A.resjunk = False
--                     }
--                   ]
--                 , A.qual = []
--                 , A.indexqual =
--                   [ A.OPEXPR
--                     { A.oprname = "="
--                     , A.oprargs =
--                       [ A.VAR "index_id" "id"
--                       , A.CONST "4" "int4" ]
--                     }
--                   ]
--                 , A.recheckqual =
--                   [ 
--                     -- A.OPEXPR
--                     -- { A.oprname = "="
--                     -- , A.oprargs =
--                     --   [ A.VAR "tb_a" "id"
--                     --   , A.CONST "5" "int4" ]
--                     -- }
--                   ]
--                 , A.indexorderby = []
--                 , A.indexorderasc = True
--                 , A.indexname = "index_id"
--                 , A.scanrelation = "tb_a"
--                 }

-- INDEXONLYSCAN {targetlist = [TargetEntry {targetexpr = VAR {varTable = "tb_a", varColumn = "id"}, targetresname = "id", resjunk = False}], qual = [], indexqual = [OPEXPR {oprname = "=", oprargs = [VAR {varTable = "index_id", varColumn = "id"},CONST {constvalue = "2", consttype = "int4"}]}], indexorderby = [], indexorderasc = True, indexname = "index_id", scanrelation = "tb_a"}

bitmapheapscan1 :: A.Operator
bitmapheapscan1 = A.BITMAPHEAPSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "tb_a" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    ]
                  , A.bitmapqualorig =
                    []
                  , A.operator =
                      A.BITMAPINDEXSCAN
                      { A.indexqual =
                        [ 
                        ]
                      , A.indexname = "index_id"
                      , A.scanrelation = "tb_a"
                      }
                  , A.scanrelation = "tb_a"
                  }
bitmapor1 :: A.Operator
bitmapor1 = A.BITMAPHEAPSCAN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VAR "tb_a" "id"
                , A.targetresname = "id"
                , A.resjunk = False
                }
              ]
            , A.bitmapqualorig = 
                [ A.OR
                  { A.args =
                    [ A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VAR "tb_a" "id"
                        , A.CONST "4" "int4"
                        ]
                      }
                    , A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VAR "tb_a" "id"
                        , A.CONST "4" "int4"
                        ]
                      }
                    ]
                  }
                ]
            , A.operator =
                A.BITMAPOR
                { A.bitmapplans =
                  [ A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "index_id" "id"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "index_id"
                    , A.scanrelation = "tb_a"
                    }
                  , A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "index_id" "id"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "index_id"
                    , A.scanrelation = "tb_a"
                    }
                  ]
                }
            , A.scanrelation = "tb_a"
            }
bitmapor11 :: A.Operator
bitmapor11 = A.BITMAPHEAPSCAN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VAR "t12" "c1"
                , A.targetresname = "c1"
                , A.resjunk = False
                }
              ]
            , A.bitmapqualorig = 
                [ A.OR
                  { A.args =
                    [ A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VAR "t12" "c1"
                        , A.CONST "4" "int4"
                        ]
                      }
                    , A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VAR "t12" "c2"
                        , A.CONST "4" "int4"
                        ]
                      }
                    ]
                  }
                ]
            , A.operator =
                A.BITMAPOR
                { A.bitmapplans =
                  [ A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "t12_c1" "c1"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "t12_c1"
                    , A.scanrelation = "t12"
                    }
                  , A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "t12_c2" "c2"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "t12_c2"
                    , A.scanrelation = "t12"
                    }
                  ]
                }
            , A.scanrelation = "t12"
            }
bitmapAnd1 :: A.Operator
bitmapAnd1 = A.BITMAPHEAPSCAN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VAR "t12" "c1"
                , A.targetresname = "id"
                , A.resjunk = False
                }
              ]
            , A.bitmapqualorig = 
                [ A.AND
                  { A.args =
                    [ A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VAR "t12" "c1"
                        , A.CONST "4" "int4"
                        ]
                      }
                    , A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VAR "t12" "c2"
                        , A.CONST "4" "int4"
                        ]
                      }
                    ]
                  }
                ]
            , A.operator =
                A.BITMAPAND
                { A.bitmapplans =
                  [ A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "t12_c1" "c1"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "t12_c1"
                    , A.scanrelation = "t12"
                    }
                  , A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "t12_c2" "c2"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "t12_c2"
                    , A.scanrelation = "t12"
                    }
                  ]
                }
            , A.scanrelation = "t12"
            }
bitmapor2 :: A.Operator
bitmapor2 = 
                A.BITMAPAND
                { A.bitmapplans =
                  [ A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "t12_c1" "c1"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "t12_c1"
                    , A.scanrelation = "t12"
                    }
                  , A.BITMAPINDEXSCAN
                    { A.indexqual =
                    [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                        [ A.VAR "t12_c2" "c2"
                        , A.CONST "4" "int4"
                        ]
                        }
                    ]
                    , A.indexname = "t12_c2"
                    , A.scanrelation = "t12"
                    }
                  ]
                }

mergejoin1 :: A.Operator
mergejoin1 = A.MERGEJOIN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "OUTER_VAR" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                -- , A.TargetEntry
                --   { A.targetexpr = A.VAR "INNER_VAR" "id"
                --   , A.targetresname = "id"
                --   , A.resjunk = False
                --   }

                ]
              , A.qual = []
              , A.joinType = A.INNER
              , A.inner_unique = True
              , A.joinquals = []
              , A.mergeclauses = []
              , A.mergeStrategies = []
              , A.lefttree =
                A.SEQSCAN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "tb_b" "id"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                  
                  ]
                , A.qual = []
                , A.scanrelation = "tb_b"
                }
              , A.righttree =
                A.SEQSCAN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "tb_c" "id"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                  ]
                , A.qual = []
                , A.scanrelation = "tb_c"
                }
              }

subqueryscan1 :: A.Operator
subqueryscan1 = A.SUBQUERYSCAN
                { A.targetlist =
                    [ A.TargetEntry
                        { A.targetexpr = A.SCANVAR 1
                        , A.targetresname = "foo"
                        , A.resjunk = False
                        }
                    ]
                , A.qual = []
                , A.subplan =
                  A.SEQSCAN{ 
                              A.targetlist =[ 
                                  A.TargetEntry{ 
                                      A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                                      , A.targetresname = "b_id"
                                      , A.resjunk = False
                                  }
                              ]
                              , A.qual = []
                              , A.scanrelation="tb_b"
                          }
                    -- A.RESULT
                    -- { A.targetlist =
                    --     [ A.TargetEntry
                    --         { A.targetexpr = A.CONST "42" "int4"
                    --         , A.targetresname = "id"
                    --         , A.resjunk = False
                    --         }
                    --     ]
                    -- , A.resconstantqual = Nothing
                    -- }
                }

setop1 :: A.Operator
setop1 = A.SETOP
        { A.targetlist =
            [ A.TargetEntry
                { A.targetexpr = A.VAR "OUTER_VAR" "b_id"
                , A.targetresname = "id"
                , A.resjunk = False
                }
            ]
        , A.qual = []
        , A.setOpCmd = A.SETOPCMD_EXCEPT
        , A.setopStrategy = A.SETOP_HASHED
        , A.lefttree =
                    A.SEQSCAN{ 
              A.targetlist =[ 
                  A.TargetEntry{ 
                      A.targetexpr = A.VAR {A.varTable="tb_b", A.varColumn="id"}
                      , A.targetresname = "b_id"
                      , A.resjunk = False
                  }
              ]
              , A.qual = []
              , A.scanrelation="tb_b"
          }
            -- A.APPEND
            -- { A.targetlist =
            --     [ A.TargetEntry
            --         { A.targetexpr = A.VAR "OUTER_VAR" "id"
            --         , A.targetresname = "id"
            --         , A.resjunk = False
            --         }
            --     , A.TargetEntry
            --         { A.targetexpr = A.VAR "OUTER_VAR" "data"
            --         , A.targetresname = "data"
            --         , A.resjunk = False
            --         }
            --     , A.TargetEntry
            --         { A.targetexpr = A.VAR "OUTER_VAR" "flag"
            --         , A.targetresname = "flag"
            --         , A.resjunk = False
            --         }
            --     ]
            -- , A.appendplans =
            --     [ A.SUBQUERYSCAN
            --         { A.targetlist =
            --             [ A.TargetEntry
            --               { A.targetexpr = A.SCANVAR 1
            --               , A.targetresname = "id"
            --               , A.resjunk = False
            --               }
            --             , A.TargetEntry
            --               { A.targetexpr = A.SCANVAR 2
            --               , A.targetresname = "data"
            --               , A.resjunk = False
            --               }
            --             , A.TargetEntry
            --               { A.targetexpr = A.CONST "0" "int4"
            --               , A.targetresname = "flag"
            --               , A.resjunk = False
            --               }
            --             ]
            --         , A.qual = []
            --         , A.subplan =
            --             A.SEQSCAN
            --             { A.targetlist =
            --                 [ A.TargetEntry
            --                   { A.targetexpr = A.VAR "tb_b" "id"
            --                   , A.targetresname = "id"
            --                   , A.resjunk = False
            --                   }
            --                 , A.TargetEntry
            --                   { A.targetexpr = A.VAR "tb_b" "data"
            --                   , A.targetresname = "data"
            --                   , A.resjunk = False
            --                   }
            --                 ]
            --             , A.qual = []
            --             , A.scanrelation = "tb_b"
            --             }
            --         }
            --     , A.SUBQUERYSCAN
            --         { A.targetlist =
            --             [ A.TargetEntry
            --               { A.targetexpr = A.SCANVAR 1
            --               , A.targetresname = "id"
            --               , A.resjunk = False
            --               }
            --             , A.TargetEntry
            --               { A.targetexpr = A.SCANVAR 2
            --               , A.targetresname = "data"
            --               , A.resjunk = False
            --               }
            --             , A.TargetEntry
            --               { A.targetexpr = A.CONST "1" "int4"
            --               , A.targetresname = "flag"
            --               , A.resjunk = False
            --               }
            --             ]
            --         , A.qual = []
            --         , A.subplan =
            --             A.SEQSCAN
            --             { A.targetlist =
            --                 [ A.TargetEntry
            --                 { A.targetexpr = A.VAR "tb_a" "id"
            --                 , A.targetresname = "id"
            --                 , A.resjunk = False
            --                 }
            --                 , A.TargetEntry
            --                 { A.targetexpr = A.VAR "tb_a" "data"
            --                 , A.targetresname = "data"
            --                 , A.resjunk = False
            --                 }
            --                 ]
            --             , A.qual = []
            --             , A.scanrelation = "tb_a"
            --             }
            --         }
            --     ]
            -- }
        , A.flagColIdx = 3
        , A.firstFlag = 0
        }

windowfunc1 :: A.Operator
windowfunc1 = A.WINDOWAGG
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr =
                      A.WINDOWFUNC
                      { A.winname = "sum"
                      , A.winargs =
                        [ A.VAR "OUTER_VAR" "id" ]
                      , A.aggfilter = Nothing
                      , A.winref = 1
                      , A.winstar = False
                      }
                  , A.targetresname = "foo"
                  , A.resjunk = False
                  }
                ]
              , A.operator =
                  A.SEQSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "tb_b" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VAR "tb_b" "data"
                      , A.targetresname = "data"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.scanrelation = "tb_b"
                  }
              , A.winrefId = 1
              , A.ordEx = []
              , A.groupCols = []
              , A.frameOptions = [ A.FRAMEOPTION_RANGE
                                 , A.FRAMEOPTION_START_UNBOUNDED_PRECEDING
                                 , A.FRAMEOPTION_END_CURRENT_ROW
                                 ]
              , A.startOffset = Nothing
              , A.endOffset = Nothing
              }

ctescan1 :: A.PlannedStmt
ctescan1 = A.PlannedStmt
            { A.planTree =
                A.CTESCAN
                { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.SCANVAR 1
                      , A.targetresname = "x"
                      , A.resjunk = False
                      }
                    ]
                , A.qual = []
                , A.ctename = "num"
                , A.recursive = False
                , A.initPlan = [1]
                }
            , A.subplans =
              [ A.RESULT
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.CONST "42" "int4"
                    , A.targetresname = "x"
                    , A.resjunk = False
                    }
                  ]
                , A.resconstantqual = Nothing
                }
              ]
            }

ctescan11 :: A.PlannedStmt
ctescan11 = A.PlannedStmt
            { A.planTree =
                A.CTESCAN
                { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.SCANVAR 1
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    ]
                , A.qual = []
                , A.ctename = "tb_b"
                , A.recursive = False
                , A.initPlan = [1]
                }
            , A.subplans =
              [ A.RESULT
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.CONST "1" "int4"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                  ]
                , A.resconstantqual = Nothing
                }
              ]
            }


worktable1 :: A.Operator
worktable1 = A.WORKTABLESCAN
                      { A.targetlist =
                        [ A.TargetEntry
                          { A.targetexpr = A.VAR "tb_a" "id"
                          , A.targetresname = "x"
                          , A.resjunk = False
                          }
                        ]
                      , A.qual =
                          [ 
                          ]
                          
                      , A.wtParam = 0
                      }
recursive1 :: A.PlannedStmt
recursive1 = A.PlannedStmt
              { A.planTree =
                  A.CTESCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.SCANVAR 1
                      , A.targetresname = "x"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.ctename = "num"
                  , A.recursive = False
                  , A.initPlan = [1]
                  }
              , A.subplans =
                [ A.RECURSIVEUNION
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "OUTER_VAR" "x"
                      , A.targetresname = "x"
                      , A.resjunk = False
                      }
                    ]
                  , A.lefttree =
                      A.RESULT
                      { A.targetlist =
                          [ A.TargetEntry
                              { A.targetexpr = A.CONST "1" "int4"
                              , A.targetresname = "x"
                              , A.resjunk = False
                              }
                          ]
                      , A.resconstantqual = Nothing
                      }
                  , A.righttree =
                      A.WORKTABLESCAN
                      { A.targetlist =
                        [ A.TargetEntry
                          { A.targetexpr =
                              A.OPEXPR
                              { A.oprname = "+"
                              , A.oprargs =
                                [ A.VAR "num" "x"
                                , A.CONST "1" "int4"
                                ]
                              }
                          , A.targetresname = "x"
                          , A.resjunk = False
                          }
                        ]
                      , A.qual =
                          [ A.OPEXPR
                            { A.oprname = "<"
                            , A.oprargs =
                              [ A.VAR "num" "x"
                              , A.CONST "10" "int4"
                              ]
                            }
                          ]
                      , A.wtParam = 0
                      }
                  , A.wtParam = 0
                  , A.unionall = False
                  , A.ctename = "num"
                  }
                ]
              }

recursive2 :: A.PlannedStmt
recursive2 = A.PlannedStmt
              { A.planTree =
                  A.CTESCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.SCANVAR 1
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.ctename = "tb_b"
                  , A.recursive = False
                  , A.initPlan = [1]
                  }
              , A.subplans =
                [ A.RECURSIVEUNION
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "OUTER_VAR" "id"
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    ]
                  , A.lefttree =
                      A.RESULT
                      { A.targetlist =
                          [ A.TargetEntry
                              { A.targetexpr = A.CONST "1" "int4"
                              , A.targetresname = "id"
                              , A.resjunk = False
                              }
                          ]
                      , A.resconstantqual = Nothing
                      }
                  , A.righttree =
                      A.WORKTABLESCAN
                      { A.targetlist =
                        [ A.TargetEntry
                          { A.targetexpr =
                              A.OPEXPR
                              { A.oprname = "+"
                              , A.oprargs =
                                [ A.VAR "tb_b" "id"
                                , A.CONST "1" "int4"
                                ]
                              }
                          , A.targetresname = "id"
                          , A.resjunk = False
                          }
                        ]
                      , A.qual =
                          [ A.OPEXPR
                            { A.oprname = "<"
                            , A.oprargs =
                              [ A.VAR "tb_b" "id"
                              , A.CONST "10" "int4"
                              ]
                            }
                          ]
                      , A.wtParam = 0
                      }
                  , A.wtParam = 0
                  , A.unionall = False
                  , A.ctename = "tb_b"
                  }
                ]
              }
              
              
gather1 :: A.Operator
gather1 = A.GATHER
          { A.targetlist =
            [ A.TargetEntry
              { A.targetexpr = A.VAR "OUTER_VAR" "id"
              , A.targetresname = "id"
              , A.resjunk = False
              }
            ]
          , A.num_workers = 999
          , A.operator =
            A.PARALLEL
            A.SEQSCAN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VAR "tb_a" "id"
                , A.targetresname = "id"
                , A.resjunk = False
                }
              , A.TargetEntry
                { A.targetexpr = A.VAR "tb_a" "data"
                , A.targetresname = "data"
                , A.resjunk = False 
                }
              ]
            , A.qual = 
              [ {-A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "tb_a" "id"
                  , A.CONST "0.42" "numeric"
                  ]
                }-}
              ]
            , A.scanrelation = "tb_a"
            }
          , A.rescan_param = 0
          }

-- gathermerge1 :: A.Operator
-- gathermerge1 = A.GATHERMERGE
--                 { A.targetlist =
--                   [ A.TargetEntry
--                     { A.targetexpr = A.VAR "tb_a" "id"
--                     , A.targetresname = "id"
--                     , A.resjunk = False
--                     }
--                   ]
--                 , A.num_workers = 4
--                 , A.operator =
--                          A.SEQSCAN
--                         { A.targetlist =
--                           [ A.TargetEntry
--                             { A.targetexpr = A.VAR {A.varTable="tb_a", A.varColumn="id"}
--                             , A.targetresname = "id"
--                             , A.resjunk = False
--                             }
--                           ]
--                         , A.qual = []
--                         , A.scanrelation = "tb_a"
--                         }     
--                 , A.rescan_param = 0
--                 , A.sortCols = [ A.SortEx 1 True False ]
--                 }
gathermerge1 :: A.Operator
gathermerge1 = A.GATHERMERGE
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "a"
                    , A.targetresname = "a"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "b"
                    , A.targetresname = "b"
                    , A.resjunk = False 
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "c"
                    , A.targetresname = "c"
                    , A.resjunk = False 
                    }
                  ]
                , A.num_workers = 2
                , A.operator =
                    A.PARALLEL A.SORT
                    { A.targetlist =
                      [ A.TargetEntry
                        { A.targetexpr = A.VAR "OUTER_VAR" "a"
                        , A.targetresname = "a"
                        , A.resjunk = False
                        }
                      , A.TargetEntry
                        { A.targetexpr = A.VAR "OUTER_VAR" "b"
                        , A.targetresname = "b"
                        , A.resjunk = False 
                        }
                      , A.TargetEntry
                        { A.targetexpr = A.VAR "OUTER_VAR" "c"
                        , A.targetresname = "c"
                        , A.resjunk = False 
                        }
                      ]
                    , A.operator =
                        A.PARALLEL A.SEQSCAN
                        { A.targetlist =
                          [ A.TargetEntry
                            { A.targetexpr = A.VAR "indexed" "a"
                            , A.targetresname = "a"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VAR "indexed" "b"
                            , A.targetresname = "b"
                            , A.resjunk = False 
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VAR "indexed" "c"
                            , A.targetresname = "c"
                            , A.resjunk = False 
                            }
                          ]
                        , A.qual = []
                        , A.scanrelation = "indexed"
                        }
                    , A.sortCols = [ A.SortEx 1 True False ]
                    }
                , A.rescan_param = 0
                , A.sortCols = [ A.SortEx 1 True False ]
                }



paragg :: A.Operator
paragg = A.AGG
        { A.targetlist =
          [ A.TargetEntry
            { A.targetexpr = 
              A.AGGREF
              { A.aggname = "sum"
              , A.aggargs =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "OUTER_VAR" "sum"
                  , A.targetresname = "sum"
                  , A.resjunk = False
                  }
                ]
              , A.aggdirectargs = []
              , A.aggorder = []
              , A.aggdistinct = []
              , A.aggfilter = Nothing
              , A.aggstar = False
              }
            , A.targetresname = "sum"
            , A.resjunk = False
            }
          ]
        , A.qual = []
        , A.operator =
          A.GATHER
          { A.targetlist =
            [ A.TargetEntry
              { A.targetexpr = A.VAR "OUTER_VAR" "sum"
              , A.targetresname = "sum"
              , A.resjunk = False
              }
            ]
          , A.operator =
            A.PARALLEL A.AGG
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr =
                  A.AGGREF
                  { A.aggname = "sum"
                  , A.aggargs =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "OUTER_VAR" "id" 
                      , A.targetresname = "sum"
                      , A.resjunk = False
                      }
                    ]
                  , A.aggdirectargs = []
                  , A.aggorder = []
                  , A.aggdistinct = []
                  , A.aggfilter = Nothing
                  , A.aggstar = False
                  }
                , A.targetresname = "sum"
                , A.resjunk = False
                }
              ]
            , A.qual = []
            , A.operator =
              A.PARALLEL A.SEQSCAN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "tb_a" "id"
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
                ]
              , A.qual = []
              , A.scanrelation = "tb_a"
              }
            , A.groupCols = []
            , A.aggstrategy = A.AGG_PLAIN
            , A.aggsplit    = A.aggSPLIT_INITIAL_SERIAL
            }
          , A.num_workers = 10
          , A.rescan_param = 0
          }
        , A.groupCols = []
        , A.aggstrategy = A.AGG_PLAIN
        , A.aggsplit    = A.aggSPLIT_FINAL_DESERIAL
        }

-- ctescan2 :: A.PlannedStmt
-- ctescan2 = A.PlannedStmt
--             { A.planTree =
--               A.NESTLOOP
--               { A.targetlist = 
--                 [ A.TargetEntry
--                   { A.targetexpr = A.VAR "OUTER_VAR" "id"
--                   , A.targetresname = "id"
--                   , A.resjunk = False
--                   }
--                 , A.TargetEntry
--                   { A.targetexpr = A.VAR "INNER_VAR" "id"
--                   , A.targetresname = "id"
--                   , A.resjunk = False
--                   }
--                 ]
--               , A.joinType = A.INNER
--               , A.inner_unique = False
--               , A.joinquals = []
--               , A.nestParams = []
--               , A.lefttree =
--                 A.CTESCAN
--                 { A.targetlist =
--                   [ A.TargetEntry
--                     { A.targetexpr = A.SCANVAR 1
--                     , A.targetresname = "id"
--                     , A.resjunk = False
--                     }
--                   ]
--                 , A.qual = []
--                 , A.ctename = "tb_b"
--                 , A.recursive = False
--                 , A.initPlan = [1]
--                 }
--             , A.righttree =
--                 A.CTESCAN
--                 { A.targetlist =
--                   [ A.TargetEntry
--                     { A.targetexpr = A.SCANVAR 1
--                     , A.targetresname = "id"
--                     , A.resjunk = False
--                     }
--                   ]
--                 , A.qual = []
--                 , A.ctename = "tb_b"
--                 , A.recursive = False
--                 , A.initPlan = [2]
--                 }
--               }
--             , A.subplans =
--               [ A.RESULT
--                 { A.targetlist =
--                   [ A.TargetEntry
--                     { A.targetexpr = A.CONST "1" "int4"
--                     , A.targetresname = "id"
--                     , A.resjunk = False
--                     }
--                   ]
--                 , A.resconstantqual = Nothing
--                 }
--               , A.RESULT
--                 { A.targetlist =
--                   [ A.TargetEntry
--                     { A.targetexpr = A.CONST "41" "int4"
--                     , A.targetresname = "id"
--                     , A.resjunk = False
--                     }
--                   ]
--                 , A.resconstantqual = Nothing
--                 }
--               ]
--             }
ctescan2 :: A.PlannedStmt
ctescan2 = A.PlannedStmt
            { A.planTree =
              A.NESTLOOP
              { A.targetlist = 
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "OUTER_VAR" "x"
                  , A.targetresname = "x"
                  , A.resjunk = False
                  }
                , A.TargetEntry
                  { A.targetexpr = A.VAR "INNER_VAR" "x"
                  , A.targetresname = "x"
                  , A.resjunk = False
                  }
                ]
              , A.joinType = A.INNER
              , A.inner_unique = False
              , A.joinquals = []
              , A.nestParams = []
              , A.lefttree =
                A.CTESCAN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.SCANVAR 1
                    , A.targetresname = "x"
                    , A.resjunk = False
                    }
                  ]
                , A.qual = []
                , A.ctename = "num"
                , A.recursive = False
                , A.initPlan = [1]
                }
            , A.righttree =
                A.CTESCAN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.SCANVAR 1
                    , A.targetresname = "x"
                    , A.resjunk = False
                    }
                  ]
                , A.qual = []
                , A.ctename = "num"
                , A.recursive = False
                , A.initPlan = [2]
                }
              }
            , A.subplans =
              [ A.RESULT
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.CONST "1" "int4"
                    , A.targetresname = "x"
                    , A.resjunk = False
                    }
                  ]
                , A.resconstantqual = Nothing
                }
              , A.RESULT
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.CONST "41" "int4"
                    , A.targetresname = "x"
                    , A.resjunk = False
                    }
                  ]
                , A.resconstantqual = Nothing
                }
              ]
            }

--------------------------------------------------------------------------------
-- NEUMANN UNNESTING Q1

neumannQ1 :: A.PlannedStmt
neumannQ1 = A.PlannedStmt
            { A.planTree =
              A.HASHJOIN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VAR "OUTER_VAR" "name"
                  , A.targetresname = "name"
                  , A.resjunk = False
                  }
                , A.TargetEntry
                  { A.targetexpr = A.VAR "INNER_VAR" "course"
                  , A.targetresname = "course"
                  , A.resjunk = False
                  }
                ]
              , A.joinType = A.INNER
              , A.inner_unique = False
              , A.joinquals = []
              , A.hashclauses =
                [ A.OPEXPR
                  { A.oprname = "="
                  , A.oprargs =
                    [ A.VAR "OUTER_VAR" "id"
                    , A.VAR "INNER_VAR" "sid"
                    ]
                  }
                , A.OPEXPR
                  { A.oprname = "="
                  , A.oprargs =
                    [ A.SUBPLAN                           -- FIXME
                      { A.sublinkType = A.EXPR_SUBLINK
                      , A.testExpr = Nothing
                      , A.paramIds = []
                      , A.plan_id = 1
                      , A.plan_name = "Subplan1"
                      , A.firstColType = "int4"
                      , A.setParam = []
                      , A.parParam=[0]
                      , A.args =
                        [ A.VAR "OUTER_VAR" "id" ]
                      }
                    , A.VAR "INNER_VAR" "grade"
                    ]
                  }
                ]
              , A.lefttree =
                A.SEQSCAN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "students" "id"
                    , A.targetresname = "id"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "students" "name"
                    , A.targetresname = "name"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "students" "major"
                    , A.targetresname = "major"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "students" "year"
                    , A.targetresname = "year"
                    , A.resjunk = False
                    }
                  ]
                , A.qual = []
                , A.scanrelation = "students"
                }
              , A.righttree =
                A.HASH
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "sid"
                    , A.targetresname = "sid"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "course"
                    , A.targetresname = "course"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VAR "OUTER_VAR" "grade"
                    , A.targetresname = "grade"
                    , A.resjunk = False
                    }
                  ]
                , A.operator =
                  A.SEQSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "exams" "sid"
                      , A.targetresname = "sid"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VAR "exams" "course"
                      , A.targetresname = "course"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VAR "exams" "grade"
                      , A.targetresname = "grade"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.scanrelation = "exams"
                  }
                , A.skewTable = "exams"
                , A.skewColumn = 0
                }
              }
            , A.subplans =
              [ A.AGG
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr =
                      A.AGGREF
                      { A.aggname = "min"
                      , A.aggargs =
                        [ A.TargetEntry
                          { A.targetexpr = A.VAR "OUTER_VAR" "grade"
                          , A.targetresname = "grade"
                          , A.resjunk = False
                          }
                        ]
                      , A.aggdirectargs = []
                      , A.aggorder = []
                      , A.aggdistinct = []
                      , A.aggfilter = Nothing
                      , A.aggstar = False
                      }
                    , A.targetresname = "min"
                    , A.resjunk = False
                    }
                  ]
                , A.qual = []
                , A.operator =
                  A.SEQSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VAR "exams" "grade"
                      , A.targetresname = "grade"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual =
                    [ A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.PARAM -- FIXME
                          { A.paramkind = A.PARAM_EXEC
                          , A.paramid   = 0
                          , A.paramtype = "int4"
                          }
                        , A.VAR "exams" "sid"
                        ]
                      }
                    ]
                  , A.scanrelation = "exams"
                  }
                , A.groupCols = []
                , A.aggstrategy = A.AGG_PLAIN
                , A.aggsplit    = [A.AGGSPLITOP_SIMPLE]
                }
              ]
            }

neumannQ1' :: A.PlannedStmt
neumannQ1' = A.PlannedStmt
              { A.planTree =
                A.HASHJOIN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VARPOS "OUTER_VAR" 2
                    , A.targetresname = "name"
                    , A.resjunk = False
                    }
                  , A.TargetEntry
                    { A.targetexpr = A.VARPOS "INNER_VAR" 1
                    , A.targetresname= "course"
                    , A.resjunk = False
                    }
                  ]
                , A.joinType = A.INNER
                , A.inner_unique = False
                , A.joinquals = []
                , A.hashclauses =
                  [ A.OPEXPR
                    { A.oprname = "="
                    , A.oprargs =
                      [ A.VARPOS "OUTER_VAR" 1
                      , A.VARPOS "INNER_VAR" 2
                      ]
                    }
                  ]
                , A.lefttree =
                  A.SEQSCAN
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VARPOS "students" 1
                      , A.targetresname = "id"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VARPOS "students" 2
                      , A.targetresname = "name"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VARPOS "students" 3
                      , A.targetresname = "major"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VARPOS "students" 4
                      , A.targetresname = "year"
                      , A.resjunk = False
                      }
                    ]
                  , A.qual = []
                  , A.scanrelation = "students"
                  }
                , A.righttree =
                  A.HASH
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VARPOS "OUTER_VAR" 1
                      , A.targetresname = "sid"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VARPOS "OUTER_VAR" 2
                      , A.targetresname = "min"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VARPOS "OUTER_VAR" 3
                      , A.targetresname = "course"
                      , A.resjunk = False
                      }
                    ]
                  , A.operator =
                    A.HASHJOIN
                    { A.targetlist =
                      [ A.TargetEntry
                        { A.targetexpr = A.VARPOS "INNER_VAR" 1
                        , A.targetresname = "course"
                        , A.resjunk = False
                        }
                      , A.TargetEntry
                        { A.targetexpr = A.VARPOS "INNER_VAR" 2
                        , A.targetresname = "sid"
                        , A.resjunk = False
                        }
                      , A.TargetEntry
                        { A.targetexpr = A.VARPOS "OUTER_VAR" 1
                        , A.targetresname = "min"
                        , A.resjunk = False
                        }
                      ]
                    , A.joinType = A.INNER
                    , A.inner_unique = False
                    , A.joinquals =
                      []
                    , A.hashclauses =
                      [ A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                          [ A.VARPOS "OUTER_VAR" 1
                          , A.VARPOS "INNER_VAR" 2
                          ]
                        }
                      , A.OPEXPR
                        { A.oprname = "="
                        , A.oprargs =
                          [ A.VARPOS "OUTER_VAR" 2
                          , A.VARPOS "INNER_VAR" 3
                          ]
                        }
                      ]
                    , A.lefttree =
                      A.AGG
                      { A.targetlist =
                        [ A.TargetEntry
                          { A.targetexpr = A.VARPOS "OUTER_VAR" 1
                          , A.targetresname = "sid"
                          , A.resjunk = False
                          }
                        , A.TargetEntry
                          { A.targetexpr =
                            A.AGGREF
                            { A.aggname = "min"
                            , A.aggargs =
                              [ A.TargetEntry
                                { A.targetexpr = A.VARPOS "OUTER_VAR" 5
                                , A.targetresname = "grade"
                                , A.resjunk = False
                                }
                              ]
                            , A.aggdirectargs = []
                            , A.aggorder = []
                            , A.aggdistinct = []
                            , A.aggfilter = Nothing
                            , A.aggstar = False
                            }
                          , A.targetresname = "min"
                          , A.resjunk = False }
                        ]
                      , A.qual = []
                      , A.operator =
                        A.SEQSCAN
                        { A.targetlist =
                          [ A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 1
                            , A.targetresname = "sid"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 2
                            , A.targetresname = "course"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 3
                            , A.targetresname = "curriculum"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 4
                            , A.targetresname = "date"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 5
                            , A.targetresname = "grade"
                            , A.resjunk = False
                            }
                          ]
                        , A.qual = []
                        , A.scanrelation = "exams"
                        }
                      , A.groupCols = [1]
                      , A.aggstrategy = A.AGG_HASHED
                      , A.aggsplit    = [A.AGGSPLITOP_SIMPLE]
                      }
                    , A.righttree =
                      A.HASH
                      { A.targetlist =
                        [ A.TargetEntry
                          { A.targetexpr = A.VARPOS "OUTER_VAR" 1
                          , A.targetresname = "course"
                          , A.resjunk = False
                          }
                        , A.TargetEntry
                          { A.targetexpr = A.VARPOS "OUTER_VAR" 2
                          , A.targetresname = "sid"
                          , A.resjunk = False
                          }
                        , A.TargetEntry
                          { A.targetexpr = A.VARPOS "OUTER_VAR" 3
                          , A.targetresname = "grade"
                          , A.resjunk = False
                          }
                        ]
                      , A.operator =
                        A.SEQSCAN
                        { A.targetlist =
                          [ A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 2
                            , A.targetresname = "course"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 1
                            , A.targetresname = "sid"
                            , A.resjunk = False
                            }
                          , A.TargetEntry
                            { A.targetexpr = A.VARPOS "exams" 5
                            , A.targetresname = "grade"
                            , A.resjunk = False
                            }
                          ]
                        , A.qual = []
                        , A.scanrelation = "exams"
                        }
                      , A.skewTable = "exams"
                      , A.skewColumn = 0
                      }
                    }
                  , A.skewTable = "students"
                  , A.skewColumn = 1
                  }
                }
              , A.subplans =
                []
              }

seqExams :: A.Operator
seqExams = A.SEQSCAN
            { A.targetlist =
              [ A.TargetEntry
                { A.targetexpr = A.VARPOS "tb_a" 1
                , A.targetresname = "sid"
                , A.resjunk = False
                }
              
              ]
            , A.qual = []
            , A.scanrelation = "tb_a"
            }

seqStudents :: A.Operator
seqStudents = A.SEQSCAN
              { A.targetlist =
                [ A.TargetEntry
                  { A.targetexpr = A.VARPOS "tb_b" 1
                  , A.targetresname = "id"
                  , A.resjunk = False
                  }
              
                ]
              , A.qual = []
              , A.scanrelation = "tb_b"
              }

j1 :: A.Operator
j1 = A.HASHJOIN
      { A.targetlist =
        [ A.TargetEntry
          { A.targetexpr = A.VARPOS "OUTER_VAR" 2
          , A.targetresname = "name"
          , A.resjunk = False
          }
        , A.TargetEntry
          { A.targetexpr = A.VARPOS "OUTER_VAR" 1
          , A.targetresname = "id"
          , A.resjunk = False
          }
        , A.TargetEntry
          { A.targetexpr = A.VARPOS "INNER_VAR" 2
          , A.targetresname = "course"
          , A.resjunk = False
          }
        , A.TargetEntry
          { A.targetexpr = A.VARPOS "INNER_VAR" 5
          , A.targetresname = "grade"
          , A.resjunk = False
          }
        ]
      , A.joinType = A.INNER
      , A.inner_unique = False
      , A.joinquals = []
      , A.hashclauses =
        [ A.OPEXPR
          { A.oprname = "="
          , A.oprargs =
            [ A.VARPOS "OUTER_VAR" 1
            , A.VARPOS "INNER_VAR" 1
            ]
          }
        ]
      , A.lefttree = seqStudents
      , A.righttree =
        A.HASH
        { A.targetlist =
          [ A.TargetEntry
            { A.targetexpr = A.VARPOS "exams" 1
            , A.targetresname = "sid"
            , A.resjunk = False
            }
          , A.TargetEntry
            { A.targetexpr = A.VARPOS "exams" 2
            , A.targetresname = "course"
            , A.resjunk = False
            }
          , A.TargetEntry
            { A.targetexpr = A.VARPOS "exams" 3
            , A.targetresname = "curriculum"
            , A.resjunk = False
            }
          , A.TargetEntry
            { A.targetexpr = A.VARPOS "exams" 4
            , A.targetresname = "date"
            , A.resjunk = False
            }
          , A.TargetEntry
            { A.targetexpr = A.VARPOS "exams" 5
            , A.targetresname = "grade"
            , A.resjunk = False
            }
          ]
        , A.operator = seqExams
        , A.skewTable = "exams"
        , A.skewColumn = 0
        }
      }

s1 :: A.Operator
s1 = A.AGG
      { A.targetlist =
        [ A.TargetEntry
          { A.targetexpr = A.VARPOS "OUTER_VAR" 1
          , A.targetresname = "sid"
          , A.resjunk = False
          }
        , A.TargetEntry
          { A.targetexpr =
            A.AGGREF
            { A.aggname = "min"
            , A.aggargs =
              [ A.TargetEntry
                { A.targetexpr = A.VARPOS "OUTER_VAR" 5
                , A.targetresname = "grade"
                , A.resjunk = False
                }
              ]
            , A.aggdirectargs = []
            , A.aggorder = []
            , A.aggdistinct = []
            , A.aggfilter = Nothing
            , A.aggstar = False
            }
          , A.targetresname = "min"
          , A.resjunk = False
          }
        ]
      , A.qual = []
      , A.operator = seqExams
      , A.groupCols = [1]
      , A.aggstrategy = A.AGG_HASHED
      , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
      }

neumannQ1'' :: A.PlannedStmt
neumannQ1'' = A.PlannedStmt
              { A.planTree =
                A.HASHJOIN
                { A.targetlist =
                  [ A.TargetEntry
                    { A.targetexpr = A.VARPOS "OUTER_VAR" 1
                    , A.targetresname = "name"
                    , A.resjunk = False
                    }
                  -- , A.TargetEntry
                  --   { A.targetexpr = A.VARPOS "INNER_VAR" 2
                  --   , A.targetresname = "course"
                  --   , A.resjunk = False
                  --   }
                  , A.TargetEntry
                    { A.targetexpr = A.VARPOS "OUTER_VAR" 3
                    , A.targetresname = "course"
                    , A.resjunk = False
                    }
                  ]
                , A.joinType = A.INNER
                , A.inner_unique = False
                , A.joinquals =
                  [ A.OPEXPR
                    { A.oprname = "="
                    , A.oprargs =
                      [ A.VARPOS "OUTER_VAR" 4
                      , A.VARPOS "INNER_VAR" 2
                      ]
                    }
                  ]
                , A.hashclauses =
                  [ A.OPEXPR
                    { A.oprname = "="
                    , A.oprargs =
                      [ A.VARPOS "OUTER_VAR" 2
                      , A.VARPOS "INNER_VAR" 1
                      ]
                    }
                  ]
                , A.lefttree = j1
                , A.righttree =
                  A.HASH
                  { A.targetlist =
                    [ A.TargetEntry
                      { A.targetexpr = A.VARPOS "OUTER_VAR" 1
                      , A.targetresname = "sid"
                      , A.resjunk = False
                      }
                    , A.TargetEntry
                      { A.targetexpr = A.VARPOS "OUTER_VAR" 2
                      , A.targetresname = "grade"
                      , A.resjunk = False
                      }
                    ]
                  , A.operator = s1
                  , A.skewTable = "exams"
                  , A.skewColumn = 0
                  }
                }
              , A.subplans = []
              }

--------------------------------------------------------------------------------
-- NEUMANN unnesting Q2

seqStudentsFilter = seqStudents 
                    { A.qual = 
                      [ A.OR
                        { A.args =
                          [ A.OPEXPR
                            { A.oprname = "="
                            , A.oprargs =
                              [  A.VAR "tb_b" "id"
                                , A.CONST "1" "int4"
                              ]
                            }
                          , A.OPEXPR
                            { A.oprname = "="
                            , A.oprargs =
                              [  A.VAR "tb_b" "id"
                                , A.CONST "1" "int4"
                              ]
                            }
                          ]
                        }
                      ]
                    }

q2Join1 = A.HASHJOIN
          { A.targetlist =
            [ 
            defCol "OUTER_VAR" "id"
            ]
          , A.joinType = A.INNER
          , A.inner_unique = False
          , A.joinquals = []
          , A.hashclauses =
            [ A.OPEXPR
              { A.oprname = "="
              , A.oprargs =
                [ A.VARPOS "OUTER_VAR" 1
                , A.VARPOS "INNER_VAR" 1
                ]
              }
            ]
          , A.lefttree = seqStudentsFilter
          , A.righttree =
            A.HASH
            { A.targetlist =
              [ defCol "tb_a" "id"
             
              ]
            , A.operator =
              seqExams
            , A.skewTable = "tb_a"
            , A.skewColumn = 0
            }
          }

q2Join2 = A.HASHJOIN
          { A.targetlist =
            [ defCol "tb_b" "id"
            ]
          , A.joinType = A.INNER
          , A.inner_unique = False
          , A.joinquals =
            [ 
            ]
          , A.hashclauses =
            [ A.OPEXPR
              { A.oprname = "="
              , A.oprargs =
                [ A.VARPOS "OUTER_VAR" 1
                , A.VARPOS "INNER_VAR" 1
                ]
              }
            ]
          , A.lefttree = q2Join1
          , A.righttree =
            A.HASH
            { A.targetlist =
              [ defCol "tb_b" "id"
              
              ]
            , A.operator =
              seqExams
            , A.skewTable = "tb_a"
            , A.skewColumn = 0
            }
          }

q2Agg = A.AGG
        { A.targetlist =
          [ defCol "OUTER_VAR" "id"
          , A.TargetEntry
            { A.targetexpr =
              A.AGGREF
              { A.aggname = "avg"
              , A.aggargs =
                [ defCol "OUTER_VAR" "id"
                ]
              , A.aggdirectargs = []
              , A.aggorder = []
              , A.aggdistinct = []
              , A.aggfilter = Nothing
              , A.aggstar = False
              }
            , A.targetresname = "avg"
            , A.resjunk = False
            }
          ]
        , A.qual = []
        , A.operator = q2Join2
        , A.groupCols = [1]
        , A.aggstrategy = A.AGG_HASHED
        , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
        }
material1 = A.MATERIAL q2Agg
material = A.MATERIAL unique1
q2Join3 = A.NESTLOOP
          { A.targetlist =
            [ defCol "OUTER_VAR" "id"
            ]
          , A.joinType = A.INNER
          , A.inner_unique = False
          , A.joinquals =
            [ A.OPEXPR
              { A.oprname = ">="
              , A.oprargs =
                [ A.FUNCEXPR
                  { A.funcname = "numeric"
                  , A.funcargs = [ A.VARPOS "OUTER_VAR" 8 ]
                  }
                , A.OPEXPR
                  { A.oprname = "+"
                  , A.oprargs =
                    [ A.VARPOS "INNER_VAR" 4
                    , A.CONST "1" "numeric"
                    ]
                  }
                ]
              }
            , A.OR
              { A.args =
                [ A.OPEXPR
                  { A.oprname = "="
                  , A.oprargs =
                    [ A.VARPOS "INNER_VAR" 1
                    , A.VARPOS "OUTER_VAR" 2
                    ]
                  }
                , A.AND
                  { A.args =
                    [ A.OPEXPR
                      { A.oprname = ">"
                      , A.oprargs =
                        [ A.VARPOS "INNER_VAR" 2
                        , A.VARPOS "OUTER_VAR" 7
                        ]
                      }
                    , A.OPEXPR
                      { A.oprname = "="
                      , A.oprargs =
                        [ A.VARPOS "OUTER_VAR" 6
                        , A.VARPOS "INNER_VAR" 3
                        ]
                      }
                    ]
                  }
                ]
              }
            ]
          , A.nestParams =
            []
          , A.lefttree = q2Join1
          , A.righttree = A.MATERIAL q2Agg
          
          }

neumannQ2 :: A.PlannedStmt
neumannQ2 = A.PlannedStmt
            { A.planTree = q2Join3
            , A.subplans = []
            }

--
--------------------------------------------------------------------------------
-- TPC-H Q21

defCol :: String -> String -> A.TargetEntry
defCol t c = A.TargetEntry
          { A.targetexpr = A.VAR t c
          , A.targetresname = c
          , A.resjunk = False
          }

seqNation :: A.Operator
seqNation = A.SEQSCAN
            { A.targetlist =
              [ defCol "nation" "n_nationkey"
              , defCol "nation" "n_name"
              , defCol "nation" "n_regionkey"
              , defCol "nation" "n_comment"
              ]
            , A.qual = 
              [ A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "nation" "n_name"
                  , A.CONST "VIETNAM" "bpchar"
                  ]
                }
              ]
            , A.scanrelation = "nation"
            }

seqSupplier :: A.Operator
seqSupplier = A.SEQSCAN
              { A.targetlist =
                [ defCol "supplier" "s_suppkey"
                , defCol "supplier" "s_name"
                , defCol "supplier" "s_address"
                , defCol "supplier" "s_nationkey"
                , defCol "supplier" "s_phone"
                , defCol "supplier" "s_acctbal"
                , defCol "supplier" "s_comment"
                ]
              , A.qual = []
              , A.scanrelation = "supplier"
              }

tpc21j1 :: A.Operator
tpc21j1 = A.HASHJOIN
    { A.targetlist =
      [ defCol "OUTER_VAR" "n_nationkey"
      , defCol "OUTER_VAR" "n_name"
      , defCol "OUTER_VAR" "n_regionkey"
      , defCol "OUTER_VAR" "n_comment"
      , defCol "INNER_VAR" "s_suppkey"
      , defCol "INNER_VAR" "s_name"
      , defCol "INNER_VAR" "s_address"
      , defCol "INNER_VAR" "s_nationkey"
      , defCol "INNER_VAR" "s_phone"
      , defCol "INNER_VAR" "s_acctbal"
      , defCol "INNER_VAR" "s_comment"
      ]
    , A.joinType = A.INNER
    , A.inner_unique = False
    , A.joinquals = []
    , A.hashclauses =
      [ A.OPEXPR
        { A.oprname = "="
        , A.oprargs =
          [ A.VARPOS "OUTER_VAR" 1
          , A.VARPOS "INNER_VAR" 4 ]
        }
      ]
    , A.lefttree = seqNation
    , A.righttree =
      A.HASH
      { A.targetlist =
        [ defCol "OUTER_VAR" "s_suppkey"
        , defCol "OUTER_VAR" "s_name"
        , defCol "OUTER_VAR" "s_address"
        , defCol "OUTER_VAR" "s_nationkey"
        , defCol "OUTER_VAR" "s_phone"
        , defCol "OUTER_VAR" "s_acctbal"
        , defCol "OUTER_VAR" "s_comment"
        ]
      , A.operator = seqSupplier
      , A.skewTable = "supplier"
      , A.skewColumn = 0
      }
    }

seqLineitem :: A.Operator
seqLineitem = A.SEQSCAN
              { A.targetlist =
                [ defCol "lineitem" "l_orderkey"
                , defCol "lineitem" "l_partkey"
                , defCol "lineitem" "l_suppkey"
                , defCol "lineitem" "l_linenumber"
                , defCol "lineitem" "l_quantity"
                , defCol "lineitem" "l_extendedprice"
                , defCol "lineitem" "l_discount"
                , defCol "lineitem" "l_tax"
                , defCol "lineitem" "l_returnflag"
                , defCol "lineitem" "l_linestatus"
                , defCol "lineitem" "l_shipdate"
                , defCol "lineitem" "l_commitdate"
                , defCol "lineitem" "l_receiptdate"
                , defCol "lineitem" "l_shipinstruct"
                , defCol "lineitem" "l_shipmode"
                , defCol "lineitem" "l_comment"
                ]
              , A.qual = []
              , A.scanrelation = "lineitem"
              }

tpc21j2 :: A.Operator
tpc21j2 = A.HASHJOIN
          { A.targetlist =
            [ defCol "OUTER_VAR" "n_nationkey"
            , defCol "OUTER_VAR" "n_name"
            , defCol "OUTER_VAR" "n_regionkey"
            , defCol "OUTER_VAR" "n_comment"
            , defCol "OUTER_VAR" "s_suppkey"
            , defCol "OUTER_VAR" "s_name"
            , defCol "OUTER_VAR" "s_address"
            , defCol "OUTER_VAR" "s_nationkey"
            , defCol "OUTER_VAR" "s_phone"
            , defCol "OUTER_VAR" "s_acctbal"
            , defCol "OUTER_VAR" "s_comment"
            , defCol "INNER_VAR" "l_orderkey"
            , defCol "INNER_VAR" "l_partkey"
            , defCol "INNER_VAR" "l_suppkey"
            , defCol "INNER_VAR" "l_linenumber"
            , defCol "INNER_VAR" "l_quantity"
            , defCol "INNER_VAR" "l_extendedprice"
            , defCol "INNER_VAR" "l_discount"
            , defCol "INNER_VAR" "l_tax"
            , defCol "INNER_VAR" "l_returnflag"
            , defCol "INNER_VAR" "l_linestatus"
            , defCol "INNER_VAR" "l_shipdate"
            , defCol "INNER_VAR" "l_commitdate"
            , defCol "INNER_VAR" "l_receiptdate"
            , defCol "INNER_VAR" "l_shipinstruct"
            , defCol "INNER_VAR" "l_shipmode"
            , defCol "INNER_VAR" "l_comment"
            ]
          , A.joinType = A.INNER
          , A.inner_unique = False
          , A.joinquals = []
          , A.hashclauses =
            [ A.OPEXPR
              { A.oprname = "="
              , A.oprargs =
                [ A.VAR "OUTER_VAR" "s_suppkey"
                , A.VAR "INNER_VAR" "l_suppkey"
                ]
              }
            ]
          , A.lefttree = tpc21j1
          , A.righttree =
            A.HASH
            { A.targetlist =
              [ defCol "OUTER_VAR" "l_orderkey"
              , defCol "OUTER_VAR" "l_partkey"
              , defCol "OUTER_VAR" "l_suppkey"
              , defCol "OUTER_VAR" "l_linenumber"
              , defCol "OUTER_VAR" "l_quantity"
              , defCol "OUTER_VAR" "l_extendedprice"
              , defCol "OUTER_VAR" "l_discount"
              , defCol "OUTER_VAR" "l_tax"
              , defCol "OUTER_VAR" "l_returnflag"
              , defCol "OUTER_VAR" "l_linestatus"
              , defCol "OUTER_VAR" "l_shipdate"
              , defCol "OUTER_VAR" "l_commitdate"
              , defCol "OUTER_VAR" "l_receiptdate"
              , defCol "OUTER_VAR" "l_shipinstruct"
              , defCol "OUTER_VAR" "l_shipmode"
              , defCol "OUTER_VAR" "l_comment"
              ]
            , A.operator = seqLineitem
                            { A.qual =
                              [ A.OPEXPR
                                { A.oprname = ">"
                                , A.oprargs =
                                  [ A.VAR "lineitem" "l_receiptdate"
                                  , A.VAR "lineitem" "l_commitdate"
                                  ]
                                }
                              ]
                            }
            , A.skewTable = "lineitem"
            , A.skewColumn = 3
            }
          }

seqOrders :: A.Operator
seqOrders = A.SEQSCAN
            { A.targetlist =
              [ defCol "orders" "o_orderkey"
              , defCol "orders" "o_custkey"
              , defCol "orders" "o_orderstatus"
              , defCol "orders" "o_totalprice"
              , defCol "orders" "o_orderdate"
              , defCol "orders" "o_orderpriority"
              , defCol "orders" "o_clerk"
              , defCol "orders" "o_shippriority"
              , defCol "orders" "o_comment"
              ]
            , A.qual =
              [ A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "orders" "o_orderstatus"
                  , A.CONST "F" "bpchar"
                  ]
                }
              ]
            , A.scanrelation = "orders" }

tpc21j3 :: A.Operator
tpc21j3 = A.HASHJOIN
          { A.targetlist =
            [ defCol "OUTER_VAR" "n_nationkey"
            , defCol "OUTER_VAR" "n_name"
            , defCol "OUTER_VAR" "n_regionkey"
            , defCol "OUTER_VAR" "n_comment"
            , defCol "OUTER_VAR" "s_suppkey"
            , defCol "OUTER_VAR" "s_name"
            , defCol "OUTER_VAR" "s_address"
            , defCol "OUTER_VAR" "s_nationkey"
            , defCol "OUTER_VAR" "s_phone"
            , defCol "OUTER_VAR" "s_acctbal"
            , defCol "OUTER_VAR" "s_comment"
            , defCol "OUTER_VAR" "l_orderkey"
            , defCol "OUTER_VAR" "l_partkey"
            , defCol "OUTER_VAR" "l_suppkey"
            , defCol "OUTER_VAR" "l_linenumber"
            , defCol "OUTER_VAR" "l_quantity"
            , defCol "OUTER_VAR" "l_extendedprice"
            , defCol "OUTER_VAR" "l_discount"
            , defCol "OUTER_VAR" "l_tax"
            , defCol "OUTER_VAR" "l_returnflag"
            , defCol "OUTER_VAR" "l_linestatus"
            , defCol "OUTER_VAR" "l_shipdate"
            , defCol "OUTER_VAR" "l_commitdate"
            , defCol "OUTER_VAR" "l_receiptdate"
            , defCol "OUTER_VAR" "l_shipinstruct"
            , defCol "OUTER_VAR" "l_shipmode"
            , defCol "OUTER_VAR" "l_comment"
            , defCol "INNER_VAR" "o_orderkey"
            , defCol "INNER_VAR" "o_custkey"
            , defCol "INNER_VAR" "o_orderstatus"
            , defCol "INNER_VAR" "o_totalprice"
            , defCol "INNER_VAR" "o_orderdate"
            , defCol "INNER_VAR" "o_orderpriority"
            , defCol "INNER_VAR" "o_clerk"
            , defCol "INNER_VAR" "o_shippriority"
            , defCol "INNER_VAR" "o_comment"
            ]
          , A.joinType = A.INNER
          , A.inner_unique = False
          , A.joinquals = []
          , A.hashclauses =
            [ A.OPEXPR
              { A.oprname = "="
              , A.oprargs =
                [ A.VAR "OUTER_VAR" "l_orderkey"
                , A.VAR "INNER_VAR" "o_orderkey"
                ]
              }
            ]
          , A.lefttree = tpc21j2
          , A.righttree =
            A.HASH
            { A.targetlist =
              [ defCol "OUTER_VAR" "o_orderkey"
              , defCol "OUTER_VAR" "o_custkey"
              , defCol "OUTER_VAR" "o_orderstatus"
              , defCol "OUTER_VAR" "o_totalprice"
              , defCol "OUTER_VAR" "o_orderdate"
              , defCol "OUTER_VAR" "o_orderpriority"
              , defCol "OUTER_VAR" "o_clerk"
              , defCol "OUTER_VAR" "o_shippriority"
              , defCol "OUTER_VAR" "o_comment"]
            , A.operator = seqOrders
            , A.skewTable = "orders"
            , A.skewColumn = 0
            }
          }

tpc21j3Index :: A.Operator
tpc21j3Index = A.NESTLOOP
          { A.targetlist =
            [ defCol "OUTER_VAR" "n_nationkey"
            , defCol "OUTER_VAR" "n_name"
            , defCol "OUTER_VAR" "n_regionkey"
            , defCol "OUTER_VAR" "n_comment"
            , defCol "OUTER_VAR" "s_suppkey"
            , defCol "OUTER_VAR" "s_name"
            , defCol "OUTER_VAR" "s_address"
            , defCol "OUTER_VAR" "s_nationkey"
            , defCol "OUTER_VAR" "s_phone"
            , defCol "OUTER_VAR" "s_acctbal"
            , defCol "OUTER_VAR" "s_comment"
            , defCol "OUTER_VAR" "l_orderkey"
            , defCol "OUTER_VAR" "l_partkey"
            , defCol "OUTER_VAR" "l_suppkey"
            , defCol "OUTER_VAR" "l_linenumber"
            , defCol "OUTER_VAR" "l_quantity"
            , defCol "OUTER_VAR" "l_extendedprice"
            , defCol "OUTER_VAR" "l_discount"
            , defCol "OUTER_VAR" "l_tax"
            , defCol "OUTER_VAR" "l_returnflag"
            , defCol "OUTER_VAR" "l_linestatus"
            , defCol "OUTER_VAR" "l_shipdate"
            , defCol "OUTER_VAR" "l_commitdate"
            , defCol "OUTER_VAR" "l_receiptdate"
            , defCol "OUTER_VAR" "l_shipinstruct"
            , defCol "OUTER_VAR" "l_shipmode"
            , defCol "OUTER_VAR" "l_comment"
            , defCol "INNER_VAR" "o_orderkey"
            , defCol "INNER_VAR" "o_custkey"
            , defCol "INNER_VAR" "o_orderstatus"
            , defCol "INNER_VAR" "o_totalprice"
            , defCol "INNER_VAR" "o_orderdate"
            , defCol "INNER_VAR" "o_orderpriority"
            , defCol "INNER_VAR" "o_clerk"
            , defCol "INNER_VAR" "o_shippriority"
            , defCol "INNER_VAR" "o_comment"
            ]
          , A.joinType = A.INNER
          , A.inner_unique = False
          , A.joinquals = []
              -- [ A.OPEXPR
              --   { A.oprname = "="
              --   , A.oprargs =
              --     [ A.VAR "OUTER_VAR" "l_orderkey"
              --     , A.VAR "INNER_VAR" "o_orderkey"
              --     ]
              --   }
              -- ]
          , A.nestParams =
            [ A.NestLoopParam 0 (A.VAR "OUTER_VAR" "l_orderkey")]
          , A.lefttree = tpc21j2
          , A.righttree =
            A.INDEXSCAN
            { A.targetlist =
              [ defCol "orders" "o_orderkey"
              , defCol "orders" "o_custkey"
              , defCol "orders" "o_orderstatus"
              , defCol "orders" "o_totalprice"
              , defCol "orders" "o_orderdate"
              , defCol "orders" "o_orderpriority"
              , defCol "orders" "o_clerk"
              , defCol "orders" "o_shippriority"
              , defCol "orders" "o_comment"
              ]
            , A.qual =
              [ A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "orders" "o_orderstatus"
                  , A.CONST "F" "bpchar"
                  ]
                }
              ]
            , A.indexqual =
              [ A.OPEXPR
                { A.oprname = "="
                , A.oprargs =
                  [ A.VAR "INDEX_VAR" "o_orderkey"
                  , A.PARAM A.PARAM_EXEC 0 "int4"
                  ]
                }
              ]
            , A.indexorderby = []
            , A.indexorderasc = True
            , A.indexname = "o_orderkey_idx"
            , A.scanrelation = "orders"
            }
          }


tpc21j4 :: A.Operator
tpc21j4 = A.HASHJOIN
          { A.targetlist =
            [ defCol "OUTER_VAR" "n_nationkey"
            , defCol "OUTER_VAR" "n_name"
            , defCol "OUTER_VAR" "n_regionkey"
            , defCol "OUTER_VAR" "n_comment"
            , defCol "OUTER_VAR" "s_suppkey"
            , defCol "OUTER_VAR" "s_name"
            , defCol "OUTER_VAR" "s_address"
            , defCol "OUTER_VAR" "s_nationkey"
            , defCol "OUTER_VAR" "s_phone"
            , defCol "OUTER_VAR" "s_acctbal"
            , defCol "OUTER_VAR" "s_comment"
            , defCol "OUTER_VAR" "l_orderkey"
            , defCol "OUTER_VAR" "l_partkey"
            , defCol "OUTER_VAR" "l_suppkey"
            , defCol "OUTER_VAR" "l_linenumber"
            , defCol "OUTER_VAR" "l_quantity"
            , defCol "OUTER_VAR" "l_extendedprice"
            , defCol "OUTER_VAR" "l_discount"
            , defCol "OUTER_VAR" "l_tax"
            , defCol "OUTER_VAR" "l_returnflag"
            , defCol "OUTER_VAR" "l_linestatus"
            , defCol "OUTER_VAR" "l_shipdate"
            , defCol "OUTER_VAR" "l_commitdate"
            , defCol "OUTER_VAR" "l_receiptdate"
            , defCol "OUTER_VAR" "l_shipinstruct"
            , defCol "OUTER_VAR" "l_shipmode"
            , defCol "OUTER_VAR" "l_comment"
            , defCol "OUTER_VAR" "o_orderkey"
            , defCol "OUTER_VAR" "o_custkey"
            , defCol "OUTER_VAR" "o_orderstatus"
            , defCol "OUTER_VAR" "o_totalprice"
            , defCol "OUTER_VAR" "o_orderdate"
            , defCol "OUTER_VAR" "o_orderpriority"
            , defCol "OUTER_VAR" "o_clerk"
            , defCol "OUTER_VAR" "o_shippriority"
            , defCol "OUTER_VAR" "o_comment"
            ]
          , A.joinType = A.ANTI
          , A.inner_unique = False
          , A.joinquals =
            [ A.OPEXPR
              { A.oprname = "<>"
              , A.oprargs = 
                [ A.VAR "OUTER_VAR" "l_suppkey"
                , A.VAR "INNER_VAR" "l_suppkey"
                ]
              }
            ]
          , A.hashclauses =
            [ A.OPEXPR
              { A.oprname = "="
              , A.oprargs =
                [ A.VAR "OUTER_VAR" "l_orderkey"
                , A.VAR "INNER_VAR" "l_orderkey"
                ]
              }
            ]
          , A.lefttree = tpc21j3Index
          , A.righttree =
            A.HASH
            { A.targetlist =
              [ defCol "OUTER_VAR" "l_orderkey"
              , defCol "OUTER_VAR" "l_partkey"
              , defCol "OUTER_VAR" "l_suppkey"
              , defCol "OUTER_VAR" "l_linenumber"
              , defCol "OUTER_VAR" "l_quantity"
              , defCol "OUTER_VAR" "l_extendedprice"
              , defCol "OUTER_VAR" "l_discount"
              , defCol "OUTER_VAR" "l_tax"
              , defCol "OUTER_VAR" "l_returnflag"
              , defCol "OUTER_VAR" "l_linestatus"
              , defCol "OUTER_VAR" "l_shipdate"
              , defCol "OUTER_VAR" "l_commitdate"
              , defCol "OUTER_VAR" "l_receiptdate"
              , defCol "OUTER_VAR" "l_shipinstruct"
              , defCol "OUTER_VAR" "l_shipmode"
              , defCol "OUTER_VAR" "l_comment"
              ]
            , A.operator = seqLineitem
                            { A.qual =
                              [ A.OPEXPR
                                { A.oprname = ">"
                                , A.oprargs =
                                  [ A.VAR "lineitem" "l_receiptdate"
                                  , A.VAR "lineitem" "l_commitdate"
                                  ]
                                }
                              ]
                            }
            , A.skewTable = "lineitem"
            , A.skewColumn = 3
            }
          }

tpc21j5 :: A.Operator
tpc21j5 = A.HASHJOIN
          { A.targetlist =
            [ defCol "OUTER_VAR" "n_nationkey"
            , defCol "OUTER_VAR" "n_name"
            , defCol "OUTER_VAR" "n_regionkey"
            , defCol "OUTER_VAR" "n_comment"
            , defCol "OUTER_VAR" "s_suppkey"
            , defCol "OUTER_VAR" "s_name"
            , defCol "OUTER_VAR" "s_address"
            , defCol "OUTER_VAR" "s_nationkey"
            , defCol "OUTER_VAR" "s_phone"
            , defCol "OUTER_VAR" "s_acctbal"
            , defCol "OUTER_VAR" "s_comment"
            , defCol "OUTER_VAR" "l_orderkey"
            , defCol "OUTER_VAR" "l_partkey"
            , defCol "OUTER_VAR" "l_suppkey"
            , defCol "OUTER_VAR" "l_linenumber"
            , defCol "OUTER_VAR" "l_quantity"
            , defCol "OUTER_VAR" "l_extendedprice"
            , defCol "OUTER_VAR" "l_discount"
            , defCol "OUTER_VAR" "l_tax"
            , defCol "OUTER_VAR" "l_returnflag"
            , defCol "OUTER_VAR" "l_linestatus"
            , defCol "OUTER_VAR" "l_shipdate"
            , defCol "OUTER_VAR" "l_commitdate"
            , defCol "OUTER_VAR" "l_receiptdate"
            , defCol "OUTER_VAR" "l_shipinstruct"
            , defCol "OUTER_VAR" "l_shipmode"
            , defCol "OUTER_VAR" "l_comment"
            , defCol "OUTER_VAR" "o_orderkey"
            , defCol "OUTER_VAR" "o_custkey"
            , defCol "OUTER_VAR" "o_orderstatus"
            , defCol "OUTER_VAR" "o_totalprice"
            , defCol "OUTER_VAR" "o_orderdate"
            , defCol "OUTER_VAR" "o_orderpriority"
            , defCol "OUTER_VAR" "o_clerk"
            , defCol "OUTER_VAR" "o_shippriority"
            , defCol "OUTER_VAR" "o_comment"
            ]
          , A.joinType = A.SEMI
          , A.inner_unique = False
          , A.joinquals =
            [ A.OPEXPR
              { A.oprname = "<>"
              , A.oprargs = 
                [ A.VAR "OUTER_VAR" "l_suppkey"
                , A.VAR "INNER_VAR" "l_suppkey"
                ]
              }
            -- , A.OPEXPR
            --   { A.oprname = ">"
            --   , A.oprargs =
            --     [ A.VAR "INNER_VAR" "l_receiptdate"
            --     , A.VAR "INNER_VAR" "l_commitdate"
            --     ]
            --   }
            ]
          , A.hashclauses =
            [ A.OPEXPR
              { A.oprname = "="
              , A.oprargs =
                [ A.VAR "OUTER_VAR" "l_orderkey"
                , A.VAR "INNER_VAR" "l_orderkey"
                ]
              }
            ]
          , A.lefttree = tpc21j4
          , A.righttree =
            A.HASH
            { A.targetlist =
              [ defCol "OUTER_VAR" "l_orderkey"
              , defCol "OUTER_VAR" "l_partkey"
              , defCol "OUTER_VAR" "l_suppkey"
              , defCol "OUTER_VAR" "l_linenumber"
              , defCol "OUTER_VAR" "l_quantity"
              , defCol "OUTER_VAR" "l_extendedprice"
              , defCol "OUTER_VAR" "l_discount"
              , defCol "OUTER_VAR" "l_tax"
              , defCol "OUTER_VAR" "l_returnflag"
              , defCol "OUTER_VAR" "l_linestatus"
              , defCol "OUTER_VAR" "l_shipdate"
              , defCol "OUTER_VAR" "l_commitdate"
              , defCol "OUTER_VAR" "l_receiptdate"
              , defCol "OUTER_VAR" "l_shipinstruct"
              , defCol "OUTER_VAR" "l_shipmode"
              , defCol "OUTER_VAR" "l_comment"
              ]
            , A.operator = seqLineitem
            , A.skewTable = "lineitem"
            , A.skewColumn = 0
            }
          }

tpc21agg :: A.Operator
tpc21agg = A.AGG
          { A.targetlist =
            [ defCol "OUTER_VAR" "s_name"
            , A.TargetEntry
              { A.targetexpr =
                A.AGGREF
                { A.aggname = "count"
                , A.aggargs =
                  []
                , A.aggdirectargs = []
                , A.aggorder = []
                , A.aggdistinct = []
                , A.aggfilter = Nothing
                , A.aggstar = True }
              , A.targetresname = "numwait"
              , A.resjunk = False
              }
            ]
          , A.qual = []
          , A.operator = tpc21j5
          , A.groupCols = [6]
          , A.aggstrategy = A.AGG_HASHED
          , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
          }

tpc21sort :: A.Operator
tpc21sort = A.SORT
            { A.targetlist =
              [ defCol "OUTER_VAR" "s_name"
              , defCol "OUTER_VAR" "numwait"
              ]
            , A.operator = tpc21agg
            , A.sortCols =
              [ A.SortEx 2 False False
              , A.SortEx 1 True False
              ]
            }

tpc21limit :: A.Operator
tpc21limit = A.LIMIT
            { A.operator = tpc21sort
            , A.limitOffset = Nothing
            , A.limitCount = Just
              (A.CONST "1" "int8")
            }

tpch21 :: A.PlannedStmt
tpch21 = A.PlannedStmt
          { A.planTree =
            tpc21limit
          , A.subplans = []
          }

--
--------------------------------------------------------------------------------
-- Plan Stitching SIGMOD Query

seqOrdersSIG :: A.Operator
seqOrdersSIG = A.SEQSCAN
            { A.targetlist =
              [ defCol "orders" "o_orderkey"
              , defCol "orders" "o_custkey"
              , defCol "orders" "o_orderstatus"
              , defCol "orders" "o_totalprice"
              , defCol "orders" "o_orderdate"
              , defCol "orders" "o_orderpriority"
              , defCol "orders" "o_clerk"
              , defCol "orders" "o_shippriority"
              , defCol "orders" "o_comment"
              ]
            , A.qual =
              [ A.OPEXPR
                { A.oprname = ">"
                , A.oprargs =
                  [ A.VAR "orders" "o_orderdate"
                  , A.CONST "1998-01-01" "date"
                  ]
                }
              ]
            , A.scanrelation = "orders" }

seqLineitemSIG :: A.Operator
seqLineitemSIG = A.SEQSCAN
              { A.targetlist =
                [ defCol "lineitem" "l_orderkey"
                , defCol "lineitem" "l_partkey"
                , defCol "lineitem" "l_suppkey"
                , defCol "lineitem" "l_linenumber"
                , defCol "lineitem" "l_quantity"
                , defCol "lineitem" "l_extendedprice"
                , defCol "lineitem" "l_discount"
                , defCol "lineitem" "l_tax"
                , defCol "lineitem" "l_returnflag"
                , defCol "lineitem" "l_linestatus"
                , defCol "lineitem" "l_shipdate"
                , defCol "lineitem" "l_commitdate"
                , defCol "lineitem" "l_receiptdate"
                , defCol "lineitem" "l_shipinstruct"
                , defCol "lineitem" "l_shipmode"
                , defCol "lineitem" "l_comment"
                ]
              , A.qual = []
              , A.scanrelation = "lineitem"
              }

seqCustomerSIG :: A.Operator
seqCustomerSIG = A.SEQSCAN
              { A.targetlist =
                [ defCol "customer" "c_custkey"
                , defCol "customer" "c_name" ]
              , A.qual = []
              , A.scanrelation = "customer"
              }

hashJoin_Line_Orders :: A.Operator
hashJoin_Line_Orders
  = A.HASHJOIN
    { A.targetlist =
      [ defCol "OUTER_VAR" "l_orderkey"
      , defCol "OUTER_VAR" "l_partkey"
      , defCol "OUTER_VAR" "l_suppkey"
      , defCol "OUTER_VAR" "l_linenumber"
      , defCol "OUTER_VAR" "l_quantity"
      , defCol "OUTER_VAR" "l_extendedprice"
      , defCol "OUTER_VAR" "l_discount"
      , defCol "OUTER_VAR" "l_tax"
      , defCol "OUTER_VAR" "l_returnflag"
      , defCol "OUTER_VAR" "l_linestatus"
      , defCol "OUTER_VAR" "l_shipdate"
      , defCol "OUTER_VAR" "l_commitdate"
      , defCol "OUTER_VAR" "l_receiptdate"
      , defCol "OUTER_VAR" "l_shipinstruct"
      , defCol "OUTER_VAR" "l_shipmode"
      , defCol "OUTER_VAR" "l_comment"
      , defCol "INNER_VAR" "o_orderkey"
      , defCol "INNER_VAR" "o_custkey"
      , defCol "INNER_VAR" "o_orderstatus"
      , defCol "INNER_VAR" "o_totalprice"
      , defCol "INNER_VAR" "o_orderdate"
      , defCol "INNER_VAR" "o_orderpriority"
      , defCol "INNER_VAR" "o_clerk"
      , defCol "INNER_VAR" "o_shippriority"
      , defCol "INNER_VAR" "o_comment" ]
    , A.joinType = A.INNER
    , A.inner_unique = False
    , A.joinquals = []
    , A.hashclauses =
      [ A.OPEXPR
        { A.oprname = "="
        , A.oprargs =
          [ A.VAR "OUTER_VAR" "l_orderkey"
          , A.VAR "INNER_VAR" "o_orderkey"
          ]
        }
      ]
    , A.lefttree = seqLineitemSIG
    , A.righttree =
      A.HASH
      { A.targetlist =
        [ defCol "OUTER_VAR" "o_orderkey"
        , defCol "OUTER_VAR" "o_custkey"
        , defCol "OUTER_VAR" "o_orderstatus"
        , defCol "OUTER_VAR" "o_totalprice"
        , defCol "OUTER_VAR" "o_orderdate"
        , defCol "OUTER_VAR" "o_orderpriority"
        , defCol "OUTER_VAR" "o_clerk"
        , defCol "OUTER_VAR" "o_shippriority"
        , defCol "OUTER_VAR" "o_comment"
        ]
      , A.operator = seqOrdersSIG
      , A.skewTable = "orders"
      , A.skewColumn = 0
      }
  }

hashJoin_H_customer :: A.Operator
hashJoin_H_customer
  = A.HASHJOIN
    { A.targetlist =
      [ defCol "OUTER_VAR" "l_orderkey"
      , defCol "OUTER_VAR" "l_partkey"
      , defCol "OUTER_VAR" "l_suppkey"
      , defCol "OUTER_VAR" "l_linenumber"
      , defCol "OUTER_VAR" "l_quantity"
      , defCol "OUTER_VAR" "l_extendedprice"
      , defCol "OUTER_VAR" "l_discount"
      , defCol "OUTER_VAR" "l_tax"
      , defCol "OUTER_VAR" "l_returnflag"
      , defCol "OUTER_VAR" "l_linestatus"
      , defCol "OUTER_VAR" "l_shipdate"
      , defCol "OUTER_VAR" "l_commitdate"
      , defCol "OUTER_VAR" "l_receiptdate"
      , defCol "OUTER_VAR" "l_shipinstruct"
      , defCol "OUTER_VAR" "l_shipmode"
      , defCol "OUTER_VAR" "l_comment"
      , defCol "OUTER_VAR" "o_orderkey"
      , defCol "OUTER_VAR" "o_custkey"
      , defCol "OUTER_VAR" "o_orderstatus"
      , defCol "OUTER_VAR" "o_totalprice"
      , defCol "OUTER_VAR" "o_orderdate"
      , defCol "OUTER_VAR" "o_orderpriority"
      , defCol "OUTER_VAR" "o_clerk"
      , defCol "OUTER_VAR" "o_shippriority"
      , defCol "OUTER_VAR" "o_comment"
      , defCol "INNER_VAR" "c_custkey"
      , defCol "INNER_VAR" "c_name" ]
    , A.joinType = A.INNER
    , A.inner_unique = False
    , A.joinquals = []
    , A.hashclauses = 
      [A.OPEXPR
        { A.oprname = "="
        , A.oprargs =
          [ A.VAR "OUTER_VAR" "o_custkey"
          , A.VAR "INNER_VAR" "c_custkey"
          ]
        }
      ]
    , A.lefttree = hashJoin_Line_Orders
    , A.righttree =
      A.HASH
      { A.targetlist =
        [ defCol "OUTER_VAR" "c_custkey"
        , defCol "OUTER_VAR" "c_name"
        ]
      , A.operator = seqCustomerSIG
      , A.skewTable = "customer"
      , A.skewColumn = 0
      }
  }

sortSIG :: A.Operator
sortSIG = A.SORT
          { A.targetlist =
            [ defCol "OUTER_VAR" "l_orderkey"
            , defCol "OUTER_VAR" "l_partkey"
            , defCol "OUTER_VAR" "l_suppkey"
            , defCol "OUTER_VAR" "l_linenumber"
            , defCol "OUTER_VAR" "l_quantity"
            , defCol "OUTER_VAR" "l_extendedprice"
            , defCol "OUTER_VAR" "l_discount"
            , defCol "OUTER_VAR" "l_tax"
            , defCol "OUTER_VAR" "l_returnflag"
            , defCol "OUTER_VAR" "l_linestatus"
            , defCol "OUTER_VAR" "l_shipdate"
            , defCol "OUTER_VAR" "l_commitdate"
            , defCol "OUTER_VAR" "l_receiptdate"
            , defCol "OUTER_VAR" "l_shipinstruct"
            , defCol "OUTER_VAR" "l_shipmode"
            , defCol "OUTER_VAR" "l_comment"
            , defCol "OUTER_VAR" "o_orderkey"
            , defCol "OUTER_VAR" "o_custkey"
            , defCol "OUTER_VAR" "o_orderstatus"
            , defCol "OUTER_VAR" "o_totalprice"
            , defCol "OUTER_VAR" "o_orderdate"
            , defCol "OUTER_VAR" "o_orderpriority"
            , defCol "OUTER_VAR" "o_clerk"
            , defCol "OUTER_VAR" "o_shippriority"
            , defCol "OUTER_VAR" "o_comment"
            , defCol "OUTER_VAR" "c_custkey"
            , defCol "OUTER_VAR" "c_name"
            ]
          , A.operator = hashJoin_H_customer
          , A.sortCols = 
            [ A.SortEx 27 True False
            , A.SortEx 17 True False
            ]
          }

aggSIG :: A.Operator
aggSIG = A.AGG
        { A.targetlist =
          [ defCol "OUTER_VAR" "c_name"
          , defCol "OUTER_VAR" "o_orderkey"
          , defCol "OUTER_VAR" "o_orderdate"
          , A.TargetEntry
            { A.targetexpr =
              A.FUNCEXPR
              { A.funcname = "abs"
              , A.funcargs =
                [ A.OPEXPR
                  { A.oprname = "-"
                  , A.oprargs =
                    [ A.VAR "OUTER_VAR" "o_totalprice"
                    , A.AGGREF
                      { A.aggname = "sum"
                      , A.aggargs =
                        [ A.TargetEntry
                          { A.targetexpr =
                            A.OPEXPR
                            { A.oprname = "*"
                            , A.oprargs =
                              [ A.OPEXPR
                                { A.oprname = "*"
                                , A.oprargs =
                                  [ A.VAR "OUTER_VAR" "l_extendedprice"
                                  , A.OPEXPR
                                    { A.oprname = "-"
                                    , A.oprargs =
                                      [ A.CONST "1" "numeric"
                                      , A.VAR "OUTER_VAR" "l_discount"
                                      ]
                                    }
                                  ]
                                }
                              , A.OPEXPR
                                { A.oprname = "+"
                                , A.oprargs =
                                  [ A.CONST "1" "numeric"
                                  , A.VAR "OUTER_VAR" "l_tax"
                                  ]
                                }
                              ]
                            }
                          , A.targetresname = "sum"
                          , A.resjunk = False
                          }
                        ]
                      , A.aggdirectargs = []
                      , A.aggorder = []
                      , A.aggdistinct = []
                      , A.aggfilter = Nothing
                      , A.aggstar = False
                      }
                    ]
                  }
                ]
              }
            , A.targetresname = "deviation"
            , A.resjunk = False }
          ]
        , A.qual =
          [ A.NOT
            A.OPEXPR
            { A.oprname = "="
            , A.oprargs =
              [ A.AGGREF
                { A.aggname = "sum"
                , A.aggargs =
                  [ A.TargetEntry
                    { A.targetexpr =
                      A.OPEXPR
                      { A.oprname = "*"
                      , A.oprargs =
                        [ A.OPEXPR
                          { A.oprname = "*"
                          , A.oprargs =
                            [ A.VAR "OUTER_VAR" "l_extendedprice"
                            , A.OPEXPR
                              { A.oprname = "-"
                              , A.oprargs =
                                [ A.CONST "1" "numeric"
                                , A.VAR "OUTER_VAR" "l_discount"
                                ]
                              }
                            ]
                          }
                        , A.OPEXPR
                          { A.oprname = "+"
                          , A.oprargs =
                            [ A.CONST "1" "numeric"
                            , A.VAR "OUTER_VAR" "l_tax"
                            ]
                          }
                        ]
                      }
                    , A.targetresname = "sum"
                    , A.resjunk = False
                    }
                  ]
                , A.aggdirectargs = []
                , A.aggorder = []
                , A.aggdistinct = []
                , A.aggfilter = Nothing
                , A.aggstar = False
                }
              , A.VAR "OUTER_VAR" "o_totalprice"
              ]
            }
          ]
        , A.operator = sortSIG
        , A.groupCols =
          [ 1, 20, 21, 27 ]
        , A.aggstrategy = A.AGG_SORTED
        , A.aggsplit = [A.AGGSPLITOP_SIMPLE]
        }

sigPlan :: A.PlannedStmt
sigPlan = A.PlannedStmt
          { A.planTree = seq1
          , A.subplans = []
          }

windowfunc_tmp :: A.Operator
windowfunc_tmp = A.WINDOWAGG{A.targetlist=[A.TargetEntry{A.targetexpr=A.PARAM{A.paramkind = A.PARAM_EXEC,A.paramid = 0,A.paramtype = "int8"},A.targetresname="Px",A.resjunk=True}],A.operator = A.FUNCTIONSCAN{A.targetlist=[],A.qual=[],A.functions = [A.FUNCEXPR{A.funcname = "generate_series",A.funcargs = [A.CONST{A.constvalue ="22",A.consttype ="int4"},A.CONST{A.constvalue ="90",A.consttype ="int4"}]}],A.funcordinality = False},A.winrefId = 1,A.ordEx = [],A.groupCols = [],A.frameOptions = [A.FRAMEOPTION_RANGE],A.startOffset = Nothing,A.endOffset = Nothing}          

-- access list elements safely
(!!) :: [a] -> Int -> Maybe a
(!!) lst idx = if idx >= length lst
                then Nothing
                else Just $ lst Prelude.!! idx

checkAndGenerate :: String -> A.Operator -> IO ()
checkAndGenerate authStr op = do
  -- Validate the AST
  putStrLn $ "Validate: "
  let errs = V.validateOperator op
  -- Print errors
  -- putStrLn $ intercalate "\n" errs

  unless (null errs) $
    do
      error $ "AST is invalid:\n" ++ intercalate "\n" errs

  -- Get Catalog data
  tableDataR <- getTableData authStr

  -- Use Extract.hs to extract information from AST to be pre-transformed etc.
  let consts = E.extract op
  putStrLn $ PP.ppShow consts

  -- Compile constants
  consts' <- mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts
  
  -- Debug output of constants
  putStrLn $ PP.ppShow consts'

  -- Infere output AST
  let infered = generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op [])
  
  -- Print AST structure as well as the postgres plan
  putStrLn $ PP.ppShow infered
  let pgplan = gprint infered
  -- putStrLn $ "Explain: "
  writeFile "explain.sql" $ "select plan_explain('" ++ pgplan ++ "', true);"
  -- putStrLn $ "Execute:"
  writeFile "execute.sql" $ "select plan_execute_print('" ++ pgplan ++ "');"

checkAndGenerateStmt :: String -> A.PlannedStmt -> IO ()
checkAndGenerateStmt authStr op = do
  -- Validate the AST
  putStrLn $ "Validate: "
  let errs = V.validatePlannedStmt op
  -- Print errors
  -- putStrLn $ intercalate "\n" errs

  unless (null errs) $
    do
      error $ "AST is invalid:\n" ++ intercalate "\n" errs

  -- Get Catalog data
  tableDataR <- getTableData authStr

  -- Use Extract.hs to extract information from AST to be pre-transformed etc.
  let consts = E.extractP op
  putStrLn $ PP.ppShow consts

  -- Compile constants
  consts' <- mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts
  
  -- Debug output of constants
  putStrLn $ PP.ppShow consts'

  -- Infere output AST
  let infered = generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) op
  putStrLn $ PP.ppShow op
  -- Print AST structure as well as the postgres plan
  putStrLn $ PP.ppShow infered
  let pgplan = gprint infered
  -- putStrLn $ "Explain: "
  writeFile "explain.sql" $ "select plan_explain('" ++ pgplan ++ "', true);"
  -- putStrLn $ "Execute:"
  writeFile "execute.sql" $ "select plan_execute_print('" ++ pgplan ++ "');"


operatorToPlan :: String -> IO ()
operatorToPlan str = do
  let authStr = "user=postgres password=123456 host=127.0.0.1 dbname=fuzz port=5432"

  opResult <- try(evaluate(read str :: A.Operator)) :: IO (Either SomeException A.Operator) 
  case opResult of
    Left _ -> do
      putStrLn $ "Read error!"

    Right op -> do
      -- errResult <- try(evaluate(V.validateOperator op)) :: IO (Either SomeException A.Operator)
      let errs = V.validateOperator op
      case null errs of
        True -> do
          putStrLn $ "validate op error!"
        False -> do
          tableDataR <- getTableData authStr
          let consts = E.extract op
          consts' <- mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts
          let infered = generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op [])
     
      -- constsResult1 <- try(evaluate(E.extract op)) :: IO (Either SomeException E.Log) 
      -- case constsResult1 of
      --   Left _ -> do
      --     putStrLn $ "extract op error!"
      --   Right consts -> do
      --     constsResult2 <- try(mapM (\x -> L.parseConst authStr x >>= \p -> return (x, p)) $ lgconsts consts) :: IO (Either SomeException [(A.Expr,P.Expr)])
      --     case constsResult2 of
      --       Left _ -> do
      --         putStrLn $ "parseConst error!"
      --       Right consts' -> do
      --         inferedResult <- try(evaluate(generatePlan tableDataR consts' (lgTableNames consts) (lgScan consts) (A.PlannedStmt op []))) :: IO (Either SomeException P.PLANNEDSTMT)
      --         case inferedResult of
      --           Left _ -> do
      --             putStrLn $ "infered error!"
      --           Right infered -> do
                  
          let pgplan = gprint infered
          -- eitherResult <- try(newCString ("select plan_execute_print('" ++ pgplan ++ "');")) :: IO (Either MyException CString)
          eitherResult <- try(newCString ("select plan_execute_print('" ++ pgplan ++ "');")) :: IO (Either SomeException CString)
          case eitherResult of
            Left e -> do 
              putStrLn $ "An exception occurred: "
            Right plan -> do
              str <- peekCString plan
              print str

main :: IO ()
main = do
    cmdArgs <- getArgs
    let configFile =
            case cmdArgs Main.!! 0 of
                Just j -> j -- config.ini file
                Nothing -> error "please provide a config file"
    config <- readfile emptyCP configFile
    let cp = forceEither config
    let authStr = forceEither $ get cp "Main" "dbauth" :: String
    -- Main.checkAndGenerateStmt authStr recursive1
    checkAndGenerate authStr seq1
    -- Main.checkAndGenerateStmt authStr indexonlyscan1
    -- print(indexonlyscan1)

