# Cuis-Smalltalk-Vim

This is a package for Cuis Smalltalk that adds support for a subset of Vim
in al editable text areas.

Currently only the Vim commands that I use most often are supported.
If it is missing support for Vim commands that you use,
please let me know by creating an issue and I will consider adding them.

Currently this package has only been tested in macOS, but I don't
foresee any differences when running in Linux or Windows.

To install this, clone the repository and
evaluate `Feature require: 'Vim'` in a Workspace.
This will enable use of Vim commands in all instances of `InnerTextMorph`
which seems to include all places where text can be entered and edited
in the development environment.

Please report any problems you encounter with this package
or feature requests by creating issues in this GitHub repository.

## Vim Modes

The initial Vim mode in each text area is "insert". You should not
experience any differences in functionality while in this mode.

To switch to "command" mode, press the escape key.
When in "command" mode, the text cursor changes to red.
Also, a red border is drawn on the right edge of the text area
to remind you that you are in command mode.

To switch to "visual" mode where text can be selected
by simply moving the cursor, press the "v" key.
A blue border will be drawn on the right edge of the text area
to remind you that you are in visual mode.

To switch to "visualLine" mode where complete lines of text can be selected
by simply moving the cursor down or up, press the "V" key.
A purple border will be drawn on the right edge of the text area
to remind you that you are in visualLine mode.

## New Classes

This package adds the class `Vim` whose only purpose is
to invoke the `InnerTextMorph` class method `initialize`
when the `Vim` package is installed.
This happens in its class method `initialize`.

## Modifications to Provided Classes

This package makes the following modifications to
classes that are provided in the base Cuis image.

### Editor

The `moveCursor:forward:event:` method was modified
to consider the current Vim mode when deciding whether
moving the cursor should change the current text selection.

### InnerTextMorph

New instance variables `vimCommand`, `vimCount`, and`vimMode`
were added to the class definition. 
TODO: How does the file `Vim.pck.st` know about this?

The class method `initialize` was added.
This sets the class variable `VimMappings` to a `Dictionary`
that maps symbols representing keyboard sequences to
messages that are sent to instances of the `TextEditor` class
to process Vim commands.
Browse this method to see all the Vim commands
that are currently supported.

The `drawOn:` method was modified to draw a right border
whose color indicates the current Vim mode.
It is red for command mode, blue for visual mode,
and purple for visualLine mode.
No right border is drawn when in insert mode.

The `initialize` method was modified to initialize the
new instance variables `vimCommand`, `vimCount`, and `vimMode`.

The `processKeystrokeEvent:` method was modified
to consider the current Vim mode.
When in insert mode, the only change is to comment out the handling of
the escape key, which is necessary to allow the escape key
to trigger switching from insert mode to command mode.
When not in insert mode, this method now performs Vim-specific processing.

The following new instance methods were added:
`modeColor`, `pendingChangeTo:`, `pendingDeleteTo:`, `pendingFind:`,
`pendingReplace:`, `processVimKeystrokeEvent:`, `vimCommand`, `vimCommand:`,
`vimCount`, `vimCount:`, `vimMode`, `vimMode:`, and `vimReset`.

### TextComposition

The `displayTextCursorAtX:top:bottom:emphasis:on:textLeft:` method
was modified to set the color of the text cursor
based on the current Vim mode.
It also makes the text cursor bold when not in insert mode.

### TextEditor

The method category `*Vim` was added, along with 49 methods
that implement the currently supported subset of Vim commands.

Also, the `cut` method provided in the base Cuis image was modified.
The `lineSelectAndEmptyCheck:` message send was commented out because
it breaks the ability to delete an empty line using the Vim `dd` command.

