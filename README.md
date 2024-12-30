# Cuis-Smalltalk-Vim

This is a package for Cuis Smalltalk that adds support for a subset of Vim
in add editable text areas.

Initially this will only support the Vim keystrokes that I use most often.
If it is missing support for Vim keystrokes that you use,
please let me know by creating an issue and I will consider adding it.

I'm not aware of any issues with using this package, but for now
only use this in fresh images that do not contain important code changes
you cannot afford to lose.

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
