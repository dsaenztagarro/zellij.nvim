# zellij.nvim

Neovim plugin for seamless integration with [Zellij](https://zellij.dev/) terminal multiplexer.

## Features

- **Run commands** in new Zellij panes from Neovim
- **Open files** in separate editor panes using Zellij's built-in edit action
- **Create tabs** with optional layout files
- **Session support** for targeting specific Zellij sessions
- **Configurable defaults** for pane behavior (floating, close-on-exit, etc.)
- **Vim commands** for quick access (`:ZellijRun`, `:ZellijEdit`, `:ZellijNewTab`)

## Requirements

- Neovim 0.9+ (uses `vim.system()`)
- [Zellij](https://zellij.dev/) terminal multiplexer
- Running inside a Zellij session (or specify a target session)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'dsaenztagarro/zellij.nvim',
  config = function()
    require('zellij').setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'dsaenztagarro/zellij.nvim',
  config = function()
    require('zellij').setup()
  end,
}
```

### Manual

Clone the repository and add it to your runtime path:

```bash
git clone https://github.com/dsaenztagarro/zellij.nvim ~/.local/share/nvim/site/pack/plugins/start/zellij.nvim
```

## Configuration

Call `setup()` with your options. All options are optional and have sensible defaults:

```lua
require('zellij').setup({
  -- Shell to use for commands (default: $SHELL or /bin/sh)
  shell = '/bin/zsh',

  -- Default Zellij session to target (default: nil = current session)
  session = nil,

  -- Default pane behavior
  defaults = {
    floating = true,         -- Open panes as floating by default
    close_on_exit = false,   -- Keep pane open after command exits
    start_suspended = false, -- Don't wait for keypress before running
  },

  -- Notification preferences
  notifications = {
    enabled = true,      -- Enable notifications
    on_success = false,  -- Show notification on success (silent by default)
    on_error = true,     -- Show notification on errors
  },
})
```

### Default Configuration

If you call `setup()` without arguments, these defaults are used:

| Option | Default | Description |
|--------|---------|-------------|
| `shell` | `$SHELL` or `/bin/sh` | Shell for running commands |
| `session` | `nil` (current) | Target Zellij session |
| `defaults.floating` | `true` | Panes open as floating |
| `defaults.close_on_exit` | `false` | Panes stay open after command exits |
| `defaults.start_suspended` | `false` | Commands run immediately |
| `notifications.enabled` | `true` | Notifications are enabled |
| `notifications.on_success` | `false` | Silent on success |
| `notifications.on_error` | `true` | Show errors |

## API

### `require('zellij').new_pane(opts)`

Create a new Zellij pane. Accepts either a command string or an options table.

```lua
local zellij = require('zellij')

-- Simple usage: just a command string
zellij.new_pane('npm test')

-- Full options table
zellij.new_pane({
  cmd = 'npm test',
  floating = true,              -- Open as floating pane
  direction = 'right',          -- or 'down' (ignored if floating)
  cwd = '/path/to/project',     -- Working directory
  name = 'Tests',               -- Pane name
  close_on_exit = true,         -- Close when command exits
  start_suspended = false,      -- Wait for keypress before running
  session = 'my-session',       -- Target session (overrides config)
})
```

#### Options

| Option | Type | Description |
|--------|------|-------------|
| `cmd` | `string` | Shell command to execute |
| `floating` | `boolean` | Open as floating pane (default from config) |
| `direction` | `"right"\|"down"` | Direction for tiled pane |
| `cwd` | `string` | Working directory |
| `name` | `string` | Pane name |
| `close_on_exit` | `boolean` | Close pane when command exits |
| `start_suspended` | `boolean` | Wait for keypress before running |
| `session` | `string` | Target Zellij session |

### `require('zellij').run(cmd, opts?)`

Convenience alias for running a command in a new pane. The command is the first argument.

```lua
local zellij = require('zellij')

-- Simple
zellij.run('make build')

-- With options
zellij.run('cargo test', {
  floating = false,
  direction = 'down',
  close_on_exit = true,
})
```

### `require('zellij').edit(file, opts?)`

Open a file in a new Zellij pane using your `$EDITOR`. Uses Zellij's built-in `edit` action.

```lua
local zellij = require('zellij')

-- Open a file
zellij.edit('/path/to/file.lua')

-- Open current buffer in a floating pane
zellij.edit(vim.fn.expand('%:p'), { floating = true })

-- Open at a specific line
zellij.edit('/path/to/file.lua', { line = 42 })

-- Open in a tiled pane on the right
zellij.edit('README.md', { floating = false, direction = 'right' })
```

#### Options

| Option | Type | Description |
|--------|------|-------------|
| `floating` | `boolean` | Open as floating pane (default from config) |
| `direction` | `"right"\|"down"` | Direction for tiled pane |
| `line` | `number` | Line number to jump to |
| `cwd` | `string` | Working directory |
| `session` | `string` | Target Zellij session |

### `require('zellij').new_tab(opts?)`

Create a new Zellij tab, optionally with a layout file.

```lua
local zellij = require('zellij')

-- Create empty tab
zellij.new_tab()

-- Create tab with a layout
zellij.new_tab({ layout = '~/.config/zellij/layouts/dev.kdl' })

-- Create tab with name and working directory
zellij.new_tab({
  layout = 'dev.kdl',
  name = 'Development',
  cwd = vim.fn.getcwd(),
})
```

#### Options

| Option | Type | Description |
|--------|------|-------------|
| `layout` | `string` | Path to layout file (.kdl) |
| `layout_url` | `string` | URL to layout file (Zellij v0.41+) |
| `name` | `string` | Tab name |
| `cwd` | `string` | Working directory |
| `session` | `string` | Target Zellij session |

## Vim Commands

The plugin registers these commands when `setup()` is called:

### `:ZellijRun <command>`

Run a shell command in a new Zellij pane.

```vim
:ZellijRun npm test
:ZellijRun cargo build --release
:ZellijRun make && ./a.out
```

### `:ZellijEdit [file]`

Open a file in a new Zellij pane with your `$EDITOR`. If no file is specified, opens the current buffer's file at the current line.

```vim
:ZellijEdit                 " Opens current file at current line
:ZellijEdit %               " Opens current file
:ZellijEdit README.md       " Opens specific file
:ZellijEdit ~/.config/nvim/init.lua
```

### `:ZellijNewTab [layout]`

Create a new Zellij tab. Optionally specify a layout file.

```vim
:ZellijNewTab
:ZellijNewTab ~/.config/zellij/layouts/dev.kdl
```

## Usage Examples

### Run tests on save

```lua
vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = '*.rs',
  callback = function()
    require('zellij').run('cargo test', { close_on_exit = true })
  end,
})
```

### Keymaps for common tasks

```lua
local zellij = require('zellij')

