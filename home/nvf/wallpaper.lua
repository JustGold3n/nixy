-- Suzuha atomically replaces this palette. Read it at startup and while the
-- editor is open, including when the file first appears after Neovim starts.
local path = vim.env.HOME .. "/.local/state/amane/nvim-palette.lua"
local uv = vim.uv or vim.loop
local last_palette
local current
local applying = false
local group = vim.api.nvim_create_augroup("WallpaperTheme", { clear = true })

local function color(value)
  return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function accents()
  -- Brighten muted text without turning the same palette's surfaces white.
  -- Also cover the fallback theme before Suzuha exports its first palette.
  local palette = current and current.palette
    or require("catppuccin.palettes").get_palette()
  local muted = {}
  for _, name in ipairs({ "subtext0", "subtext1", "overlay0", "overlay1", "overlay2",
      "surface0", "surface1", "surface2" }) do
    if palette[name] then muted[tonumber(palette[name]:sub(2), 16)] = true end
  end
  for name, highlight in pairs(vim.api.nvim_get_hl(0, {})) do
    if muted[highlight.fg] then
      highlight.fg = 0xffffff
      vim.api.nvim_set_hl(0, name, highlight)
    end
  end
  -- Mini Statusline links filenames to StatusLineNC by default. Resolve that
  -- link and pin only the text color, retaining the theme's background.
  for _, name in ipairs({ "MiniStatuslineFilename", "MiniStatuslineInactive" }) do
    local highlight = vim.api.nvim_get_hl(0, { name = name, link = false })
    highlight.fg = 0xffffff
    vim.api.nvim_set_hl(0, name, highlight)
  end
  if not current then return end
  local accent = current.ui.accent
  for _, name in ipairs({ "MiniStarterHeader", "SnacksPickerTitle" }) do
    vim.api.nvim_set_hl(0, name, { fg = accent, bold = true })
  end
  vim.api.nvim_set_hl(0, "SnacksPickerBorder", { fg = accent })
  vim.api.nvim_set_hl(0, "Cursor", { bg = accent, fg = current.ui.on_accent })
  vim.api.nvim_set_hl(0, "lCursor", { link = "Cursor" })
end

local function apply()
  if applying then return end
  local file = io.open(path, "r")
  if not file then return end
  local text = file:read("*a")
  file:close()
  if text == last_palette then return end

  -- The export is a literal Lua table; it needs no access to editor or OS APIs.
  local chunk = loadstring(text, "@" .. path)
  if not chunk then return end
  setfenv(chunk, {})
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= "table" or type(data.palette) ~= "table"
      or type(data.ui) ~= "table" or type(data.light) ~= "boolean" then return end
  for _, key in ipairs({ "base", "mantle", "text", "mauve", "blue", "green", "red" }) do
    if not color(data.palette[key]) then return end
  end
  for _, value in pairs(data.palette) do
    if not color(value) then return end
  end
  for _, key in ipairs({ "accent", "on_accent", "segment", "text" }) do
    if not color(data.ui[key]) then return end
  end

  local found, catppuccin = pcall(require, "catppuccin")
  if not found then return end
  applying = true
  local success, err = pcall(function()
    local flavour = data.light and "latte" or "mocha"
    local options = vim.deepcopy(catppuccin.options)
    options.flavour = flavour
    options.color_overrides = { [flavour] = data.palette }
    catppuccin.setup(options)
    current = data
    vim.o.background = data.light and "light" or "dark"
    vim.cmd.colorscheme("catppuccin-" .. flavour)
    accents()

    -- Refresh the status line from the same palette, preserving its layout.
    local has_lualine, lualine = pcall(require, "lualine")
    if has_lualine then
      local config = lualine.get_config()
      local function sections(accent)
        return {
          a = { fg = data.ui.on_accent, bg = accent, gui = "bold" },
          b = { fg = data.ui.text, bg = data.ui.segment },
          c = { fg = data.ui.text, bg = data.palette.base },
        }
      end
      config.options.theme = {
        normal = sections(data.ui.accent), insert = sections(data.palette.green),
        visual = sections(data.palette.mauve), replace = sections(data.palette.red),
        command = sections(data.palette.yellow), inactive = sections(data.ui.segment),
      }
      lualine.setup(config)
    end
    last_palette = text
    vim.g.wallpaper_theme_accent = data.ui.accent
  end)
  applying = false
  if not success then
    vim.notify("Wallpaper theme: " .. tostring(err), vim.log.levels.WARN)
  end
end

vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = accents })
vim.api.nvim_create_autocmd({ "FocusGained", "VimEnter" }, { group = group, callback = apply })
local timer = uv.new_timer()
timer:start(1000, 1000, vim.schedule_wrap(apply))
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group, once = true,
  callback = function() timer:stop(); timer:close() end,
})
apply()
accents()
