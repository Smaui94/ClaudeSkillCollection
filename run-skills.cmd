@echo off
rem Runs selected review skills of this collection on a project (Windows).
rem
rem AI mode (default): starts Claude Code non-interactively (claude -p) in the
rem project directory. Claude may only read files and run the skills' helper
rem scripts and read-only git commands; editing tools are disabled.
rem Scripts mode (--scripts-only): runs only the helper scripts of the selected
rem skills with Git Bash, without Claude.
rem
rem Usage: run-skills.cmd [options] skill[,skill...] [project_dir]
rem        (skills may be separated by commas or spaces)
rem        run-skills.cmd --help

setlocal EnableExtensions EnableDelayedExpansion

set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "DIRF=%DIR:\=/%"

set "OUT="
set "LANG_=English"
set "MODEL="
set "EXTRA="
set "SCRIPTS_ONLY="
set "DRY_RUN="
set "SKILLS="
set "PROJECT="
set "NPOS="

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="-o" (set "OUT=%~f2" & shift & shift & goto parse)
if /i "%~1"=="-l" (set "LANG_=%~2" & shift & shift & goto parse)
if /i "%~1"=="-m" (set "MODEL=%~2" & shift & shift & goto parse)
if /i "%~1"=="-x" (set "EXTRA=%~2" & shift & shift & goto parse)
if /i "%~1"=="--scripts-only" (set "SCRIPTS_ONLY=1" & shift & goto parse)
if /i "%~1"=="--dry-run" (set "DRY_RUN=1" & shift & goto parse)
if /i "%~1"=="--list" goto list
if /i "%~1"=="-h" goto usage
if /i "%~1"=="--help" goto usage
set "ARG=%~1"
if "!ARG:~0,1!"=="-" (
  echo run-skills: unknown option %1 ^(see --help^) 1>&2
  exit /b 2
)
rem cmd splits "a,b" into separate arguments, so collect all positionals.
set /a NPOS+=1
set "POS!NPOS!=%~1"
shift
goto parse

:parsed
if not defined NPOS goto usage_error
rem The last positional is the project directory unless it is a skill name.
set "LAST=!POS%NPOS%!"
if %NPOS% GEQ 2 (
  set "LASTSKILL="
  if /i "!LAST!"=="full" set "LASTSKILL=1"
  if exist "%DIR%\!LAST!\SKILL.md" set "LASTSKILL=1"
  if not defined LASTSKILL (
    set "PROJECT=!LAST!"
    set /a NPOS-=1
  )
)
for /l %%i in (1,1,%NPOS%) do set "SKILLS=!SKILLS! !POS%%i!"
if not defined PROJECT set "PROJECT=."
if not exist "%PROJECT%\" (
  echo run-skills: project directory not found: %PROJECT% 1>&2
  exit /b 2
)
for %%p in ("%PROJECT%") do set "PROJECT=%%~fp"
if "%PROJECT:~-1%"=="\" set "PROJECT=%PROJECT:~0,-1%"
set "PROJECTF=%PROJECT:\=/%"

rem Validate the skill list ("full" = full-review). "exit /b" inside a FOR
rem loop does not reliably set the exit code, so collect errors first.
set "LIST="
set "BAD="
for %%s in (%SKILLS:,= %) do (
  set "S=%%~s"
  if /i "!S!"=="full" set "S=full-review"
  if exist "%DIR%\!S!\SKILL.md" (
    if defined LIST (set "LIST=!LIST! !S!") else (set "LIST=!S!")
  ) else (
    echo run-skills: unknown skill '!S!' ^(see --list^) 1>&2
    set "BAD=1"
  )
)
if defined BAD exit /b 2
if not defined LIST (
  echo run-skills: no skills given 1>&2
  exit /b 2
)

if defined SCRIPTS_ONLY goto scripts_only
goto ai_mode

