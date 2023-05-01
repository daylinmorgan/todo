import std/[os, json, tables, times]

import todo

proc getDataDir*(): string =
  ## Returns the data directory of the current user for applications.
  # follows std/os.getCacheDir
  # which in turn follows https://crates.io/crates/platform-dirs
  when defined(windows):
    result = getEnv("LOCALAPPDATA")
  elif defined(osx):
    result = getEnv("XDG_DATA_HOME", getEnv("HOME") / "Library/Application Support")
  else:
    result = getEnv("XDG_DATA_HOME", getEnv("HOME") / ".local/share")

  result.normalizePathEnd(false)

type
  Database* = object
    path*: string
    todos*: Table[string, Todo]

proc todoFileInfo(p: string): (string, Time) =
  (p.absolutePath,
   getFileInfo(p.absolutePath).lastWriteTime)

proc add*(db: var Database, p: string) =
  let (pAbs, _) = todoFileInfo(p)
  if db.todos.contains(pAbs):
    if db.todos[pAbs].wasModified:
      db.todos[pAbs] = parseTodo(pAbs)
  else:
    db.todos[pAbs] = parseTodo(pAbs)

proc add*(db: var Database, t: Todo) =
  db.todos[t.path] = t

proc del*(db: var Database, t: Todo) =
  db.todos.del t.path

proc del*(db: var Database, p: string) =
  let (pAbs, _) = todoFileInfo(p)
  if db.todos.contains(pAbs):
    db.todos.del pAbs
  else:
    echo "p not found in databse"


proc get*(db: Database, p: string): Todo =
  let (pAbs, _) = todoFileInfo(p)
  if db.todos.contains(pAbs):
    if not db.todos[pAbs].wasModified:
      return db.todos[pAbs]

  parseTodo(pAbs)

proc empty*(db: Database): bool {.inline.} = len(db.todos) == 0

proc save*(db: Database) =
  if not dirExists(db.path.parentDir):
    db.path.parentDir.createDir()
  db.path.writeFile(pretty( %* db.todos))

proc check*(db: var Database, reload: bool = false) =

  var changed = false
  let todos = db.todos
  for p, t in todos:
    if not fileExists(p):
      changed = true
      db.del t

    if reload and t.wasModified:
      changed = true
      db.add p

  if changed:
    db.save


proc load*(): Database =
  let dbPath = getDataDir() / "todo" / "todos.json"
  if not fileExists(dbPath):
    return Database(path: dbPath)
  else:
    result.path = dbPath
    result.todos = parseJson(readFile(dbPath)).to(Table[string, Todo])

  result.check

var db*: Database = load()
