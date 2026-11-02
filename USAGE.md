# Use the start script to examine a project with the skills, and repair the findings

This document is written in ASD-STE100 Simplified Technical English.

## 1 Description

The start script examines the files of a project with the skills of this collection.
There are two start scripts:

- `run-skills.sh` is for Git Bash, Linux and macOS.
- `run-skills.cmd` is for the Windows command prompt.

The start script has two modes:

- **Default mode:** The script starts Claude Code. Claude Code examines the project
  and writes a report. Claude Code does not change the files of the project.
- **Script mode (`--scripts-only`):** The script starts only the helper scripts of the
  skills. You do not need Claude Code. This mode is fast, but only some skills have
  helper scripts.

## 2 Requirements

- Bash. On Windows, install Git for Windows. Git for Windows includes Git Bash.
- Claude Code. You need Claude Code for the default mode only. Log in to Claude Code
  before you start the script.
- Python 3. The skill `config-review` uses Python 3 to examine JSON files. The other
  skills do not need Python 3.

## 3 Safety

**CAUTION:** Each start in the default mode uses your Claude account. This can cost
money or use part of your usage limit.

**CAUTION:** The skill `dependency-audit` can send the names of your packages to public
databases. If you do not want this, do not use this skill.

**NOTE:** The start script does not change the files of the project. The option `-o`
writes a report file to the location that you give.

## 4 Procedure

### 4.1 Show the available skills

1. Open Git Bash or the Windows command prompt.
2. Go to the directory of the skill collection:
   ```
   cd <path-to>/ClaudeSkillCollection
   ```
3. Type this command:
   - Git Bash, Linux, macOS: `./run-skills.sh --list`
   - Windows command prompt: `run-skills.cmd --list`
4. Find the names of the skills that you want to use.

**NOTE:** The letter `S` in the list shows that the skill has helper scripts. You can
use these skills in script mode.

### 4.2 Examine a project in the default mode

1. Make sure that Claude Code is installed. Type `claude --version`.
2. Type the start script, the skill names and the project directory:
   ```
   ./run-skills.sh secrets-scan,repo-hygiene C:/Projects/my-app
   ```
3. Wait until the script stops.
4. Read the report on the screen.

### 4.3 Save the report in a file

1. Add the option `-o` and a file name:
   ```
   ./run-skills.sh -o report.md secrets-scan C:/Projects/my-app
   ```
2. Open the file `report.md` after the script stops.

**NOTE:** The start of the report shows the full path of the project. The fix script
(section 8) reads the project path from this line:
`<!-- run-skills:project=PATH -->`. Do not change this line.

### 4.4 Get the report in a different language

1. Add the option `-l` and the name of the language:
   ```
   ./run-skills.sh -l Deutsch secrets-scan C:/Projects/my-app
   ```

### 4.5 Do a full examination of a project

1. Use the name `full` in place of the skill names:
   ```
   ./run-skills.sh -l Deutsch -o report.md full C:/Projects/my-app
   ```
2. Wait until the script stops. A full examination can take a long time.

**NOTE:** The skill `full-review` finds the skills that apply to the project. It uses
only these skills.

### 4.6 Examine a project without Claude Code

1. Add the option `--scripts-only`:
   ```
   ./run-skills.sh --scripts-only todo-audit,config-review C:/Projects/my-app
   ```
2. Read the result on the screen.

**NOTE:** In script mode, a skill without helper scripts shows the message
"no helper script". This is not an error.

### 4.7 Examine the command before you start it

1. Add the option `--dry-run`:
   ```
   ./run-skills.sh --dry-run secrets-scan C:/Projects/my-app
   ```
2. Examine the command and the instructions for Claude Code on the screen.
3. Remove the option `--dry-run` to start the examination.

**NOTE:** On Windows, use `run-skills.cmd` in place of `./run-skills.sh`. The options
and arguments are the same.

## 5 Rules for the arguments

- Separate the skill names with commas or spaces.
- Put the project directory last.
- If you do not give a project directory, the script uses the directory that you are in.
- If the last argument is a skill name, the script uses the directory that you are in.

## 6 Options

| Option | Function |
| --- | --- |
| `-o FILE` | Writes the report to the file. |
| `-l LANGUAGE` | Sets the language of the report. The default language is English. |
| `-m MODEL` | Sets the Claude model. |
| `-x "TEXT"` | Gives more instructions to Claude Code, for example `-x "examine only src/"`. |
| `--scripts-only` | Starts only the helper scripts. Claude Code is not necessary. |
| `--dry-run` | Shows the command and the instructions. The script does not start Claude Code. |
| `--list` | Shows all skills. |
| `-h`, `--help` | Shows the help text. |

