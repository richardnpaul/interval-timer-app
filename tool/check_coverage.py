#!/usr/bin/env python3
import sys
import os

lcov_path = "coverage/lcov.info"

# If lcov.info doesn't exist, we fail. The previous hook step should have generated it.
if not os.path.exists(lcov_path):
    print("Error: coverage/lcov.info not found. Did `flutter test --coverage` run successfully?")
    sys.exit(1)

with open(lcov_path, 'r') as f:
    lines = f.readlines()

total_lines = 0
hit_lines = 0

for line in lines:
    if line.startswith("LF:"):
        total_lines += int(line.strip().split(":")[1])
    elif line.startswith("LH:"):
        hit_lines += int(line.strip().split(":")[1])

if total_lines == 0:
    print("Error: No lines found in coverage report.")
    sys.exit(1)

coverage = (hit_lines / total_lines) * 100
if coverage < 100.0:
    print(f"Error: Test coverage is {coverage:.2f}%. 100% coverage is required to commit!")
    sys.exit(1)

print("Test coverage is 100%. Pre-commit check passed.")
sys.exit(0)
