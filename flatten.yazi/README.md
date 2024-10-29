# flatten.yazi

Simple plugin for recursively flattening multiple directories into one.

## Setup

Install the plugin using one of the following methods:
1. `ya pack --add rickyelopez/yazi-plugins:flatten`
1. Download the plugin some other way and copy/paste it into `~/.config/yazi/plugins/flatten.yazi`

Configure a keymap to activate the plugin:
```toml
[[manager.prepend_keymap]]
on   = [ "c", "f" ]
run  = "plugin flatten"
desc = "Flatten selected files/dirs"
```

## Usage

1. Select one or more files/directories and activate the plugin with the keybind you configured above.
1. Provide a name for the target directory. The directory will be created if it does not exist. Relative paths (i.e. `../../new-dir`) are supported.
   If you have at least one directory selected, you can omit this field (by leaving it blank and hitting enter) to flatten into the first directory you have selected
1. ????
1. profit

## Notes

The `-n` flag is used with the `mv` command, meaning that no files will be overwritten when flattening.

Any directory (other than the destination) that is empty after flattening will be removed.

If you select only files (no directories), you can use this plugin as a quick way of grouping files into new directories. You must provide a target directory name in this case.
