'From Cuis7.3 [latest update: #6895] on 27 December 2024 at 6:42:26 am'!
'Description '!
!provides: 'Vim' 1 0!
SystemOrganization addCategory: 'Vim'!


!classDefinition: #VimEditor category: 'Vim'!
SystemWindow subclass: #VimEditor
	instanceVariableNames: 'mode'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Vim'!
!classDefinition: 'VimEditor class' category: 'Vim'!
VimEditor class
	instanceVariableNames: ''!


!VimEditor methodsFor: 'as yet unclassified' stamp: 'RMV 12/26/2024 19:40:22'!
initialize
	| char columnNumber contents editor font labelMorph line lineCount lines lineNumber pointBlock textComposition textModel textMorph value |
	
	super initialize.
	mode := #command.
	self setLabel: 'Vim Editor'.
	
	labelMorph := LabelMorph new contents: 'Edit text below.'; color: Color green.

	contents := 'first line
second line
third line'.
	textModel := TextModel withText: contents.
	textMorph := TextModelMorph withModel: textModel.
	textMorph layoutSpec offAxisEdgeWeight: 0.

	font := FontFamily familyName: 'JetBrains Mono ML' pointSize: 24.
	"font := FontFamily familyName: 'Alex Brush' pointSize: 24."
	editor := textMorph editor.
	editor defaultFont: font.
	textComposition := editor textComposition.
	
	"This block is called AFTER regular processing!!
	We need it to be called instead of regular processing
	and only run regular processing if a Vim key is not pressed.
	See InnerTextMorph method processKeystrokeEvent:."
	textMorph keystrokeAction: [ :keyboardEvent |
		"See the TextEditor method sameColumn:newLine:forward:."
		pointBlock := editor pointBlock.
		columnNumber := pointBlock stringIndex - pointBlock textLine first. 6 .
		lines := textComposition lines.
		lineCount := textComposition numberOfLines.
		lineNumber  := textComposition lineIndexFor: (pointBlock stringIndex).
		line := lines at: lineNumber.
		columnNumber := pointBlock stringIndex - line first.
		"self halt."

		char := keyboardEvent keyCharacter.
		value := keyboardEvent keyValue.
		value logAs: 'value'.
		'keyCharacter = {1}, keyValue = {2}' format: { char. value } print.
		'isEsc = {1}' format: { keyboardEvent isEsc } print.

		mode = #command
			ifTrue: [
				true caseOf: {
					[char = $a] -> [ mode := #append ].
					[char = $A] -> [ mode := #append ].
					[char = $i] -> [ mode := #insert ].
					[char = $I] -> [ mode := #insert ].
					[char = $h] -> [ editor cursorLeft: keyboardEvent ].
					[char = $j] -> [ editor cursorDown: keyboardEvent ].
					[char = $k] -> [ editor cursorUp: keyboardEvent ].
					[char = $l] -> [ editor cursorRight: keyboardEvent ]
				} otherwise: []. "do nothing"
			]
			ifFalse: [
				keyboardEvent isEsc
					ifTrue: [ mode := #command ]
					ifFalse: []. "key not handled"
			].

		self setLabel: 'Vim Editor - ', mode, ' mode'.
		"key was handled"	
	].

	layoutMorph addMorph: labelMorph.
	layoutMorph addMorph: textMorph proportionalWidth: 1.
	
	! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/26/2024 19:06:01'!
textComposition
	^ textComposition! !
