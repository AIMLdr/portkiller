# Port Killer Script (`portkiller.sh`) ☠️

**Version:** 1.1

---

**A command-line utility to identify and interactively terminate processes listening on specified TCP ports.**

⚠️ **Warning:** This script can terminate running processes. Use with extreme caution, especially with `sudo`, as killing the wrong process can cause data loss or system instability. ⚠️

This script helps developers and system administrators quickly find and stop applications occupying specific network ports, commonly needed during development or troubleshooting.

## Table of Contents


    *   [The Kill Prompt](#the-kill-prompt)

---

##  Introduction

`port-killer.sh` is a Bash script designed to simplify the task of freeing up TCP network ports. It scans specified ports, identifies any listening processes, displays detailed information about them, and offers an interactive, time-limited prompt to terminate those processes.

Its primary use case is to quickly stop lingering development servers or other applications that might be preventing a new process from binding to a required port.

---

##  Features ✨

*   **Flexible Port Specification:** Checks default ports (`3000`, `8000`) or accepts any number of ports as command-line arguments.
*   **Robust Process Detection:** Utilizes `lsof`, `ss`, or `netstat` (in order of preference) to find listening TCP processes, maximizing compatibility.
*   **Detailed Process Information:** Shows PID, User, Command Name, and Full Arguments (`ps`) for identified processes.
*   **Interactive Confirmation:** Prompts the user with a configurable timeout before attempting termination, defaulting to *no* action.
*   **Graceful & Forceful Termination:** Attempts `SIGTERM` first, followed by `SIGKILL` if the process doesn't exit promptly.
*   **Input Validation:** Ensures provided port arguments are valid numbers (1-65535).
*   **Clear Logging:** Provides step-by-step information about checks, findings, user choices, and termination results.

---

##  Prerequisites 🛠️

The script requires the following standard Linux/macOS command-line utilities:

*   **Bash:** The script interpreter.
*   **Core Utilities:** `grep`, `sed`, `sort`, `paste`, `awk`, `stdbuf` (usually part of `coreutils`).
*   **Process Management:** `ps`, `kill`.
*   **Port Checking (at least one):**
    *   `lsof` (**Highly Recommended**)
    *   `ss` (Common on modern Linux)
    *   `netstat` (Legacy, may require `sudo` for PIDs)
*   **Optional:** `sudo` (may be needed for `netstat -p` or killing processes owned by other users/root).

The script performs basic checks for these commands at startup.

---

##  Usage ▶️

### Basic Execution

  **Save:** Save the script code to a file, for example, `port-killer.sh`.
  **Make Executable:**
    ```bash
    chmod +x port-killer.sh
    ```
  **Run:**

    *   **Check Default Ports:**
        To check the default ports defined within the script (e.g., 3000, 8000):
        ```bash
        ./port-killer.sh
        ```

    *   **Check Specific Ports:**
        To check one or more specific ports, list them as arguments:
        ```bash
        # Check ports 8080 and 9000
        ./port-killer.sh 8080 9000

        # Check only port 4000
        ./port-killer.sh 4000
        ```

### The Kill Prompt

If a process is found listening on a checked port, the script will display details like this:
Use code with caution.
Markdown
[WARN] [PORT 8000] Found process(es) listening (using lsof):
PID USER COMMAND COMMAND+ARGS
12345 myuser uvicorn /path/to/venv/bin/python ... uvicorn main:app ...
Kill process(es) on port 8000? (y/N, default N after 5 sec):
*   **To Kill:** Type `y` or `Y` and press Enter within the timeout period.
*   **To Skip:** Press Enter, type `n` or `N`, or let the timeout expire.

---

##  How It Works ⚙️

  **Initialization:** Checks prerequisites and determines the target ports (arguments or defaults). Validates port numbers.
  **Port Iteration:** Loops through each valid port.
  **Process Detection:** Sequentially tries `lsof`, `ss`, and `netstat` to find PIDs associated with listening TCP sockets on the current port.
  **PID Extraction & Display:** If PIDs are found, parses them and uses `ps` to display detailed process information.
  **User Confirmation:** Prompts the user interactively with a timeout.
  **Termination Sequence (if confirmed):**
    *   Sends `SIGTERM` (`kill <pid>`) to allow graceful shutdown.
    *   Pauses briefly.
    *   Checks if the process is still running (`ps -p <pid>`).
    *   If still running, sends `SIGKILL` (`kill -9 <pid>`) for forceful termination.
  **Logging:** Reports the status for each port and the outcome of any kill attempts.

---

##  Configuration 🔧

Modify these variables near the top of `port-killer.sh` to change default behavior:

*   `DEFAULT_PORTS`: Array of default ports to check if none are given as arguments.
    ```bash
    # Example: Check 80, 443, 8080 by default
    DEFAULT_PORTS=("80" "443" "8080")
    ```
*   `PROMPT_TIMEOUT`: Duration (in seconds) to wait for user input at the kill prompt before defaulting to "No".
    ```bash
    # Example: Wait 10 seconds
    PROMPT_TIMEOUT=10
    ```

---

##  Important Notes & Warnings ☠️

*   🛑 **EXTREME CAUTION ADVISED:** This script terminates processes. Killing essential system processes or processes holding unsaved data can cause **severe system instability or data loss**.
*   **VERIFY PROCESSES:** Always carefully examine the process details (`PID`, `User`, `Command`, `Arguments`) displayed by the script before confirming termination. Ensure you are targeting the correct application.
*   **PERMISSIONS:** You can only kill processes owned by your user unless you run the script with `sudo`. Running with `sudo` significantly increases the risk of damaging your system if you kill the wrong process.
*   **TCP ONLY:** The script currently focuses on **TCP** listening ports. UDP ports are not checked by default.
*   **`netstat` LIMITATIONS:** If the script falls back to using `netstat`, it might require `sudo` privileges to display the PID associated with a listening port. Without `sudo`, it might detect a listening service but be unable to identify the specific PID to kill.
*   **NO UNDO:** There is no undo function. Once a process is killed (especially with `SIGKILL`), it's gone.

---

##  License 📜

This script is distributed under the MIT License.

```text
MIT License

portkiller (c) 2025 PYTHAI

Permission is hereby granted, free of charge, to any person obtaining a copy
of portkiller and associated documentation files (the "portkiller"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
Use code with caution.
(Remember to replace [Year] and [Your Name/Organization])
Contributing 🤝
Suggestions and improvements are welcome. Please feel free to open an issue or submit a pull request.
