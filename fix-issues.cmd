@echo off
rem Fixes the findings of a run-skills report with Claude Code (Windows).
rem
rem Reads a report written by run-skills.cmd/.sh (-o FILE), takes the project
rem path from its header (or from the command line) and starts Claude Code
rem non-interactively in the project. Claude may read and edit files in the
rem project directory only. It does not commit, push or rewrite git history.
rem
rem Usage: fix-issues.cmd [options] report.md [project_dir]
rem        fix-issues.cmd --help

setlocal EnableExtensions EnableDelayedExpansion

set "LEVEL=warning"
set "FILTER="
set "TEST_CMD="
set "OUT="
set "LANG_=English"
set "MODEL="
set "EXTRA="
set "ALLOW_DIRTY="
set "DRY_RUN="
set "REPORT="
set "PROJECT="
set "NPOS=0"

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="-s" (set "LEVEL=%~2" & shift & shift & goto parse)
if /i "%~1"=="-f" (set "FILTER=%~2" & shift & shift & goto parse)
if /i "%~1"=="-t" (set "TEST_CMD=%~2" & shift & shift & goto parse)
if /i "%~1"=="-o" (set "OUT=%~f2" & shift & shift & goto parse)
if /i "%~1"=="-l" (set "LANG_=%~2" & shift & shift & goto parse)
if /i "%~1"=="-m" (set "MODEL=%~2" & shift & shift & goto parse)
if /i "%~1"=="-x" (set "EXTRA=%~2" & shift & shift & goto parse)
if /i "%~1"=="--allow-dirty" (set "ALLOW_DIRTY=1" & shift & goto parse)
if /i "%~1"=="--dry-run" (set "DRY_RUN=1" & shift & goto parse)
if /i "%~1"=="-h" goto usage
if /i "%~1"=="--help" goto usage
set "ARG=%~1"
if "!ARG:~0,1!"=="-" (
  echo fix-issues: unknown option %1 ^(see --help^) 1>&2
  exit /b 2
)
set /a NPOS+=1
if !NPOS! EQU 1 set "REPORT=%~f1"
if !NPOS! EQU 2 set "PROJECT=%~1"
shift
goto parse

:parsed
if %NPOS% EQU 0 goto usage_error
if %NPOS% GTR 2 (
  echo fix-issues: too many arguments - put option values with spaces or commas in quotes 1>&2
  exit /b 2
)
if not exist "%REPORT%" goto no_report
if exist "%REPORT%\" goto no_report
for %%r in ("%REPORT%") do set "REPORT_NAME=%%~nxr"

rem Take the project path from the "run-skills:project=" header line.
if not defined PROJECT (
  for /f "tokens=1,* delims==" %%a in ('findstr /c:"run-skills:project=" "%REPORT%"') do (
    if not defined PROJECT set "PROJECT=%%b"
  )
  if defined PROJECT set "PROJECT=!PROJECT: -->=!"
)
if not defined PROJECT (
  echo fix-issues: no project path in the report header - give the project directory 1>&2
  exit /b 2
)
set "PROJECT=!PROJECT:/=\!"
if not exist "!PROJECT!\" (
  echo fix-issues: project directory not found: !PROJECT! 1>&2
  exit /b 2
)
for %%p in ("!PROJECT!") do set "PROJECT=%%~fp"
if "!PROJECT:~-1!"=="\" set "PROJECT=!PROJECT:~0,-1!"
set "PROJECTF=!PROJECT:\=/!"

set "SEV="
if /i "%LEVEL%"=="error" set "SEV=error"
if /i "%LEVEL%"=="warning" set "SEV=error and warning"
if /i "%LEVEL%"=="info" set "SEV=error, warning and info"
if not defined SEV (
  echo fix-issues: -s must be error, warning or info 1>&2
  exit /b 2
)

set "TEST_ARGS="
if defined TEST_CMD set TEST_ARGS="Bash(!TEST_CMD!)" "Bash(!TEST_CMD! *)"
set "MODEL_ARG="
if defined MODEL set "MODEL_ARG=--model "%MODEL%""

set "PROMPT_FILE=%TEMP%\fix-issues-%RANDOM%%RANDOM%.txt"
call :write_prompt > "%PROMPT_FILE%"
if defined DRY_RUN goto dry_run

where claude >nul 2>&1
if errorlevel 1 (
  echo fix-issues: claude not found - install Claude Code 1>&2
  del "%PROMPT_FILE%" >nul 2>&1
  exit /b 2
)

set "IS_GIT="
git -C "%PROJECT%" rev-parse --is-inside-work-tree >nul 2>&1 && set "IS_GIT=1"
set "DIRTY="
if not defined ALLOW_DIRTY call :check_clean
if defined DIRTY (
  del "%PROMPT_FILE%" >nul 2>&1
  exit /b 2
)

pushd "%PROJECT%"
set "RC=0"
if defined OUT (
  call :claude_run > "%OUT%"
  set "RC=!ERRORLEVEL!"
  type "%OUT%"
) else (
  call :claude_run
  set "RC=!ERRORLEVEL!"
)
if defined IS_GIT call :show_changes
popd
del "%PROMPT_FILE%" >nul 2>&1
exit /b %RC%

