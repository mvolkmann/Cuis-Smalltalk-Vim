'From Cuis7.3 [latest update: #6895] on 27 December 2024 at 1:36:09 pm'!
'Description '!
!provides: 'Vim' 1 19!
SystemOrganization addCategory: #Vim!


!classDefinition: #VimEditor category: #Vim!
SystemWindow subclass: #VimEditor
	instanceVariableNames: 'mode textModelMorph'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Vim'!
!classDefinition: 'VimEditor class' category: #Vim!
VimEditor class
	instanceVariableNames: ''!


!VimEditor commentStamp: 'RMV 12/27/2024 08:55:46' prior: 0!
I probably do not want to keep this class.
All its functionality was moved to InnerTextMorph.!

!VimEditor methodsFor: 'as yet unclassified' stamp: 'RMV 12/27/2024 08:13:27'!
initialize
	| contents editor font labelMorph textComposition textModel |
	
	super initialize.
	
	"Should you use Preferences instead? That seems to only support known keys."
	Smalltalk at: #useVim put: true.

	mode := #command.
	self setLabel: 'Vim Editor'.
	
	labelMorph := LabelMorph new contents: 'Edit text below.'; color: Color green.

	contents := 'first line
second line
third line'.
	textModel := TextModel withText: contents.
	textModelMorph := TextModelMorph withModel: textModel.
	textModelMorph layoutSpec offAxisEdgeWeight: 0.

	"TODO: The font name must be wrong here."
	font := FontFamily familyName: 'JetBrains Mono NL' pointSize: 24.
	"font := FontFamily familyName: 'Alex Brush' pointSize: 24."
	editor := textModelMorph editor.
	editor defaultFont: font.
	textComposition := editor textComposition.
	
	"This block is called AFTER regular processing!!
	We need to run this block BEFORE regular processing
	and only run regular processing if a Vim key is not pressed.
	See InnerTextMorph method processKeystrokeEvent:."
	textModelMorph keystrokeAction: [ :keyboardEvent |
		self processKeystrokeEvent: keyboardEvent forEditor: editor
	].

	layoutMorph addMorph: labelMorph.
	layoutMorph addMorph: textModelMorph proportionalWidth: 1.
	
	! !

!VimEditor methodsFor: 'as yet unclassified' stamp: 'RMV 12/27/2024 08:13:11'!
processKeystrokeEvent: evt forEditor: editor
	| char columnNumber handled line lines lineNumber pointBlock textComposition value |
	
	evt logAs: 'evt'.
	textComposition := editor textComposition.

	"See the TextEditor method sameColumn:newLine:forward:."
	pointBlock := editor pointBlock.
	columnNumber := pointBlock stringIndex - pointBlock textLine first. 6 .
	lines := textComposition lines.
	"lineCount := textComposition numberOfLines."
	lineNumber  := textComposition lineIndexFor: (pointBlock stringIndex).
	line := lines at: lineNumber.
	columnNumber := pointBlock stringIndex - line first.
	"self halt."

	char := evt keyCharacter.
	value := evt keyValue.
	value logAs: 'value'.
	'keyCharacter = {1}, keyValue = {2}' format: { char. value } print.
	'isEsc = {1}' format: { evt isEsc } print.
	
	handled := true. "assume for now"
	mode = #command
		ifTrue: [
			true caseOf: {
				[char = $a] -> [ mode := #append ].
				[char = $A] -> [ mode := #append ].
				[char = $i] -> [ mode := #insert ].
				[char = $I] -> [ mode := #insert ].
				[char = $h] -> [ editor cursorLeft: evt ].
				[char = $j] -> [ editor cursorDown: evt ].
				[char = $k] -> [ editor cursorUp: evt ].
				[char = $l] -> [ editor cursorRight: evt ]
			} otherwise: [ handled := false ]
		]
		ifFalse: [
			evt isEsc
				ifTrue: [
					mode := #command.
					evt wasHandled: true.
				]
				ifFalse: [ handled := false ]
		].

	self setLabel: 'Vim Editor - ', mode, ' mode'.
	evt wasHandled: handled.	
	! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 13:35:13'!
processKeystrokeEvent: evt
	"This method was modified from the version in the base image."
	| action |
	
	"This block of code was added to support Vim keystrokes."
	self processVimKeystrokeEvent: evt.
	evt wasHandled ifTrue: [
		"The next two lines were copied from handleInteraction:."
		self selectionChanged.
		self updateFromTextComposition.
		^ nil "Don't run the rest of the code in this method."
	].

	(acceptOn = #enter and: [evt isReturnKey]) ifTrue: [^ self acceptContents].

	self pauseBlinking.
	
	"Return - check for special action"
	evt isReturnKey ifTrue: [	
		action := self crAction.
		action ifNotNil: [ ^action value ] ].
	
	"Esc - check for special action"
	evt isEsc ifTrue: [			
		action := self escAction.
		action ifNotNil: [ ^action value ] ].
	
	self handleInteraction: [ editor processKeystrokeEvent: evt ].	
	(owner is: #ScrollPane) ifTrue: [
		owner scrollSelectionIntoView ].

	"Only accept (on any) if we have unaccepted edits, otherwise the morph will flash."
	(hasUnacceptedEdits and: [ acceptOn == #any ]) ifTrue: [ self acceptContents ].! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 13:35:46'!
processVimKeystrokeEvent: evt
	"Handle Vim keystrokes (called by processKeystrokeEvent:)"
	| block char handled newMode value |
	
	"See the TextEditor method sameColumn:newLine:forward:."
	"pointBlock := editor pointBlock.
	columnNumber := pointBlock stringIndex - pointBlock textLine first. 6 .
	lines := textComposition lines.
	lineCount := textComposition numberOfLines.
	lineNumber  := textComposition lineIndexFor: (pointBlock stringIndex).
	line := lines at: lineNumber.
	columnNumber := pointBlock stringIndex - line first."

	char := evt keyCharacter.
	value := evt keyValue.
	"'keyCharacter = {1}, keyValue = {2}' format: { char. value } print."
	
	handled := true. "assume for now"

	vimMode = #command
		ifTrue: [
			block := VimMappings at: char ifAbsent: nil.
			block ifNotNil: [
				newMode := block value: evt value: editor.
				newMode isSymbol ifTrue: [
					vimMode := newMode.
					'Vim mode is {1}.' format: { vimMode} :: print.
				].
			].
		]
		ifFalse: [
			evt isEsc
				ifTrue: [
					vimMode := #command.
					'Vim mode is {1}.' format: { vimMode} :: print.
				]
				ifFalse: [ handled := false ]
		].

	evt wasHandled: handled.	
	! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/27/2024 13:34:32'!
moveCursor: directionBlock forward: forward event: aKeyboardEvent
	"Private - Move cursor.
	directionBlock is a one argument Block that computes the new Position from a given one."
	| char shift indices newPosition vimKey |

	char := aKeyboardEvent keyCharacter.
	"This Vim keys require the shift key, but we don't to select text when they are used."
	vimKey := char = $^ or: [char = $$].
	shift := aKeyboardEvent notNil and: [aKeyboardEvent shiftPressed].
	indices := self
		setIndices: shift
		forward: forward.
	newPosition := directionBlock value: (indices at: #moving).
	shift and: [vimKey not] ::
		ifTrue: [
			self
				selectMark: (indices at: #fixed)
				point: newPosition - 1 ]
		ifFalse: [ self deselectAndPlaceCursorAt: newPosition ]! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/27/2024 08:52:30'!
textComposition
	"This instance variable is not exposed in the base image."

	^ textComposition! !
