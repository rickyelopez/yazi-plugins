--- @class NodeInfo
--- @field url Url
--- @field cha Cha
local NodeInfo = {}

--- Helper function to send an error notification with the given content
---@param content string
local notify_error = function(content)
  ya.notify({
    title = "Flatten",
    content = content,
    level = "error",
    timeout = 5,
  })
end

--- Helper function to send a warn notification with the given content
---@param content string
local notify_warn = function(content)
  ya.notify({
    title = "Flatten",
    content = content,
    level = "warn",
    timeout = 5,
  })
end

--- Get sorted list of URLs of selected files/dirs
--- @return Urls[]
local get_selected = ya.sync(function()
  local tab = cx.active
  local selected = {}

  for _, url in pairs(tab.selected) do
    selected[#selected + 1] = url
  end

  table.sort(selected, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return selected
end)

--- Process a destination dir and list of URLs, and return a table of {url, cha} for each.
--- Also choose a destination dir if none was provided by the user
--- @param dest string | NodeInfo
--- @param urls Url[]
--- @return NodeInfo | nil
--- @return table | string | nil
local process_urls = function(dest, urls)
  local sources = {}

  --- @type NodeInfo | nil
  local dest_ret = type(dest) == "table" and dest or nil

  for _, url in ipairs(urls) do
    local cha, err = fs.cha(url)
    if cha == nil then
      notify_error("Failed to produce a cha from one of the selected files/dirs")
      return nil, err
    end

    -- use the first directory we find as the destination if a target dir name was not provided by the user
    if dest_ret == nil and cha.is_dir then
      dest_ret = {
        url = url,
        cha = cha,
      }
    else
      table.insert(sources, { url = url, cha = cha })
    end
  end

  if dest_ret == nil then
    notify_warn("Flatten target dir was left empty but no directories were selected")
    return nil, nil
  end

  return dest_ret, sources
end

--- Create the destination directory if it does not exist. Returns `nil` on success, or the error otherwise
---@param dest string
---@return NodeInfo | string
local create_dest = function(dest)
  local output, err = Command("mkdir"):arg("-p"):arg("./" .. dest):stdout(Command.PIPED):stderr(Command.PIPED):output()

  if not output or not output.status or not output.status.success then
    notify_error(
      string.format(
        "Flattening selected dirs failed with exit code: '%s'\n stdout: %s\n stderr: %s",
        output.status and output.status.code or err,
        output.stdout,
        output.stderr
      )
    )
    return err
  end

  local dest_url = Url("./" .. dest)
  local dest_cha
  dest_cha, err = fs.cha(dest_url)
  if dest_cha == nil then
    notify_error("Failed to build a cha from the given target directory name")
    return err
  end

  return {
    url = dest_url,
    cha = dest_cha,
  }
end

--- Delete the given dir if it is empty. Returns `nil` on success, or the error otherwise
---@param dir table
---@return nil | string
local rm_if_empty = function(dir)
  local ok, err = fs.remove("dir_clean", dir.url)
  if not ok then
    notify_error(string.format("Failed to delete source directory with error code '%s'", err))
    return err
  end
  return nil
end

--- Move all files in the given dir to the given dest, making recursive calls to itself for any subdirs.
--- Returns `nil` on success, or the error otherwise
--- Errors if recursion depth exceeds 10
---@param dest table
---@param source table
---@param recursion_depth integer
---@return nil | string
RecursiveMove = function(dest, source, recursion_depth)
  if recursion_depth > 10 then
    notify_error("Max recursion depth reached, not going any deeper")
    return nil
  end

  if source.cha.is_dir then
    local contents, err = fs.read_dir(source.url, {})

    if contents == nil then
      notify_error(string.format("Error reading directory '%s': $s", tostring(source.url), err))
      return err
    end

    for _, entry in ipairs(contents) do
      local res = RecursiveMove(dest, { url = entry.url, cha = entry.cha }, recursion_depth + 1)
      if res ~= nil then
        return res
      end
    end

    return rm_if_empty(source)
  end

  ya.dbg(string.format("moving '%s' to '%s'", tostring(source.url), tostring(dest.url)))
  local output, err = Command("mv")
    :arg("-n")
    :arg(tostring(source.url))
    :arg(tostring(dest.url))
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :output()

  if not output or not output.status or not output.status.success then
    local error_string = string.format(
      "Flattening selected dirs failed with exit code: '%s'\n stdout: %s\n stderr: %s",
      output.status and output.status.code or err,
      output.stdout,
      output.stderr
    )
    notify_error(error_string)
    ya.err(error_string)
    return err
  end

  return nil
end

return {
  entry = function()
    -- exit visual selection mode
    ya.manager_emit("escape", { visual = true })

    -- get the target directory name from the user
    local dest, event = ya.input({
      title = "Flattened dir name (leave blank to flatten into first selected dir):",
      position = { "top-center", y = 3, w = 40 },
    })

    -- user aborted instead of prividing directory name
    if event ~= 1 then
      return
    end

    -- user provided a dest dir name
    if dest ~= "" then
      dest = create_dest(dest)
      if type(dest) ~= "table" then
        return
      end
    end

    local selected_items = get_selected()

    if #selected_items < 2 then
      notify_warn("Must select at least two files/dirs in order to flatten!")
      return
    end

    dest, selected_items = process_urls(dest, selected_items)
    -- error happened when processing urls
    if dest == nil then
      return
    end

    for _, source in ipairs(selected_items) do
      if RecursiveMove(dest, source, 0) ~= nil then
        return
      end
    end

    -- deselect all
    ya.manager_emit("select_all", { state = "false" })
  end,
}
