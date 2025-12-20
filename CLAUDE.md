# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Advent of Code solutions repository written in Zig. Solutions are organized by year (2024, 2025) and day, with each day having its own directory containing a standalone `main.zig` file and input files.

**Important**: This project uses **Zig 0.15**, which uses the ArrayList initialization syntax `ArrayList(T){}` rather than `ArrayList(T).init(alloc)`.

## Build and Run Commands

### Build and run a solution
```bash
cd 2025/day01  # Navigate to the day directory
zig build-exe main.zig
./main
```

### Run tests
```bash
zig test <file>.zig
```

For example:
```bash
zig test a-bit-of-everything.zig
```

### Clean build artifacts
```bash
# Remove executables (gitignored as **/main)
find . -name main -type f -executable -delete
```

## Project Structure

- **Year/Day Organization**: Each day's solution is in `YYYY/dayNN/` with standalone `main.zig`
- **Template**: `2025/dayxx/main.zig` serves as a template for new day solutions
- **Input Files**: Each day directory contains `input` (actual problem input) and `testinput` (sample data)
- **Reference Code**: `a-bit-of-everything.zig` contains Zig language examples and tests

### Typical Day Directory
```
2025/dayNN/
├── main.zig       # Solution code
├── input          # Actual problem input
└── testinput      # Sample/test input
```

### Complex Solutions
Some days have multi-file solutions with supporting modules:
```
2025/day10/
├── main.zig       # Entry point
├── solver.zig     # Core algorithm (EquationSystem, LinEqSolver)
├── bounds.zig     # Constraint handling (Comparison, Variable)
├── frac.zig       # Rational arithmetic (Frac type)
└── logger.zig     # Custom logging
```

## Code Patterns

### Standard Imports and Setup
Most solutions use this pattern:
```zig
const std = @import("std");
const print = std.debug.print;
const parseInt = std.fmt.parseInt;
const cwd = std.fs.cwd;
const splitScalar = std.mem.splitScalar;
const tokenizeScalar = std.mem.tokenizeScalar;

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
var gpa = gpa_impl.allocator();
```

### File Reading
```zig
// Read entire file
const filepath = "input";
const contents = try cwd().readFileAlloc(gpa, filepath, 4 << 20);

// Process lines
var lines = std.mem.tokenizeScalar(u8, contents, '\n');
while (lines.next()) |line| {
    // Process line
}
```

### Custom Logging
For solutions with custom logging (like day10):
```zig
const dateLogFn = @import("logger.zig").logFn;
pub const std_options: std.Options = .{
    .logFn = dateLogFn,
};
```

## Architecture Notes

### Generic Type System
Complex solutions use generic types with compile-time type parameters:
- `Frac(T)`: Rational number implementation with type `T` for numerator/denominator
- `EquationSystem(T)`: Linear equation system solver parameterized by coefficient type
- `LinEqSolver(T)`: Optimization solver for equation systems

These types support operations like:
- Fraction arithmetic with automatic normalization
- Row reduction (RREF)
- Inequality constraints (<=, <, =, >=, >)
- Cost minimization over feasible regions

### Module Organization
Multi-file solutions use Zig's module system:
```zig
const Frac = @import("frac.zig").Frac;
const solver = @import("solver.zig");
```

No build.zig is used; files are compiled as standalone executables that import their dependencies directly.
