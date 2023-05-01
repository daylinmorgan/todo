import std/[macros, math, os, sequtils, strutils, tables, terminal, unicode]
import regex

const
  ansiReset = "\e[0m"

  boxV* = "│"
  boxH* = "─"
  boxTL* = "╭"
  boxTR* = "╮"
  boxBL* = "╰"
  boxBR* = "╯"
  boxSEP* = "┆"

let maxScreenWidth* = min(88, terminalWidth()) - 8

proc escapeAnsi*(s: string): string =
  const reAnsiCodes = re2"""(?x)
  \x1B  # ESC
  (?:   # 7-bit C1 Fe (except CSI)
      [@-Z\\-_]
  |     # or [ for CSI, followed by a control sequence
      \[
      [0-?]*  # Parameter bytes
      [ -/]*  # Intermediate bytes
      [@-~]   # Final byte
  )
  """

  s.replace(reAnsiCodes, "")


macro vt100Style*(arg: untyped): untyped =
  ## generates a basic colorizing proc
  arg.expectLen 2
  let name = arg[0]
  let code = arg[1]
  let completeCode = newLit("\e[" & $code.intVal & "m")

  result = quote do:
    proc `name`*(s: string): string =
      if os.existsEnv("NO_COLOR"): return s
      result = `completeCode` & s
      if not s.endsWith(ansiReset):
        result.add(ansiReset)


macro vt100Styles*(body: untyped) =
  ## generate vt100 procs for multiple styles/colors
  expectKind(body, nnkStmtList)
  result = newStmtList()
  for x in body.children:
    result.add(nnkCommand.newTree(
      ident("vt100Style"),
      x
    ))

vt100Styles:
  bold 1
  dim 2
  italic 3
  # underline 4
  # reverse 7
  strike 9

  red 31
  green 32
  yellow 33
  blue 34
  # magenta 35
  cyan 36
  # white 37

proc runeOffset(s: string): int =
  let bigRunes = s.toRunes().mapIt(it.size()).filterIt(it > 3)
  return bigRunes.sum() - len(bigRunes)*3

proc maxWidth(s: string): int = s.splitLines.mapIt(it.escapeAnsi.runeLen).max

proc centerText*(s: string): string =
  let
    columns = s.maxWidth
    indentSize = ((terminalWidth() - columns) / 2).int

  indent(s, indentSize)

proc boxify*(s: string): string =
  let columns = s.maxWidth
  var rows: seq[string]

  rows.add boxTL & boxH.repeat(columns+2) & boxTR

  for line in s.splitLines:
    rows.add(
      boxV & " " & line.alignLeft(
        columns + line.len - line.escapeAnsi.len - line.runeOffset,
       ' '.Rune) & " " & boxV)

  rows.add boxBL & boxH.repeat(columns+2) & boxBR

  return rows.join("\n").centerText
