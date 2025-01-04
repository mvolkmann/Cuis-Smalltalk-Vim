# Cuis-Smalltalk-Vim

This is a package for Cuis Smalltalk that adds support for a subset of Vim
in add editable text areas.

Initially this will only support the Vim keystrokes that I use most often.
If it is missing support for Vim keystrokes that you use,
please let me know by creating an issue and I will consider adding it.

I'm not aware of any issues with using this package, but for now
only use this in fresh images that do not contain important code changes
you cannot afford to lose.
So far this has only been tested in macOS.

To install this, clone the repository and
evaluate `Feature require: 'Vim'` in a Workspace.
This will enable use of Vim commands in all instances of `InnerTextMorph`
which, as far as I know, includes all places where text can be entered and edited.

The initial Vim mode in each area is "insert".
To switch to "command" mode, press the escape key.
When in "command" mode, the background of the editing area
changes to a very light pink.

I modified the `TextEditor` instance method `initialize`
to set the font to "JetBrains Mono NL" which is a monospace font.
But it is not taking effect in the code panew of System Browser windows.
I need to fix that still.

Please report any problems you encounter with this packages
or feature requests by creating an issue in this GitHub repository.

## New Classes

This package adds the class `Vim` whose only purpose is to
invoke the `InnerTextMorph` class method `initialize`
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
TODO: How does the file `Vim.pck.st` know about this

The `drawOn:` method was modified to draw a right border
whose color indicates the current Vim mode.
It is red for command mode, blue for visual mode,
and purple for visualLine mode.
No right border is drawn when in insert mode.

The `initialize` method was modified to initialize
the new instance variables `vimCommand`, `vimCount`, and `vimMode`.

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
that implement the currently supported subset of Vim command.

Also, the `cut` method provided in the base Cuis image was modified.
The `lineSelectAndEmptyCheck:` message send was commented out because
it breaks the ability to delete an empty line using the Vim `dd` command
