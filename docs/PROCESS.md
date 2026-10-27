# Process rules (from the project owner)
- Build in numbered passes; the owner tests between passes. Pass 1 = classes/AI/UX/net depth (in progress).
- Use ONE sub-agent at a time from pass 2 onward (usage budget). The lead integrates and verifies.
- **Every 5th pass (5, 10, 15...): Grand Simulation.** Simulate a whole match start to finish with all 14 classes
  as bot-driven competitors in one world until exactly one remains alive (match-based permadeath).
  Then: study the results (who won and why, time of deaths, resource flows, Purge kill/steal/capture stats, dominant or
  useless classes, stalls, degenerate strategies), research design fixes where helpful, write docs/SIM_REPORT_<pass>.md
  with real numbers, and build the next pass's work from those findings.
- Harness: tools/sim_match.gd (to build in pass 2 so it exists and is exercised before pass 5). It must use the real Rules
  module, deterministic seeds, bot command streams only (no direct state edits), and log metrics to JSON.
- Report only what was actually run. A simulation of bots is not evidence of human fun.

## Win condition (owner clarification, 2026-10-27)
The goal is to thrive, not merely survive. Only Total Conquest wins (kill/eliminate all rivals and own the entire map). Remove Dominion(60%)/Crowned(12 weeks) wins from the rules in pass 2 and replace with Total Conquest + a non-ending Prosperity score.