rem ---------------------------------------------------------------------------
:no_report
echo fix-issues: report not found: %REPORT% 1>&2
exit /b 2

:dry_run
echo # working directory: %PROJECT%
echo claude -p --permission-mode dontAsk --allowedTools Read Grep Glob Edit Write "Bash(git status)" "Bash(git status *)" "Bash(git diff)" "Bash(git diff *)" "Bash(git log *)" "Bash(git ls-files *)" "Bash(git show *)" !TEST_ARGS! --disallowedTools NotebookEdit PowerShell WebFetch WebSearch --output-format text %MODEL_ARG% ^< prompt
echo ----- prompt -----
type "%PROMPT_FILE%"
del "%PROMPT_FILE%" >nul 2>&1
exit /b 0

rem Sets DIRTY if the project has uncommitted changes (the report is ignored).
:check_clean
if not defined IS_GIT (
  echo fix-issues: note - project is not a git repository; changes can't be reviewed or reverted with git 1>&2
  exit /b 0
)
for /f "delims=" %%l in ('git -C "%PROJECT%" status --porcelain ^| findstr /v /l /c:"%REPORT_NAME%"') do (
  if not defined DIRTY echo fix-issues: the project has uncommitted changes: 1>&2
  set "DIRTY=1"
  echo   %%l 1>&2
)
if defined DIRTY echo fix-issues: commit or stash them first so you can review the fixes, or use --allow-dirty 1>&2
exit /b 0

rem "call" is needed when claude is a .cmd shim (npm install).
:claude_run
call claude -p --permission-mode dontAsk ^
  --allowedTools Read Grep Glob Edit Write ^
  "Bash(git status)" "Bash(git status *)" "Bash(git diff)" "Bash(git diff *)" ^
  "Bash(git log *)" "Bash(git ls-files *)" "Bash(git show *)" !TEST_ARGS! ^
  --disallowedTools NotebookEdit PowerShell WebFetch WebSearch ^
  --output-format text %MODEL_ARG% < "%PROMPT_FILE%"
exit /b %ERRORLEVEL%

:show_changes
echo.
echo ===== changed files - review with: git diff; undo with: git restore .
git status --short
git diff --stat
exit /b 0

:write_prompt
echo You get a review report for the project in the current working directory (%PROJECTF%). The report was made with review skills; each finding has a location, a severity (error, warning or info), a rule ID and a reason.
echo.
echo Task: fix the findings with severity %SEV%.
if defined FILTER echo Only fix these findings: !FILTER!
echo.
echo Rules:
echo 1. Verify each finding in the code before you change anything. If a finding is a false positive or already fixed, do not change the code; list it as skipped with the reason.
echo 2. Make the smallest change that fixes the finding. Keep the existing code style. Do not refactor unrelated code.
echo 3. Do not change public APIs, file formats or behavior beyond what a finding requires. If a fix needs such a change, do not make it; list it as "needs decision".
echo 4. Secrets: never print secret values. Replace them with a reference to an environment variable or config entry, and list "rotate the secret" as a manual step. Do not rewrite git history.
echo 5. Do not commit, push, create branches, delete files or install anything. Steps you can't do (e.g. git rm --cached, installing tools, updating dependencies) go to the manual steps.
echo 6. Do not modify the report file.
if defined TEST_CMD echo 7. After the fixes, run the test command: !TEST_CMD!
if defined TEST_CMD echo    If it fails because of your changes, fix or revert them.
echo This is a non-interactive run: never wait for confirmation.
echo.
echo At the end, write a summary in %LANG_%:
echo - a table with: finding (file:line and rule ID), status (fixed / skipped / needs decision / manual), what you changed and why
echo - the list of changed files
echo - the manual steps for the user
if defined TEST_CMD echo - the test result
echo Explain each change in one sentence so that the author understands it. The author will review the diff.
if defined EXTRA echo.
if defined EXTRA echo Additional instructions: !EXTRA!
echo.
echo ===== REPORT =====
type "%REPORT%"
exit /b 0

rem ---------------------------------------------------------------------------
:usage_error
call :usage_text 1>&2
exit /b 2

:usage
call :usage_text
exit /b 0

:usage_text
echo Usage: fix-issues.cmd [options] report.md [project_dir]
echo.
echo Fixes the findings in report.md (written by run-skills -o) in the project.
echo The project directory is read from the report header unless given.
echo.
echo Options:
echo   -s LEVEL        minimum severity to fix: error, warning (default) or info
echo   -f TEXT         fix only these findings, e.g. "SC1,EH1" (use quotes)
echo   -t COMMAND      test/build command Claude may run, e.g. "npm test"
echo   -o FILE         also write Claude's change summary to FILE
echo   -l LANG         language of the summary (default: English)
echo   -m MODEL        Claude model (default: Claude Code's default)
echo   -x TEXT         extra instructions
echo   --allow-dirty   run even if the project has uncommitted git changes
echo   --dry-run       print the claude command and prompt instead of running it
echo   -h, --help      show this help
echo.
echo Examples:
echo   fix-issues.cmd report.md
echo   fix-issues.cmd -s error -t "npm test" -o fixes.md report.md
echo   fix-issues.cmd -f "SC1,SC5" report.md ..\my-project
exit /b 0