-- Run current file
vim.keymap.set('n', '<leader>zr', function()
  zellij.run(vim.fn.expand('%:p'))
end, { desc = 'Run current file in Zellij' })

-- Edit file in floating pane
vim.keymap.set('n', '<leader>ze', function()
  zellij.edit(vim.fn.expand('%:p'), { floating = true, line = vim.fn.line('.') })
end, { desc = 'Edit in Zellij floating pane' })

-- Git status
vim.keymap.set('n', '<leader>zg', function()
  zellij.run('lazygit', { name = 'Git', floating = true })
end, { desc = 'Open lazygit in Zellij' })

-- Create development tab with layout
vim.keymap.set('n', '<leader>zt', function()
  zellij.new_tab({ layout = 'dev.kdl', name = 'Dev', cwd = vim.fn.getcwd() })
end, { desc = 'New Zellij dev tab' })
```

### Session targeting

Target a specific Zellij session (useful when running Neovim outside Zellij or controlling a remote session):

```lua
-- Configure default session
require('zellij').setup({
  session = 'main',
})

-- Or per-command
require('zellij').run('npm start', { session = 'backend' })
```

## Development

### Running Tests

```bash
make test
```

Tests use [mini.test](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) with child Neovim process isolation.

### Linting

```bash
make lint
```

### Formatting

```bash
make format
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make test`) and lint (`make lint`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.