## 7 Problems and solutions

| Message | Cause | Action |
| --- | --- | --- |
| `unknown skill 'NAME'` | The skill name is not correct. | Type `--list`. Use a name from the list. |
| `unknown option` | The option is not correct. | Type `--help`. Use an option from the help text. |
| `project directory not found` | The project directory does not exist. | Make sure that the path is correct. |
| `claude not found` | Claude Code is not installed. | Install Claude Code, or use the option `--scripts-only`. |
| `Git Bash not found` | Git for Windows is not installed. | Install Git for Windows from https://git-scm.com. |

The script stops with exit code 0 if there is no error. It stops with exit code 2 if an
argument is not correct.

## 8 Repair the findings of a report

### 8.1 Description

The fix script gives a report file to Claude Code. Claude Code repairs the findings in
the project. There are two fix scripts:

- `fix-issues.sh` is for Git Bash, Linux and macOS.
- `fix-issues.cmd` is for the Windows command prompt.

The fix script reads the project path from the report. Claude Code can read and change
the files in the project directory. Claude Code does not commit, push or delete files.

### 8.2 Safety

**WARNING:** The fix script changes the files of your project. Commit your work before
you start the fix script. Then you can examine and undo all changes with git.

**CAUTION:** Each start of the fix script uses your Claude account. This can cost money
or use part of your usage limit.

**CAUTION:** Do not accept changes that you do not understand. Read each change before
you keep it. The fix script is not a replacement for your own work.

**NOTE:** The fix script does not start if the project has uncommitted changes. Only the
report file is not included in this check. Use the option `--allow-dirty` to start the
fix script with uncommitted changes.

### 8.3 Procedure

1. Make a report with the start script and the option `-o` (see 4.3):
   ```
   ./run-skills.sh -o report.md full C:/Projects/my-app
   ```
2. Read the report. Decide which findings you want to repair.
3. Commit the uncommitted changes in the project.
4. Examine the instructions for Claude Code:
   ```
   ./fix-issues.sh --dry-run report.md
   ```
5. Start the fix script:
   ```
   ./fix-issues.sh -t "npm test" -o fixes.md report.md
   ```
6. Wait until the script stops.
7. Read the summary. The summary shows these items for each finding:
   - The status: fixed, skipped, needs decision or manual.
   - The change and the reason for the change.
8. Do the manual steps in the summary.
9. Examine all changes:
   ```
   git diff
   ```
10. Keep the changes that are correct. To undo all changes, type `git restore .`.

**NOTE:** If the report does not show the project path, put the project directory
after the report file: `./fix-issues.sh report.md C:/Projects/my-app`.

**NOTE:** On Windows, use `fix-issues.cmd` in place of `./fix-issues.sh`. Put option
values with commas or spaces in quotes, for example `-f "SC1,SC5"`.

### 8.4 Options of the fix script

| Option | Function |
| --- | --- |
| `-s LEVEL` | Sets the lowest severity to repair: `error`, `warning` or `info`. The default is `warning`. |
| `-f "TEXT"` | Repairs only these findings, for example `-f "SC1,EH1"`. |
| `-t "COMMAND"` | Sets a test command. Claude Code can start this command to examine the changes. |
| `-o FILE` | Writes the summary to the file. |
| `-l LANGUAGE` | Sets the language of the summary. The default language is English. |
| `-m MODEL` | Sets the Claude model. |
| `-x "TEXT"` | Gives more instructions to Claude Code. |
| `--allow-dirty` | Starts the fix script also if the project has uncommitted changes. |
| `--dry-run` | Shows the command and the instructions. The script does not start Claude Code. |
| `-h`, `--help` | Shows the help text. |

### 8.5 Problems and solutions

| Message | Cause | Action |
| --- | --- | --- |
| `report not found` | The report file does not exist. | Make sure that the path is correct. |
| `no project path in the report header` | The report does not have the project line. | Put the project directory after the report file. |
| `project directory not found` | The project directory does not exist. | Make sure that the path is correct. |
| `the project has uncommitted changes` | The project has changes that are not committed. | Commit or stash the changes, or use `--allow-dirty`. |
| `-s must be error, warning or info` | The severity is not correct. | Use `error`, `warning` or `info`. |
| `too many arguments` | There are more than two arguments. | Put option values with spaces or commas in quotes. |
| `claude not found` | Claude Code is not installed. | Install Claude Code. |
