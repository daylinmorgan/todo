import std/[math, sequtils, strutils, terminal, unicode]
import regex

const
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
