# shortcuts - a command line interface to your text replacements on macOS

This simple utility allows you to view, update, create and delete text substitutions used in Cocoa-based applications.

> NOTE: beware that if you use iCloud to sync your text substitutions they will be screwed up eventually (because that's how good iCloud sync is). But at least you may use this tool to make and restore backups 🎉.

Since it's built on top of private API from InputMethodKit.framework I'm not sure what macOS versions are supported, but it works fine for me on 10.11.6 `¯\_(ツ)_/¯` 


## Installation

I'm working on adding shortcuts to Homebrew so it can be installed without a hassle ([#4](https://github.com/rodionovd/shortcuts/issues/4)); until then you need to open the Xcode project and build the utility yourself, then copy it into /usr/local/bin or any other suitable location.

## Usage

### Listing all text replacements

```bash
$ shortcuts list [--as-plist]
```

You can specify `--as-plist` modifier to generate a property list file suitable for dragging into Keyboard Preferences Pane (see [How to export and import text substitutions in OS X](https://support.apple.com/en-au/HT204006) for details). 

### Importing new entries 

You can import new text replacement entries either from a property list (see above)

```bash
shortcuts import [--force] /path/to/input.plist
```

or manully like this


```bash
shortcuts new [--force] <shortcut> <phrase>
```

The default conflict resolution strategy is that the existing entries will not be overwritten with those from the input file/command line. You should use the `--force` flag to update existing entries (i.e. for the same `<shortcut>`).


### Updating shortcuts

As simple as

```bash
shortcuts update <shortcut> <phrase>
```

Currently this command is an alias for the `new --force` command.

### Deleting shortcuts

```bash
shortcuts delete <shortcut>
```

Well that's it.

------

Made by [Internals Exposed](http://internals.exposed) @ 2016.