rem ---------------------------------------------------------------------------
:scripts_only
call :find_bash
if not defined BASH (
  echo run-skills: Git Bash not found - install Git for Windows ^(https://git-scm.com^) 1>&2
  exit /b 2
)
set "SKILLS_TEXT=%LIST: =, %"
set "MODE=scripts-only"
if defined OUT (
  call :header > "%OUT%"
  call :run_scripts >> "%OUT%" 2>&1
  type "%OUT%"
) else (
  call :header
  call :run_scripts
)
exit /b 0

rem Report header. fix-issues reads the project path from the
rem "run-skills:project=" comment, so keep that line format stable.
rem Delayed expansion is off here, otherwise the "!" in "<!--" is removed.
:header
setlocal DisableDelayedExpansion
echo # Skill review report
echo.
echo - Project: `%PROJECTF%`
echo - Skills: %SKILLS_TEXT%
echo - Mode: %MODE%
echo - Language: %LANG_%
echo - Date: %DATE% %TIME:~0,5%
echo.
echo ^<!-- run-skills:project=%PROJECTF% --^>
echo.
echo ---
echo.
endlocal
exit /b 0

:run_scripts
for %%s in (%LIST%) do (
  set "FOUND="
  for %%f in ("%DIR%\%%s\scripts\*.sh") do (
    set "FOUND=1"
    echo =================== %%s ^(%%~nxf^)
    set "SCRIPT=%%~ff"
    "!BASH!" "!SCRIPT:\=/!" "%PROJECTF%"
    echo.
  )
  if not defined FOUND (
    echo =================== %%s
    echo no helper script - this skill needs Claude ^(run without --scripts-only^)
    echo.
  )
)
exit /b 0

:find_bash
set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
rem Fall back to bash on PATH, but skip the WSL launcher in System32.
if not defined BASH (
  for /f "delims=" %%b in ('where bash 2^>nul ^| findstr /v /i /c:"\System32\"') do (
    if not defined BASH set "BASH=%%b"
  )
)
exit /b 0

rem ---------------------------------------------------------------------------
:ai_mode
where claude >nul 2>&1
if errorlevel 1 (
  echo run-skills: claude not found - install Claude Code or use --scripts-only 1>&2
  exit /b 2
)
set "SKILLS_TEXT=%LIST: =, %"
set "MODE=claude"
set "PROMPT_FILE=%TEMP%\run-skills-%RANDOM%%RANDOM%.txt"
call :write_prompt > "%PROMPT_FILE%"

set "MODEL_ARG="
if defined MODEL set "MODEL_ARG=--model "%MODEL%""

if defined DRY_RUN (
  echo # working directory: %PROJECT%
  echo claude -p --permission-mode dontAsk --add-dir "%DIRF%" --allowedTools Read Grep Glob "Bash(bash %DIRF%/*)" "Bash(git log *)" ... --disallowedTools Edit Write NotebookEdit PowerShell WebFetch WebSearch --output-format text %MODEL_ARG% ^< prompt
  echo ----- prompt -----
  type "%PROMPT_FILE%"
  del "%PROMPT_FILE%" >nul 2>&1
  exit /b 0
)

pushd "%PROJECT%"
set "RC=0"
if defined OUT (
  call :header > "%OUT%"
  call :claude_run >> "%OUT%"
  set "RC=!ERRORLEVEL!"
  type "%OUT%"
) else (
  call :header
  call :claude_run
  set "RC=!ERRORLEVEL!"
)
popd
del "%PROMPT_FILE%" >nul 2>&1
exit /b %RC%

rem "call" is needed when claude is a .cmd shim (npm install).
:claude_run
call claude -p --permission-mode dontAsk --add-dir "%DIRF%" ^
  --allowedTools Read Grep Glob "Bash(bash %DIRF%/*)" "Bash(git log *)" ^
  "Bash(git blame *)" "Bash(git ls-files *)" "Bash(git ls-tree *)" ^
  "Bash(git diff *)" "Bash(git show *)" "Bash(git status *)" ^
  "Bash(git describe *)" "Bash(git rev-parse *)" "Bash(git check-ignore *)" ^
  "Bash(git branch *)" "Bash(git for-each-ref *)" "Bash(git rev-list *)" ^
  "Bash(wc *)" ^
  --disallowedTools Edit Write NotebookEdit PowerShell WebFetch WebSearch ^
  --output-format text %MODEL_ARG% < "%PROMPT_FILE%"
exit /b %ERRORLEVEL%

:write_prompt
echo Run these review skills from the skill collection in %DIRF% on the project in the current working directory: %SKILLS_TEXT%.
echo.
echo For each skill, read %DIRF%/NAME/SKILL.md (NAME = the skill name) and follow it exactly. Wherever a skill says ^<skill-dir^>, use %DIRF%/NAME.
echo Run helper scripts only in this form: bash %DIRF%/NAME/scripts/SCRIPT.sh ARGS (use . as the project root).
echo Review only: do not create, modify or delete any files, and run no commands that change state.
echo This is a non-interactive run: never wait for confirmation. Where a skill says to ask the user, choose the sensible default and state the assumption in the report.
echo.
echo Report: one section per skill in that skill's report format, then a combined summary with the 10 most important findings across all skills, most severe first. Write the report in %LANG_%.
if defined EXTRA (
  echo.
  echo Additional instructions: !EXTRA!
)
exit /b 0

rem ---------------------------------------------------------------------------
:list
for /d %%d in ("%DIR%\*") do (
  if exist "%%d\SKILL.md" (
    set "MARK= "
    if exist "%%d\scripts\*.sh" set "MARK=S"
    set "NAME=%%~nxd                              "
    set "DESC="
    for /f "tokens=1,* delims=:" %%a in ('findstr /b /c:"description:" "%%d\SKILL.md"') do set "DESC=%%b"
    echo !NAME:~0,30! !MARK! !DESC:~1,90!
  )
)
echo (S = has helper scripts, usable with --scripts-only)
exit /b 0

:usage_error
call :usage_text 1>&2
exit /b 2

:usage
call :usage_text
exit /b 0

:usage_text
echo Usage: run-skills.cmd [options] skill[,skill...] [project_dir]
echo.
echo Runs the given review skills of this collection on project_dir (default: .).
echo Skills may be separated by commas or spaces; "full" = full-review.
echo.
echo Options:
echo   -o FILE         also write the report to FILE
echo   -l LANG         report language (default: English)
echo   -m MODEL        Claude model (default: Claude Code's default)
echo   -x TEXT         extra instructions, e.g. "focus on src/" or "depth thorough"
echo   --scripts-only  run only the skills' helper scripts with Git Bash, without Claude
echo   --dry-run       print the claude command and prompt instead of running it
echo   --list          list the available skills
echo   -h, --help      show this help
echo.
echo Examples:
echo   run-skills.cmd secrets-scan,repo-hygiene ..\my-project
echo   run-skills.cmd -l Deutsch -o review.md full ..\my-project
echo   run-skills.cmd --scripts-only todo-audit,config-review .
exit /b 0
