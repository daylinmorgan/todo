import std/[
  enumerate, os, sequtils, strformat,
  strutils, tables, times,
  sugar, wordwrap
]
import regex, hwylterm
import ./[ansi]

type
  TaskStatus = enum
    Complete, Incomplete, InProgress
  Task* = object
    status: TaskStatus
    complete*: bool
    text*: string
    indent*: string
    line*: int

  Todo* = object
    title*: string
    path*: string
    raw*: string
    stylized: string
    tasks*: seq[Task]
    lastWriteTime*: Time
    hideLines: seq[int]
    # TODO: implement hideLines as a seq of slices?

proc incomplete*(t: Todo): int = t.tasks.filterIt(it.status == Incomplete).len
proc complete*(t: Todo): int   = t.tasks.filterIt(it.status == Complete).len
proc inProgress*(t: Todo): int = t.tasks.filterIt(it.status == InProgress).len

proc addLine(s: var string, s2: string) =
  s.add s2
  s.add "\n"

let useNerdFonts = getEnv("TODO_NERDFONTS_DISABLE") == ""
let taskIcons: array[TaskStatus, string] =
  if not useNerdFonts: ["[✓]","[ ]","[-]"]
  else: ["","","󰡖"]
let wrapIcon =
  if not useNerdFonts: "->"
  else: "↳"

let icons* = (
  if os.getEnv("TODO_NERDFONTS_DISABLE") != "": (
    unchecked: "[ ]", checked: "[✓]", wrap: "->", inprogress: "[-]" )
  else: (unchecked: "",
         checked: "",
         wrap: "↳",
         inprogress: "󰡖"
        )
)

proc removeLines*(s: string, idxs: seq[int]): string =
  var lines = s.splitLines()
  for i in countdown(len(idxs)-1, 0):
    lines.delete(idxs[i])
  lines.join("\n")


proc wasModified*(t: Todo): bool = t.lastWriteTime !=
    t.path.getFileInfo.lastWriteTime

proc status*(t: Todo): string =
  let 
    parent = lastPathPart(parentDir(t.path))
    file = extractFilename(t.path)
    path = parent & "/" & file
  return $(fmt"[b]{path}[/] " &
          fmt" | {icons.checked} [green]{t.complete}[/]" &
          fmt" | {icons.unchecked} [red]{$t.incomplete}[/]"
    ).bb

proc stylize(task: Task): string =
  result.add task.indent
  result.add taskIcons[task.status]
  result.add " "
  case task.status:
  of Complete:
    result.add task.text.wrapWords(
        maxLineWidth = maxScreenWidth,
        newline = &"\n{task.indent}  {wrapIcon} "
    ).split("\n").mapIt($it.bb("faint strike")).join("\n")
  of Incomplete, InProgress:
    result.add task.text.wrapWords(
      maxLineWidth = maxScreenWidth,
      newline = &"\n{task.indent}  {wrapIcon} "
    )

proc addStylizedLine(t: var Todo, s: string, indent: string = "") =
  t.stylized = t.stylized & s.wrapWords(maxLineWidth = maxScreenWidth,
      newline = &"\n{indent}  {icons.wrap} ") & "\n"

template `=~` *(s: string, pattern: Regex2): untyped =
  var matches {.inject.}: RegexMatch2
  match(s, pattern, matches)

proc newTaskFromMatch(
  matches: RegexMatch2,
  line: string,
  i: int,
  status: TaskStatus
): Task =
  result.text = line[matches.group("task")]
  result.status = status
  result.indent = line[matches.group("indent")]
  result.line = i

template getMatch(m: RegexMatch2, l: string): string =
  l[m.group(0)]

proc parseText(t: var Todo) =

  # ignore final newlines
  for i, line in enumerate(t.raw.strip().splitLines()):

    # completed task
    if line =~ re2"^(?P<indent>\s*?)\-\s+\[\s*?[xX]\s*?\]\s(?P<task>.*)$":
      let task = newTaskFromMatch(matches, line, i, Complete)
      t.tasks.add task
      let
        lines = task.stylize()
        hideLines = collect:
          for i in 1..len(lines.splitLines()):
            i + len(t.stylized.splitLines()) - 2
      t.addStylizedLine lines
      t.hideLines.add hideLines

    # incomplete task
    elif line =~ re2"^(?P<indent>\s*?)\-\s+\[\s+\]\s(?P<task>.*)$":
      let task = newTaskFromMatch(matches, line, i, Incomplete)
      t.tasks.add task
      t.addStylizedLine task.stylize()

    # inprogress task
    elif line =~ re2"^(?P<indent>\s*?)\-\s+\[\s*?\-\s*?\]\s(?P<task>.*)$":
      let task = newTaskFromMatch(matches, line, i, InProgress)
      t.tasks.add task
      t.addStylizedLine task.stylize()

    # header 1
    elif line =~ re2"^#\s+?(.*)$":
      t.addStylizedLine($getMatch(matches, line).bb("cyan bold"))

    # header 2
    elif line =~ re2"^##\s+?(.*)$":
      t.addStylizedLine($getMatch(matches, line).bb("green bold"))

    # header 3
    elif line =~ re2"^###\s+?(.*)$":
      t.addStylizedLine($getMatch(matches, line).bb("yellow bold"))

    # ignore comments
    elif line =~ re2"^\s*?<!--(.*)-->\s*?$": discard

    # reduce some of the user's newlines
    elif line == "":
      if t.stylized[^2..^1] != "\n\n":
        t.addStylizedLine("")
    else:
      t.addStylizedLine(line)

  # this is kinda brute force
  t.stylized = t.stylized.strip() & '\n'

proc removeComplete*(t: var Todo) =

  let lines = collect:
    for task in t.tasks.filterIt(it.complete):
      task.line

  t.raw = t.raw.removeLines(lines)
  t.path.writeFile(t.raw)


proc parseTodo*(p: string): Todo =
  result.path = p.absolutePath
  result.lastWriteTime = getFileInfo(p).lastWriteTime
  result.raw = p.readFile

  result.parseText()


proc readFiles*(fileNames: seq[string]): Table[string, string] =
  for fileName in fileNames:
    result[fileName] = fileName.readFile

# combine this option with the config file?
let fileNamePatterns* = os.getEnv("TODO_PATTERNS", "todo.md:.todo.md").split(":")

# TODO: deduplicate global option as it's redundant with --working-directory
proc collectFiles*(root: string, global: bool, exit: bool = false,
    quiet: bool = false): seq[string] =
  var fileName: string
  for file in fileNamePatterns:
    filename =
      if global: getEnv("HOME") / file
      else: root / file

    if fileExists(fileName):
      result.add fileName

  if len(result) == 0 and exit:
    if not quiet:
      echo "No Todo's found!"
      echo "Get started with `todo edit`"
    quit 0


proc stylizeTodo*(t: Todo, hide: bool) =
  let text = 
    if hide: t.stylized.removeLines(t.hideLines)
    else: t.stylized
  echo boxify(text)

const todo_template* = """# $1 todo's

- [ ] an incomplete task
- [x] a complete task

<!-- generated with <3 by daylinmorgan/todo -->
"""
