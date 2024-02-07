import std/[math, os, osproc, sequtils,
            strformat, strutils, sugar, tables]

import todo, database, bbansi, ansi

proc error(s: string, code: int = 1) =
  echo fmt"[red]ERROR[/]: {s}".bb
  quit code

# TODO: add option to split?
proc confirm(question: string, postQuestion: string = ""): bool =
  stdout.write question & " [yellow](Y/n)[/] ".bb
  if postQuestion != "":
    stdout.write "\n" & postQuestion & "\n"
  while true:
    case readLine(stdin).toLower:
      of "y", "yes": return true
      of "n", "no": return false
      else: stdout.write "please specify: [yellow](y)es/(n)o[/] ".bb

proc show*(global: bool = false, hide: bool = false, status: bool = false,
           todo: bool = false, workingDirectory: string = "",
               quiet: bool = false) =
  ## show the todo's (default cmd)
  ##
  ## *NOTE*: --status and --todo are mutually exclusive

  let root = if workingDirectory == "": getCurrentDir() else: workingDirectory
  let todoPaths = collectFiles(root, global, exit = true, quiet = quiet)
  if status and todo:
    error "-s/--status and -t/--todo are mutually exclusive"

  for p in todoPaths:
    let t = db.get(p)

    if status:
      echo t.status(p)
    elif not todo:
      t.stylizeTodo(hide)
      echo t.status(p).centerText
    else:
      let tasks = (
        if hide: t.tasks.filterIt(not it.complete)
        else: t.tasks
      )
      for task in tasks:
        var line = task.indent
        line.add(
          if task.complete: icons.checked
          else: icons.unchecked
        )
        line.add(" ")
        line.add(if task.complete: $(task.task.bb("dim strike"))
                 else: task.task
        )
        echo line


proc clearItems*(global: bool = false, yes: bool = false,
  workingDirectory: string = "") =
  ## remove all checked off items

  # TODO: write todo fetcher proc...
  let root = if workingDirectory != "": getCurrentDir() else: workingDirectory
  let todoPaths = collectFiles(root, global, exit = true)
  var statuses: seq[string]

  for p in todoPaths:
    var t = db.get(p)
    for task in t.tasks.filterIt(it.complete):
      echo bb("[red]") & task.task

    # TODO: use a relativePath for this
    # TODO: actually use yes
    if confirm($bb(&"remove above completed tasks and overwrite: \n  [b]{t.path}")):
      t.removeComplete()

      # TODO: don't add todo to database if it isn't already there...
      # change name to `update`
      db.add(t)
      db.save()

proc edit*(global: bool = false,
      workingDirectory: string = ""
           ) =
  ## launch $$EDITOR with todo files
  let cwd = if workingDirectory == "": getCurrentDir() else: workingDirectory
  let (_, dirName) = cwd.splitPath()
  if not existsEnv("EDITOR"): error("$EDITOR is not set")

  let root = if workingDirectory != "": getCurrentDir() else: workingDirectory
  var todoFiles = collectFiles(root, global)
  if todoFiles.len == 0:
    echo "No todo files found in the current directory..."
    if not confirm(&"Start a new one at ./{fileNamePatterns[0]}?"): quit 0

    writeFile(fileNamePatterns[0], todo_template % dirName)
    todoFiles.add(fileNamePatterns[0])

  discard execShellCmd "$EDITOR " & todoFiles.join(" ")

proc getPath(p: string, absolute: bool): string =
  if absolute: p else: p.relativePath(p.parentDir.parentDir)

proc getCellLen(rows: seq[tuple[path: string, complete: string,
    incomplete: string]]): seq[int] =
  @[
    rows.mapIt(len(it.path)),
    rows.mapIt(len(it.complete)),
    rows.mapIt(len(it.incomplete)),
  ].mapIt(max(it))

