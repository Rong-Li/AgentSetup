# AGENTS.md

Guidance for AI coding agents working in this repository.

## Overview

One short paragraph: what this repo does and its main components.

## Setup and commands

- Install: `uv sync`
- Test: `uv run pytest`
- Single test: `uv run pytest path/to/test_file.py::test_name`
- Lint and format: `uv run ruff check . && uv run ruff format .`
- Run locally: `<command>`

## Structure

- `src/<pkg>/`: ...
- `tests/`: ...

## Conventions

- ...

## Boundaries

- Don't edit generated files in `<...>`.
- Ask before changing CI config, database migrations, or dependency versions.
