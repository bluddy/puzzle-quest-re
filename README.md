# Puzzle Quest: Challenge of the Warlords - Reverse Engineering Project

This repository contains the reverse-engineering analysis, tools, documentation, and C++ reimplementation of *Puzzle Quest: Challenge of the Warlords* (PC 2007).

## Project Structure
* `docs/`: Reverse-engineering documentation, architectural specs, and game knowledge base.
  * [`REVERSE_ENGINEERING_PLAN.md`](docs/REVERSE_ENGINEERING_PLAN.md): Strategic roadmap and milestones.
  * [`GAME_KNOWLEDGE_BASE.md`](docs/GAME_KNOWLEDGE_BASE.md): Game mechanics, formulas, and reverse-engineering hypotheses.
  * `LUA_API.md`: Detailed catalog of all engine functions exposed to Lua.
  * `DATA_STRUCTURES.md`: C++ reconstructed structs and memory layouts.
* `tools/`: Python and Ghidra automation scripts for binary analysis and decompiler extraction.
* `src/`: Modern C++ (C++20) clean-room engine reimplementation.
* `game/`: Original game binaries and assets (not tracked in git).

## Setup
* Python virtual environment:
  ```powershell
  python -m venv venv
  .\venv\Scripts\pip install -r requirements.txt
  ```