proc styleRow(row: tuple[path: string, complete: string, incomplete: string],
    cellLens: seq[int]): string =
  @[
   $(bb(row.path.alignLeft(cellLens[0]), "b")),
   icons.checked & " " & $(bb(row.complete.center(cellLens[1]), "green")),
   icons.unchecked & " " & $(bb(row.incomplete.center(cellLens[2]), "red"))
    ].join(" " & boxV & " ")

proc list*(absolute: bool = false) =
  ## list registered todo's

  db.check(reload = true)

  if db.empty:
    echo "database is empty use todo db -a to start tracking todo's"
    quit 0


  let rows = collect:
    for p, t in db.todos:
      (path: p.getPath(absolute),
       complete: $t.complete,
       incomplete: $t.incomplete)

  let cellLens = getCellLen(rows)

  let styledRows = collect:
    for row in rows:
      styleRow(row, cellLens)

  let header = @[
      $("[italic]" & "todo's".center(sum(cellLens) + 10)).bb & "",
      boxH.repeat(sum(cellLens) + 10)
    ]
  echo concat(
    header,
    styledRows
  ).join("\n").centerText()

proc database*(add: seq[string] = @[], del: seq[string] = @[]) =
  ## manage todo database

  for p in add:
    echo "registering todo @ " & p
    db.add p

  for p in del:
    echo "removing todo @ " & p
    db.del p

  echo &"tracking {len(db.todos)} todo's"
  db.save()

const grepArgs = "-rni"
const nimgrepArgs = "-ri"

proc pickGrepExe(): tuple[exe: string, args: string] =
  result.exe = findExe("nimgrep")
  if result.exe == "":
    result.exe = findExe("grep")
  if result.exe == "":
    error "nimgrep or grep needs to be on the $PATH"
  result.args =
    if result.exe.endswith("nimgrep"): nimgrepArgs
    else: grepArgs

proc grep*(symbol: string = "#", args: string = "",
           workingDirectory: string = "", path: seq[string]) =
  ## run (nim)grep for TODO comments

  let (grepExe, args) = pickGrepExe()
  let cmd = &"{grepExe} {args} \"{symbol} TODO\" " & path.join(" ")
  echo bb(&"cmd: [b]{cmd}")
  let errC = execCmd cmd
  if errC != 0:
    echo bb(&"[red]grep exited with error code {errC}")

type
  GitFileStatus = object
    staged: bool
    name: string
    todo: bool

  GitStatus = object
    dirty: bool
    files: seq[GitFileStatus]

proc parseGitFileStatus(s: string): GitFileStatus =
  ## parse single line from git --status --porcelain=v1
  let (x, y) = (s[0], s[1])
  var file = s[3..^1]

  if x != ' ' and y == ' ': result.staged = true

  # handle file names with quotes
  if file[0] == '"' and file[^1] == '"':
    file = file[1..^2]

  result.name = file
  result.todo = file in fileNamePatterns

proc parseGitStatus(s: string): GitStatus =
  ## generate object from git --status --porcelain=v1
  if len(s) > 0: result.dirty = true

  for line in s.strip(leading = false).splitLines():
    echo "line: " & line
    result.files.add parseGitFileStatus(line)

  echo result

proc commit*(yes: bool = false) =
  ## create commit string for git
  let (output, code) = execCmdEx("git status --porcelain=v1")
  if code != 0:
    echo (
      "[red]git had non-zero exit status...\n".bb &
      "git output:\n" &
      output
    )
    quit 1

  if output == "":
    echo "nothing to commit"
    quit 0

  let status = parseGitStatus(output)
  echo "staged: " & $status.files.filterIt(it.staged)

  let nonTodoStaged = status.files.filterIt(not it.todo and it.staged)
  let todoStaged = status.files.filterIt(it.todo and it.staged)

  if len(nonTodoStaged) > 0:
    echo "NOOOO"

  if len(todoStaged) > 0:
    echo "cool"

  # TODO: get user input then do it
  let message = "todo"
  if not yes or confirm(
    &"> cmd: git commit -m {message}\n" &
    "run the above command?"):
    echo "jk"
