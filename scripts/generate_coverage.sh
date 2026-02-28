#!/usr/bin/env bash

# Exit on error
set -o errexit
set -o nounset

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Running tests with coverage...${NC}"
flutter test --coverage

echo -e "${GREEN}Generating HTML report...${NC}"
genhtml coverage/lcov.info -o coverage/html

echo -e "${GREEN}Cleaning up...${NC}"
# Optionally remove generated files if they are very large,
# but usually lcov.info is small enough to keep.

echo -e "${GREEN}Coverage report generated at: coverage/html/index.html${NC}"
