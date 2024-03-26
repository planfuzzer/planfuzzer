import yaml
import json
import time
import os
import random
from tqdm import tqdm
import psycopg2
from tree import Tree, TreeNode, are_isomorphic

with open("../../config.yml", "r") as yaml_file:
    config = yaml.safe_load(yaml_file)

CAPACITY = config['capacity']
OUTPUT = config['output']
TMP_QUERY = config['tmp_query']
TMP_ERR = config['tmp_err']
SQLSMITH = config['sqlsmith']

TEST_DB = config['db_name']
PORT = config['port']
USER = config['user_name']
PASSWORD = config['passwd']
HOST = config["host"]

def postgres_conn(db, user, host, port):
    conn = psycopg2.connect(
            database=db,
            user=user,
            host=host,
            port=port
        )
    cur = conn.cursor()
    return cur, conn

class UniquePlan:
    def __init__(self, capacity):
        self.query_plan_pool = []
        self.unique_plan = []
        self.batch = 100
        self.capacity = capacity

    # 1) SQL Gen
    def sql_generator(self, query_num):
        '''gen sql by sqlsmith'''
        cmd = "{} --verbose --dump-all-queries --seed={} --max-queries={} \
            --target=\"host=127.0.0.1 port={} user={} password={} dbname={} \" 1>{} 2>{}" \
            .format(SQLSMITH, random.randint(1, 1000000), query_num, 
            PORT, USER, PASSWORD, TEST_DB, TMP_QUERY, TMP_ERR)
        os.system(cmd)

    # 2) valid 
    def extract_valid_sql(self):
        query_result = []
        extract_queries = []
        with open(TMP_ERR, 'r') as f:
            data = f.read()
            results = ""
            if "Generating" in data and "quer" in data:
                results = data.split(
                    "Generating indexes...done.")[1].split("queries:")[0]
                results = results.replace("\n", "").strip()

            for x in range(len(results)):
                if results[x] == "e":
                    query_result.append("fail")
                elif results[x] == ".":
                    query_result.append("success")
                elif results[x] == "S":
                    query_result.append("syntax error")
                elif results[x] == "C":
                    query_result.append("crash server!!!")
                elif results[x] == "t":
                    query_result.append("timeout")
                else:
                    raise Exception('Not possible!')

        with open(TMP_QUERY, 'r') as f:
            data = f.read()
            results = data.split(";")[:-1]
            for x in range(len(results)):
                if query_result[x] == "success":
                    extract_queries.append(results[x] + ";")
        return extract_queries

    # 3) ananlyze
    def analyze(self, query):
        cur, conn = postgres_conn(TEST_DB, USER, HOST, PORT)
        try:
            cur.execute("EXPLAIN (FORMAT json) "+query)
            rows = cur.fetchall()
            explain = rows[0][0][0]
            plan = self._build_tree_from_dict(explain["Plan"])
            return explain, plan
        except:
            return None, None

    def _build_tree_from_dict(self, node_dict):
        if not isinstance(node_dict, dict):
            return None

        root_data = node_dict.get("Node Type")
        if root_data is None:
            return None
        root_node = TreeNode(root_data)

        if "Plans" in node_dict:
            plans = node_dict["Plans"]
            if len(plans) >= 1:
                root_node.left = self._build_tree_from_dict(plans[0])
            if len(plans) == 2:
                root_node.right =self. _build_tree_from_dict(plans[1])

        return root_node

    # 4) build process
    def build(self):
        # DEBUG
        # f = open(".query-plan", "w")
        while True:
            if os.path.exists(TMP_QUERY):
                os.remove(TMP_QUERY)

            self.sql_generator(self.batch)
            queries = self.extract_valid_sql()

            for query in tqdm(queries):
                explain, plan = self.analyze(query)
                if plan is None:
                    continue

                if len(self.unique_plan) == 0:
                    self.unique_plan.append(plan)

                isomorphic = True
                for plan_old in self.unique_plan:
                    if are_isomorphic(plan_old, plan):
                        isomorphic = False
                        break
                if isomorphic:
                    self.unique_plan.append(plan)
                    self.query_plan_pool.append(explain)

                if len(self.unique_plan) == self.capacity:
                    self._to_file()
                    return
        

    def _to_file(self):
        if not os.path.exists(OUTPUT):
            os.mkdir(OUTPUT)

        for id, plan in enumerate(self.query_plan_pool):
            file_name = os.path.join(OUTPUT, str(id))+".txt"
            with open(file_name, "w") as f:
                json.dump(plan, f)

if __name__ == "__main__":
    unique_plan = UniquePlan(CAPACITY)
    start = time.time()
    query_plan_pool = unique_plan.build()
    end = time.time()
    print("Time cost: {:.2f}s".format(end-start))