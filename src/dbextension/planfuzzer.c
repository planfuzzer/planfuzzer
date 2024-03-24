#include "postgres.h"

#include "fmgr.h"
#include "utils/builtins.h"
#include "parser/parser.h"
#include "parser/analyze.h"
#include "nodes/print.h"
#include "nodes/makefuncs.h"

#include "catalog/pg_type.h"
#include "catalog/pg_collation.h"

#include "funcapi.h"
#include "miscadmin.h"
#include "nodes/nodeFuncs.h"

#include "utils/syscache.h"
#include "executor/spi_priv.h"
#include "tcop/utility.h"
#include "nodes/readfuncs.h"

#include "optimizer/planner.h"

#include "commands/explain.h"
#include "utils/snapmgr.h"

#include "access/hash.h"

#include "utils/memutils.h"

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

void _PG_init(void);
void _PG_fini(void);

text *format_node(Node *node, bool pretty);
PlannedStmt *injection_planner(Query *parse,
            int cursorOptions,
            ParamListInfo boundParams);

PlannedStmt* myPlan = NULL;

void _PG_init(void)
{

}

void _PG_fini(void)
{

}


text *
format_node(Node *node, bool pretty)
{
  if(node == NULL) {
    elog(ERROR, "format_node NULL reference");
  }
  text  *out_t;
  char  *out, *out_f;

  out = nodeToString(node);
  if (pretty) {
      out_f = pretty_format_node_dump(out);
  } 
  else 
  {
      out_f = out;
  }
  out_t = cstring_to_text(out_f);
  return out_t;
}

// As soon as the planner_hook is set, we simply ignore the input from the
// planner and instead return myPlan, which will hold the plan we enforce.
PlannedStmt *injection_planner(Query *parse,
            int cursorOptions,
            ParamListInfo boundParams)
{
  planner_hook=NULL;
  return myPlan;
}

PG_FUNCTION_INFO_V1(pg_plan_execute);

Datum
pg_plan_execute(PG_FUNCTION_ARGS)
{
  text *nodeText = PG_GETARG_TEXT_P(0);
  Node *result;
  text *outputstr;

  SPIPlanPtr res;

  int ret;
  uint64 proc;
  char *nodeChar = text_to_cstring(nodeText);

  // Deserialize the Plan
  result = (Node*) stringToNode(nodeChar);
  outputstr = format_node((Node*) result, false);

  if(!IsA(result, PlannedStmt))
    ereport(ERROR,
          (errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
          errmsg("provided input is not a plan")));

  // Setup the plan we want to execute
  myPlan = (PlannedStmt*) result;

  // ENGAGE BRAIN HERE

  // <Query-Plan Injection Code>
  // By setting planner_hook here we basically DISABLE the Postgres
  // Planner completely! Instead of giving Postgres the chance to
  // plan whatever the input is, we inject our own plan into the system.
  planner_hook = &injection_planner;

  SPI_connect();

  // Let SPI prepare a query
  res = SPI_prepare("select 1", 0, NULL);
  
  // Execute the plan.
 ret = SPI_execute_plan(res, NULL, NULL, false, 0);

  // Execution is done at this point, print the result of the query
  proc = SPI_processed; // Number of rows
  elog(INFO, "executed, rows: %lu", proc);

  if (ret > 0 && SPI_tuptable != NULL)
  {
    elog(INFO, "execution succeed!");
    /*       closed output    
                            */
  }
  else
  {
    // Some error
    elog(INFO, "Err!");
  }

  elog(INFO, "ret: %u", ret); // Returncode

  // Close the SPI connection
  SPI_finish();

  // Disable the hook, and reactivate the planner.
  // Remote plan injection is done at this point.
  planner_hook = NULL;
  // </Query-Plan Injection Code>

  PG_RETURN_TEXT_P(outputstr);
}
