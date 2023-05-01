import std/[enumerate, os, sequtils, strformat, strutils, tables, times,
    sugar, wordwrap]

import regex

import ansi

type
  Task* = object
    complete*: bool
    task*: string
    indent*: string
    line*: int

  Todo* = object
    title*: string
    path*: string
    raw*: string
    stylized: string
    incomplete*: int
    complete*: int
    tasks*: seq[Task]
    lastWriteTime*: Time
    hideLines: seq[int]


let icons* = (
  if os.getEnv("TODO_NERDFONTS_DISABLE") != "": (unchecked: "[ ]",
      checked: "[✓]", wrap: "->")
  else: (unchecked: "", checked: "", wrap: "↳")
)

proc removeLines*(s: string, idxs: seq[int]): string =
  var lines = s.splitLines()
  for i in countdown(len(idxs)-1, 0):
    lines.delete(idxs[i])
  lines.join("\n")


proc wasModified*(t: Todo): bool = t.lastWriteTime !=
    t.path.getFileInfo.lastWriteTime

proc status*(t: Todo, p: string): string =
  let row = (path: t.path,
          complete: $t.complete,
          incomplete: $t.incomplete)

  return "  " & (@[
      p.bold,
      icons.checked & " " & row.complete.green,
      icons.unchecked & " " & row.incomplete.red,
    ]
    ).join(" | ")


proc addStylizedLine(t: var Todo, task: var Task): seq[int] =
  if task.complete:
    let stylizedLine = task.indent & icons.checked & " " & task.task.wrapWords(
        maxLineWidth = maxScreenWidth,
        newline = &"\n{task.indent}  {icons.wrap} ").split("\n").mapIt(
        it.dim.strike).join("\n")

    let hideLines = collect:
      for i in 1..len(stylizedLine.splitLines()):
        i + len(t.stylized.splitLines()) - 2

    t.stylized = t.stylized & stylizedLine & "\n"
    return hideLines
  else:
    let stylizedLine = task.indent & icons.unchecked & " " &
        task.task.wrapWords(maxLineWidth = maxScreenWidth,
        newline = &"\n{task.indent}  {icons.wrap} ")

    t.stylized = t.stylized & stylizedLine & "\n"

proc addStylizedLine(t: var Todo, s: string, indent: string = "") =
  t.stylized = t.stylized & s.wrapWords(maxLineWidth = maxScreenWidth,
      newline = &"\n{indent}  {icons.wrap} ") & "\n"

proc editTask(task: var Task) =
  task.task = "REDACTED"

template `=~` *(s: string, pattern: Regex2): untyped =
  var matches {.inject.}: RegexMatch2
  match(s, pattern, matches)

proc digestTaskMatch(m: RegexMatch2, line: string): tuple[task,
    indent: string] =
  result.task = line[m.group("task")]
  result.indent = line[m.group("indent")]

template getMatch(m: RegexMatch2, l: string): string =
  l[m.group(0)]

proc parseText(t: var Todo) =

  # ignore final newlines
  for i, line in enumerate(t.raw.strip().splitLines()):

    # completed task
    if line =~ re2"^(?P<indent>\s*?)\-\s+\[\s*?[xX]\s*?\]\s(?P<task>.*)$":
      let (task, indent) = digestTaskMatch(matches, line)
      t.tasks.add Task(complete: true, task: task, indent: indent, line: i)
      t.complete.inc
      t.hideLines = t.hideLines.concat(t.addStylizedLine(t.tasks[^1]))

    # incomplete task
    elif line =~ re2"^(?P<indent>\s*?)\-\s+\[\s+\]\s(?P<task>.*)$":
      let (task, indent) = digestTaskMatch(matches, line)
      t.tasks.add Task(complete: false, task: task, indent: indent, line: i)
      t.incomplete.inc
      discard t.addStylizedLine(t.tasks[^1])

    # header 1
    elif line =~ re2"^#\s+?(.*)$":
      t.addStylizedLine(getMatch(matches, line).cyan.bold)

    # header 2
    elif line =~ re2"^##\s+?(.*)$":
      t.addStylizedLine(getMatch(matches, line).green.bold)

    # header 3
    elif line =~ re2"^###\s+?(.*)$":
      t.addStylizedLine(getMatch(matches, line).yellow.bold)

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

let fileNamePatterns* = os.getEnv("TODO_PATTERNS", "todo.md:.todo.md").split(":")

# TODO: deduplicate global option as it's redundant with --working-directory
proc collectFiles*(root: string, global: bool, exit: bool = false,
    quiet: bool = false): seq[string] =
  var fileName: string
  for file in fileNamePatterns:
    if global:
      fileName = getEnv("HOME") / file
    else:
      fileName = root / file

    if fileExists(fileName):
      result.add fileName

  if len(result) == 0 and exit:
    if not quiet:
      echo "No Todo's found!"
      echo "Get started with `todo edit`"
    quit 0


proc stylizeTodo*(t: Todo, hide: bool) =
  if hide:
    echo t.stylized.removeLines(t.hideLines).boxify
  else:
    echo t.stylized.boxify


const todo_template* = """# $1 todo's

- [ ] an incomplete task
- [x] a complete task

<!-- generated with <3 by daylinmorgan/todo -->
"""
