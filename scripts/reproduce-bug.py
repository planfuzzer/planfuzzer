import subprocess
import argparse
import os
import time
import re
import warnings

warnings.filterwarnings("ignore")
    
def get_idle_pid():    
    idle_process_cmd = "ps aux | grep postgres | grep 'idle' "
    
    # idle_process = subprocess.check_output(idle_process_cmd, shell=True).decode()
    idle_process_res = subprocess.getoutput(idle_process_cmd).split('\n')
    for line in idle_process_res:
        line = line.split()
        if 'fuzz' in line:
            return line[1]    
    return None


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Crash reproduction and deduplication scripts")
    parser.add_argument('-i', '--input', type=str, help="crash's dir", required=True)
    parser.add_argument('-o', '--output', type=str, help="unique crash's dir", required=True)
    args = parser.parse_args()

    gdb_path = "/usr/bin/gdb"
    crash_cases_folder = args.input
    unique_crash_folder = args.output
    crash_cases = os.listdir(crash_cases_folder)

    crash_unique = []

    for case in crash_cases:
        case_path = os.path.join(crash_cases_folder, case)
        
        psql = subprocess.Popen(["psql", '-h', '127.1', '-d', 'fuzz'], stdin=subprocess.PIPE)
        time.sleep(0.5)
        
        idle_pid = get_idle_pid()
        
        if idle_pid == None:
            print("Error! {}'s psql is None!".format(case))
            continue
        # assert(idle_pid!=None)
        print("Crash case:{}   Psql pid:{}".format(case, idle_pid))
        
        gdb = subprocess.Popen(['sudo', 'gdb', "-p", idle_pid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        # gdb.stdout.fileno()
        gdb.stdin.write(b"b errfinish\n")
        gdb.stdin.write(b"cont\n")
        gdb.stdin.flush()

        time.sleep(0.5)

        with open(case_path, "r") as case_file:
            case_data = case_file.read()
            psql.stdin.write(case_data.encode())
            psql.stdin.flush()
        time.sleep(1)
        
        gdb.stdin.write(b"bt\n")
        gdb.stdin.flush()
        # gdb_output = gdb.stdout.read()
        # gdb.kill()
        gdb_output, _ = gdb.communicate()
        gdb_output = gdb_output.decode()
        
        pattern = r"(?<=\(gdb\)).*?(?=\(gdb\))"  
        matches = re.findall(pattern, gdb_output, re.DOTALL)  
        call_stack = matches[-1] if len(matches) >= 2 else None
        
        if call_stack==None:
            print("Error! {}'s calltrace is None!".format(case))
            continue
        # assert(call_stack != None)
        
        call_stack = call_stack.strip()
        
        # print("****************************** CALL STACK *******************************")
        call_stack_hash = hash(call_stack)
        if call_stack_hash not in crash_unique:
            crash_unique.append(call_stack_hash)
            stacktrace_file_path = os.path.join(unique_crash_folder, f"{case}_stacktrace.txt")
            with open(stacktrace_file_path, "w") as stacktrace_file:
                stacktrace_file.write(call_stack)
        
        psql.kill()
        gdb.kill()
        
        time.sleep(1)
        
