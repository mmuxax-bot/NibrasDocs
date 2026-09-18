# Phase A2 — Selection color / highlight / size

## Rules
- **No selection**: only changes default editor color/size (or page bg); snackbar explains
- **With selection**: wraps only that range
  - Text: `[color=#RRGGBB]text[/color]`
  - Highlight: `[bg=#RRGGBB]text[/bg]`
  - Size: `[size=18]text[/size]`
- Re-applying strips old markers first
- Clear format on selection (Style tab)

## Test
1. Select a word → color palette → only that word marked
2. Select phrase → Size 24 chip → `[size=24]...`
3. Select → Clear format
4. Save / reopen — markers remain
