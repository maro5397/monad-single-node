#!/bin/bash

# ==============================================================================
# monitor_process.sh
#
# Description:
#   Monitors the CPU and memory usage of specified Process IDs (PIDs) for a 
#   given duration and saves the raw output and a summary report to files.
#
# Usage:
#   ./monitor_process.sh <total_duration_seconds> <PID_1> [PID_2] [PID_3] ...
#
# Example:
#   # Monitor PIDs 1225687 and 1225343 for 60 seconds
#   ./monitor_process.sh 60 1225687 1225343
# ==============================================================================

# --- Input Validation ---
if [ "$#" -lt 2 ]; then
  echo "Error: At least 2 arguments are required."
  echo "Usage: $0 <total_duration_seconds> <PID_1> [PID_2] ..."
  exit 1
fi

DURATION=$1
shift # Remove the first argument (duration) and use the rest as PIDs
PIDS=("$@")

# --- Setup Log Directory and Files ---
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="monitoring_logs_${TIMESTAMP}"
mkdir -p "$LOG_DIR"

if [ $? -ne 0 ]; then
    echo "Error: Could not create log directory '$LOG_DIR'."
    exit 1
fi

RAW_LOG="${LOG_DIR}/raw_output.log"
SUMMARY_REPORT="${LOG_DIR}/summary_report.txt"
echo "Results will be saved in the '${LOG_DIR}' directory."
echo ""

# --- Start Monitoring ---
echo "Starting monitoring: PIDs [${PIDS[*]}] / Duration: ${DURATION} seconds"
echo "Real-time output will be displayed. All output is also being logged to files."
echo ""

# Array to store temporary file paths
TMP_FILES=()

for PID in "${PIDS[@]}"; do
    # Simple check for a valid PID
    if ! ps -p "$PID" > /dev/null; then
        echo "Warning: PID $PID not found. Skipping."
        continue
    fi

    CPU_TMP_FILE="${LOG_DIR}/cpu_${PID}.tmp"
    MEM_TMP_FILE="${LOG_DIR}/mem_${PID}.tmp"
    TMP_FILES+=("$CPU_TMP_FILE" "$MEM_TMP_FILE")

    # -u: CPU usage, -r: Memory usage
    # Run for DURATION seconds with a 1-second interval
    # tee: a-ppend to file and also show on screen
    pidstat -p "$PID" -u 1 "$DURATION" | tee -a "$CPU_TMP_FILE" &
    pidstat -p "$PID" -r 1 "$DURATION" | tee -a "$MEM_TMP_FILE" &
done

# Wait for all background pidstat processes to finish
wait

# --- Analyze and Generate Report ---
echo ""
echo "Monitoring finished. Generating summary report..."

{
    echo "##################################################"
    echo "#      Process Performance Summary Report      #"
    echo "##################################################"
    echo ""
    echo "Monitoring Time : ${TIMESTAMP}"
    echo "Total Duration  : ${DURATION} seconds"
    echo "Target PIDs     : ${PIDS[*]}"
    echo ""
} > "$SUMMARY_REPORT"

for PID in "${PIDS[@]}"; do
    if ! [ -f "${LOG_DIR}/cpu_${PID}.tmp" ]; then
        continue # Skip if the temp file was not created (e.g., invalid PID)
    fi

    # Calculate CPU stats using awk (%CPU is the 8th column)
    CPU_STATS=$(awk '
        # Filter for data lines only (start with a number, PID matches)
        $1 ~ /^[0-9]/ && $4 == pid {
            sum += $8;
            count++;
            if ($8 > max) max = $8;
        }
        END {
            if (count > 0) {
                printf "Average CPU Usage (%%CPU): %.2f%%\n", sum/count;
                printf "Maximum CPU Usage (%%CPU): %.2f%%\n", max;
            } else {
                print "No CPU data found.";
            }
        }' pid="$PID" "${LOG_DIR}/cpu_${PID}.tmp")

    # Calculate memory stats using awk (RSS is the 7th column, in kB)
    MEM_STATS=$(awk '
        $1 ~ /^[0-9]/ && $4 == pid {
            sum += $7;
            count++;
            if ($7 > max) max = $7;
        }
        END {
            if (count > 0) {
                printf "Average Memory Usage (RSS): %.2f MB\n", sum/(count*1024);
                printf "Maximum Memory Usage (RSS): %.2f MB\n", max/1024;
            } else {
                print "No memory data found.";
            }
        }' pid="$PID" "${LOG_DIR}/mem_${PID}.tmp")

    # Append analysis to the report file
    {
        echo "--------------------------------------------------"
        echo ">> Analysis Results (PID: $PID)"
        echo "--------------------------------------------------"
        echo "$CPU_STATS"
        echo "$MEM_STATS"
        echo ""
    } >> "$SUMMARY_REPORT"
done

# --- Final Log Cleanup ---
# Combine temporary files into a single raw log and delete them
cat "${TMP_FILES[@]}" > "$RAW_LOG"
rm "${TMP_FILES[@]}"

echo "Done!"
echo "Summary Report:    ${SUMMARY_REPORT}"
echo "Full Raw Output Log: ${RAW_LOG}"