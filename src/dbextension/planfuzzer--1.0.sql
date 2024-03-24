SET search_path = public;

CREATE OR REPLACE FUNCTION plan_execute(query_string text, pretty_print bool DEFAULT true)
RETURNS setof record
AS '$libdir/planfuzzer','pg_plan_execute'
LANGUAGE C IMMUTABLE STRICT;

