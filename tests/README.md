# Testing Guide

This directory contains unit tests for remember.nvim.

## Prerequisites

You need to have `luarocks` installed to run the tests. Install it using your package manager:

```bash
# On Ubuntu/Debian
sudo apt-get install luarocks

# On macOS
brew install luarocks

# On Arch Linux
sudo pacman -S luarocks
```

## Installing Test Dependencies

Install the `busted` testing framework and `luacov` for coverage:

```bash
make test-install
# or manually:
luarocks install busted --local
luarocks install luacov --local
```

## Running Tests

Run all tests:

```bash
make test
# or directly:
busted tests/
```

Run tests with coverage report:

```bash
make test-coverage
```

Run tests with verbose output:

```bash
busted tests/ --verbose
```

Run a specific test file:

```bash
busted tests/remember_spec.lua
```

## Coverage Reports

Coverage reports are generated using [luacov](https://github.com/lunarmodules/luacov). After running `make test-coverage`, you'll find:

- `luacov.report.out` - Human-readable coverage report
- `luacov.stats.out` - Raw coverage statistics

The coverage configuration is in `.luacov` and is set to only include `lua/` directory files.

## Test Structure

- `tests/remember_spec.lua` - Main test file containing unit tests for:
  - `setup()` function - configuration options
  - `set_cursor_position()` function - cursor restoration logic
  - autocmd registration

## Writing New Tests

Tests are written using the [busted](https://olivinelabs.com/busted/) testing framework. The test file mocks the Neovim API to allow unit testing without running Neovim.

Example test structure:

```lua
describe("feature name", function()
  it("should do something", function()
    -- Test code here
    assert.is_true(condition)
  end)
end)
```

## Cleaning Up

Remove test artifacts:

```bash
make clean
```

## CI/CD

Tests are automatically run on pull requests via GitHub Actions. The workflow:
- Runs all tests
- Generates coverage report
- Posts coverage results as a PR comment
