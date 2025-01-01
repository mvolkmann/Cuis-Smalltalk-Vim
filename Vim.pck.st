'From Cuis7.3 [latest update: #6961] on 1 January 2025 at 11:12:40 am'!
'Description '!
!provides: 'Vim' 1 103!
SystemOrganization addCategory: #Vim!



!Object methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:00:25'!
logAs: aString
    "Writes logging information about receiver to the Transcript."
    | message sender template |

    sender := thisContext sender.
    template := 'In {1}, {2} is a {3} = {4}'.
    message := template format: {sender. aString. self class name. self}.
    message print.! !

!CharacterBlock methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:32:05'!
text
	"I added this because it is needed by the Vim package."
	^ text.! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/31/2024 15:54:07'!
drawOn: aCanvas
	"Draw the receiver on a canvas"
	| rect |

	false ifTrue: [ self debugDrawLineRectsOn: aCanvas ].  "show line rects for debugging"

	vimMode = #insert ifFalse: [
		rect := Rectangle origin: 0@0 extent: extent.
		aCanvas fillRectangle: rect color: (Color pink alpha: 0.1).
	].
	
	aCanvas
		drawTextComposition: self textComposition
		at: `0@0`
		extent: extent
		color: color
		selectionColor: (Theme current textHighlightFocused: self hasKeyboardFocus).

	model actualContents isEmpty ifTrue: [
		owner
			valueOfProperty: #emptyTextDisplayMessage
			ifPresentDo: [ :msg |
				aCanvas
					drawString: msg
					at: `0@0`
					font: nil
					color: Theme current textEmptyDisplayMessage ]].! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 07:23:20'!
initialize
	super initialize.
	wrapFlag := true.
	acceptOn := #none.
	hasUnacceptedEdits := false.
	hasEditingConflicts := false.
	askBeforeDiscardingEdits := true.
	needsFit := false.

	vimCommand := ''.
	vimCount := nil.
	vimMode := #insert.
! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:08:39'!
pendingChangeTo: aBoolean
	pendingChangeTo := aBoolean! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:08:30'!
pendingDeleteTo: aBoolean
	pendingDeleteTo := aBoolean! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:08:55'!
pendingFind: aBoolean
	pendingFind := aBoolean! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/31/2024 15:56:22'!
processKeystrokeEvent: evt
	"This method was modified from the version in the base image to support Vim commands."
	| action |
	
	vimMode = #insert
		ifTrue: [
			(acceptOn = #enter and: [evt isReturnKey]) ifTrue: [^ self acceptContents].
			
			self pauseBlinking.
			
			"Return - check for special action"
			evt isReturnKey ifTrue: [	
				action := self crAction.
				action ifNotNil: [ ^action value ] ].
			
			"Esc - check for special action"
			evt isEsc
				ifTrue: [	
					self vimMode: #command.
					'Vim mode is {1}.' format: { vimMode} :: print.	
					"TODO: I think we don't need the next two lines because
					we want the escape key to be specific to Vim handling.
					action := self escAction.
					action ifNotNil: [ ^action value ]"
				]
				ifFalse: [
					self handleInteraction: [ editor processKeystrokeEvent: evt ].	
				].
						
			"Only accept (on any) if we have unaccepted edits, otherwise the morph will flash."
			(hasUnacceptedEdits and: [ acceptOn == #any ]) ifTrue: [ self acceptContents ].
		]
		ifFalse: [
			evt isEsc and: [vimMode = #visual or: [vimMode = #visualLine]] ::
				ifTrue: [
					editor deselectAndPlaceCursorAt: (editor pointBlock stringIndex).
					vimMode := #command
				]
				ifFalse: [
					self processVimKeystrokeEvent: evt.
					evt wasHandled ifTrue: [
						"The next two lines were copied from handleInteraction:."
						self selectionChanged.
						self updateFromTextComposition.
					]
				]
		].
		
	(owner is: #ScrollPane) ifTrue: [ owner scrollSelectionIntoView ].

! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 11:00:42'!
processVimKeystrokeEvent: evt
	"Handle Vim keystrokes (called by processKeystrokeEvent:)"
	| char key message newMode value |
	
	char := evt keyCharacter.
	value := evt keyValue.
	"'keyCharacter = {1}, keyValue = {2}' format: { char. value } :: print."
	
	true caseOf: {
		[pendingChangeTo] -> [
			editor changeToCharacter: char event: evt.
			pendingChangeTo := false.
			self reset.
		].
		[pendingDeleteTo] -> [
			editor deleteToCharacter: char event: evt.
			pendingDeleteTo := false.
			self reset.
		].
		[pendingFind] -> [
			editor moveToCharacter: char event: evt.
			pendingFind := false.
			self reset.
		].
		[char isDigit and: [char ~= $0 or: [vimCount notNil]]] -> [
			"Only add zero character to vimCount if it is already set
			in order to get values like 10 or 20."
			vimCount
				ifNil: [ vimCount := char digitValue ]
				ifNotNil: [ vimCount := vimCount asString, char asString :: asNumber ].
		]
	} otherwise: [
			key := value < 32 ifTrue: value ifFalse: [
				"TODO: How does vimCommand ever get set to nil?"
				vimCommand := vimCommand ifNil: [ char asString ] ifNotNil: [ vimCommand, char asString ].
				vimCommand asSymbol.
			].
			
			message := VimMappings at: key ifAbsent: nil.
			message
				ifNil: [
					"Got invalid key sequence, so clear count and command."
					vimCount := nil.
					vimCommand := ''.
				]
				ifNotNil: [
					vimCount ifNil: [ vimCount := 1 ].
					vimCount timesRepeat: [ newMode := editor perform: message with: evt ].
					newMode isSymbol ifTrue: [
						self vimMode:​ newMode.
						'Vim mode is {1}.' format: { vimMode} :: print.
					].
				].
	].

	evt wasHandled: true.	
! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:19:33'!
reset

	vimCount := nil.
	vimCommand := ''.! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 06:46:30'!
vimCommand
	^ vimCommand! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 06:46:56'!
vimCommand: aString
	vimCommand := aString! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 19:19:54'!
vimCount: aNumber
	vimCount := aNumber! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 18:30:14'!
vimMode
	^ vimMode! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/29/2024 16:10:22'!
vimMode: aSymbol
	vimMode := aSymbol.
	self redrawNeeded.! !

!InnerTextMorph class methodsFor: '*Vim' stamp: 'RMV 1/1/2025 11:02:51'!
initialize
	"Every time this is modified, evaluate the following: InnerTextMorph initialize"
		
	VimMappings := Dictionary newFrom: {
		"Move right one character and enter insert mode."
		#a -> #append:.
		
		"Move to end of line and enter insert mode."
		#A -> #appendEndOfLine:.
	
		"Move to previous word."
		#b -> #cursorPreviousWord:.

		#c -> #noop:.

		"Change to a given character."
		#ct -> #changeToCharacter:.
	
		"Change word under cursor."
		#cw -> #changeCursorWord:.

		"Change characters from cursor to end of line."
		'c$' asSymbol -> #changeCursorToEndOfLine:.

		#d -> #noop:.

		"Delete line under cursor."
		#dd -> #deleteCursorLine:.
		
		"Delete to a given character."
		#dt -> #deleteToCharacter:.
	
		"Delete word under cursor."
		#dw -> #deleteCursorWord:.

		"Delete word under cursor."
		'd$' asSymbol -> #deleteCursorToEndOfLine:.

		"Find a given character."
		#f -> #findCharacter:.
		
		#g -> #noop:.
		
		"Scroll to bottom."
		#G -> #cursorLastLine:.
		
		"Scroll to top."
		#gg -> #cursorFirstLine:.

		"Enter insert mode."
		#i -> #insertAtCursor:.
		
		"Move to beginning of line and enter insert mode."
		#I -> #insertAtBeginningOfLine:.

		"The numbers below are key codes for the arrow keys."
		#h -> #moveLeft:.
		28 -> #moveLeft:.
		#j -> #moveDown:.
		31 -> #moveDown:.
		#k -> #moveUp:.
		30 -> #moveUp:.		
		#l -> #moveRight:.
		29 -> #moveRight:.

		"Join next line to current line."
		#J -> #joinLines:.
		
		"Open new line below current line and enter insert mode."
		#o -> #openLineBelow:.
				
		"Open new line above current line and enter insert mode."
		#O -> #openLineAbove:.

		"Paste clipboard contents at cursor position."
		#p -> #pasteAtCursor:.

		"Undo last action."
		#u -> #undoLastAction:.
		
		"Enter visual mode."
		#v -> #visualMode:.

		"Enter visual line mode."
		#V -> #visualLineMode:.

		"Move to next word."
		#w -> #cursorNextWord:.

		"Delete character under cursor."
		#x -> #deleteSelection:.

		#y -> #copySelection:.
		
		"Yank (copy) current line."
		#yy -> #copyCursorLine:.
	
		"Move to start of current line."
		'0' asSymbol -> #cursorBeginningOfLine:.

		"Move to first non-whitespace character in current line."
		'^' asSymbol -> #cursorFirstNonBlankOfLine:.

		"Move to end of current line."
		'$' asSymbol -> #cursorEndOfLine:.

		"Change the case of the current character or selected characters."
		#~ -> #toggleCase:.
	}.
! !

!TextComposition methodsFor: '*Vim' stamp: 'RMV 12/31/2024 16:36:12'!
selectionStopIndex

	^ selectionStopBlock stringIndex.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:09:50'!
append: evt
	self moveRight: evt.
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:11:11'!
appendEndOfLine: evt
	self cursorEnd: evt.
	self reset.
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:16:07'!
changeCursorToEndOfLine: evt
	"Change line containing cursor."
	
	self deleteCursorToEndOfLine: evt.
	self reset.
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:18:56'!
changeCursorWord: evt
	"Change word containing cursor."
	
	self deleteCursorWord: evt. "sends reset"
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:09:26'!
changeToCharacter: evt
	
	morph pendingChangeTo: true! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:59:26'!
changeToCharacter: aCharacter event: evt
	"Change text from cursor to next occurrence of aCharacter in the current line."
	| index |
	
	index := self indexOfNext: aCharacter.
	index > 0 ifTrue: [
		self selectFrom: self pointBlock stringIndex to: index - 1.
		self cut.
		morph vimMode: #insert.
	].! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:01:15'!
copyCursorLine: evt
	"Copy line containing cursor."
	| index |

	index := self pointBlock stringIndex.
	
	self selectLineWithEnding.
	self copySelection.
	self deselect.
	
	"Restore cursor position."
	self moveCursor: [ :position | index ] forward: false event: evt.
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 09:18:02'!
copySelection: evt
	"Copy selection if any."
	
	self hasSelection ifTrue: [
		| index |
		index := self markBlock stringIndex.
		index logAs: 'index'.
		self copySelection.
		self deselectAndPlaceCursorAt: index.
		morph vimMode: #command.
		self reset.
	]
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:32:42'!
cursorBeginningOfLine: evt
	"Move cursor to beginning of line."

	self moveCursor:  [ :position | self beginningOfLine: position ] forward: false event: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:34:00'!
cursorEndOfLine: evt
	"Move cursor to end of line."

	self moveCursor:  [ :position | self endOfLine: position ] forward: true event: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:20:03'!
cursorFirstLine: evt
	"Move cursor to first line."

	self defaultFont logAs: 'defaultFont'.
	self moveCursor:  [ :position | 0 ] forward: false event: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:33:16'!
cursorFirstNonBlankOfLine: evt
	"Move cursor to first non-blank character in line."
	| character currentIndex index pointBlock space stopIndex tab text |

	"editor pointBlock returns a CharacterBlock object."
	pointBlock := self pointBlock.
	index := pointBlock textLine first.
	stopIndex := pointBlock textLine last.

	text := self text.
	space := Character space.
	tab := Character tab.
	[
		character := text at: index.
		(character = space or: [ character = tab]) and: [ index < stopIndex ]
	] whileTrue: [ index := index + 1 ].
	
	currentIndex := pointBlock stringIndex.
	self moveCursor:  [ :position | index ] forward: (index > currentIndex) event: evt.
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:19:37'!
cursorLastLine: evt
	"Move cursor to last line."
	| size |
	size := morph model actualContents size.
	size logAs: 'size'.
	self moveCursor:  [ :position | size ] forward: false event: evt.
	self cursorBeginningOfLine: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 15:25:43'!
cursorNextWord: evt
	"Move cursor to beginning of next word."
	| atLastWordInLine pointBlock |

	self moveCursor:  [ :position | self nextWordStart: position] forward: true event: evt.
	
	pointBlock := self pointBlock.
	atLastWordInLine := pointBlock stringIndex = pointBlock textLine last.
	atLastWordInLine ifTrue: [
		"Do it again to move to the first word on the next line."
		self moveCursor:  [ :position | self nextWordStart: position] forward: true event: evt.
	].
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 15:28:06'!
cursorPreviousWord: evt
	"Move cursor to beginning of previous word."
	| atLastWordInLine pointBlock |

	self moveCursor:  [ :position | self previousWordStart: position ] forward: false event: evt.
	
	pointBlock := self pointBlock.
	atLastWordInLine := pointBlock stringIndex = pointBlock textLine last.
	atLastWordInLine ifTrue: [
		"Do it again to move to the last word on the previous line."
		self moveCursor:  [ :position | self previousWordStart: position] forward: false event: evt.
	].	
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:16:55'!
deleteCursorLine: evt
	"Delete line containing cursor."
	| first last textLine |

	"editor pointBlock returns a CharacterBlock object."
	textLine := self pointBlock textLine.
	first := textLine first.
	last := textLine last.
	self selectFrom: first to: last.
	self cut.
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:10:18'!
deleteCursorToEndOfLine: evt
	"Delete from cursor to end of line."
	| index last pointBlock |

	"editor pointBlock returns a CharacterBlock object."
	pointBlock := self pointBlock.
	index := pointBlock stringIndex.
	last := pointBlock textLine last.
	self text logAs: 'text'.
	(self text at: last) asciiValue :: logAs: 'last character'.
	(self text at: last) isLineSeparator :: logAs: 'isLineSeparator'.
	(self text at: last) isLineSeparator ifTrue: [ last := last - 1 ].
	self selectFrom: index to: last.
	self cut.
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:18:21'!
deleteCursorWord: evt
	"Delete word containing cursor."
	| allText atEndOfLine range startIndex stopIndex |

	"editor pointBlock returns a CharacterBlock object."
	startIndex := self pointBlock stringIndex.
	range := self wordRangeIncluding: startIndex.
	stopIndex := range last.
	allText := self text.
	atEndOfLine := stopIndex = allText size or: [ allText at: stopIndex + 1 :: isLineSeparator].
	atEndOfLine ifFalse: [ stopIndex := stopIndex + 1 ].
	self selectFrom: startIndex to: stopIndex.
	self cut.
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 09:01:39'!
deleteSelection: evt
	"Delete selected text or character at cursor."	
	| markBlock pointBlock startIndex stopIndex |

	markBlock := self markBlock.
	startIndex := markBlock stringIndex.
	pointBlock := self pointBlock.
	stopIndex := pointBlock stringIndex - 1.
	startIndex logAs: 'startIndex'.
	stopIndex logAs: 'stopIndex'.
	startIndex > stopIndex ifTrue: [
		self selectFrom: startIndex to: startIndex.
	].
	self cut.
	self reset.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:09:13'!
deleteToCharacter: evt
	
	morph pendingDeleteTo: true! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:53:30'!
deleteToCharacter: aCharacter event: evt
	"Delete text from cursor to next occurrence of aCharacter in the current line."
	| index |
	
	index := self indexOfNext: aCharacter.
	index > 0 ifTrue: [
		self selectFrom: self pointBlock stringIndex to: index - 1.
		self cut.
	].! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:09:43'!
findCharacter: evt
	
	morph pendingFind: true! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:48:17'!
indexOfNext: aCharacter
	"Answer indes of next occurrence of aCharacter in the current line."
	| offset pointBlock startIndex stopIndex substring |
	
	"Get the characters from the cursor position to the end of the current line."
	pointBlock := self pointBlock.
	startIndex := pointBlock stringIndex + 1.
	stopIndex := pointBlock textLine last.
	substring := pointBlock text string copyFrom: startIndex to: stopIndex.

	offset := substring findString: aCharacter asString.
	offset > 0 ifTrue: [^ startIndex + offset - 1] ifFalse: [^ 0].
	! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:22:01'!
insertAtBeginningOfLine: evt
	"Move cursor to beginning of line and enter insert mode."

	self cursorHome: evt.
	self reset.
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:23:04'!
insertAtCursor: evt
	"Enter insert mode."

	self reset.
	^ #insert.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 11:12:28'!
joinLines: evt
	"Join next line to the current line."
	| index |
	
	index := self pointBlock textLine last.
	self selectFrom: index to: index.
	self replaceSelectionWith: ' '.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 11:11:47'!
moveCursor: directionBlock forward: forward event: aKeyboardEvent
	"Private - Move cursor.
	directionBlock is a one argument Block that computes the new Position from a given one."
	| selecting shiftPressed indices newPosition vimMode |

	shiftPressed := aKeyboardEvent notNil and: [aKeyboardEvent shiftPressed].
	selecting := shiftPressed or: [morph vimMode = #visual] or: [morph vimMode = #visualLine].
	indices := self
		setIndices: selecting
		forward: forward.
	newPosition := directionBlock value: (indices at: #moving).

	vimMode := morph isKindOf: InnerTextMorph :: ifTrue: [ morph vimMode ] ifFalse: nil.
	selecting and: [ vimMode ~= #command ] ::
		ifTrue: [ self selectMark: (indices at: #fixed) point: newPosition - 1 ]
		ifFalse: [ self deselectAndPlaceCursorAt: newPosition ]! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 09:37:18'!
moveDown: evt

	self cursorDown: evt.
	self morph vimMode = #visualLine ifTrue: [ self selectLineWithEnding ].	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:06:19'!
moveLeft: evt
	self cursorLeft: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:00:18'!
moveRight: evt
	self cursorRight: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:47:25'!
moveToCharacter: aCharacter event: evt
	"Move cursor to next occurrence of aCharacter in the current line."
	| index |
	
	index := self indexOfNext: aCharacter.
	index > 0 ifTrue: [
		self moveCursor: [:position | index] forward: true event: evt
	].! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 08:55:06'!
moveUp: evt
	
	"stopIndex := self markBlock textLine last.
	stopIndex logAs: 'stopIndex'."
	self cursorUp: evt.
	"self morph vimMode = #visualLine ifTrue: [ self selectLine ]."	
	"savedIndex := self pointBlock textLine first."
	
	"TODO: Why does this only work the first time?"
	"self morph vimMode = #visualLine ifTrue: [
		startIndex := self pointBlock textLine first.
		startIndex logAs: 'startIndex'.
		self selectFrom: startIndex to: stopIndex.
		self moveCursor: [ :position | savedIndex ] forward: false event: evt.
	]."
	
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:39:56'!
noop: evt
	"Continue gathering command characters."! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:24:37'!
openLineAbove: evt
	"Open a new line above the line containing cursor."
	
	self cursorUp: evt.
	self cursorEnd: evt.
	self replaceSelectionWith: (Character newLineCharacter asString).
	self reset.
	^ #insert.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:24:13'!
openLineBelow: evt
	"Open a new line below the line containing cursor."
	
	self cursorEnd: evt.
	self replaceSelectionWith: (Character newLineCharacter asString).
	self reset.
	^ #insert.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 09:59:57'!
pasteAtCursor: evt
	"Paste clipboard contents at cursor location."
	| endsWithNewline text |
	
	text := self clipboardStringOrText.
	endsWithNewline := text isEmpty not and: [text last isLineSeparator].

	"When the selection ends in a newline character, assume we are pasting whole lines." 	
	endsWithNewline ifTrue: [] ifFalse: [self cursorRight: evt].

	self paste.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 10:19:47'!
reset
	self morph reset! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 08:44:06'!
setIndices: selecting forward: forward
	"Little helper method that sets the moving and fixed indices according to some flags."
	| indices |
	indices := Dictionary new.
	(selecting and:[Preferences at: #selectionsMayShrink])
		ifTrue: [
			indices at: #moving put: self pointIndex.
			indices at: #fixed put: self markIndex
		] ifFalse: [
			forward
				ifTrue:[
					indices at: #moving put: self stopIndex.
					indices at: #fixed put: self startIndex.
				] ifFalse: [
					indices at: #moving put: self startIndex.
					indices at: #fixed put: self stopIndex.
				]
		].
	^indices! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:34:29'!
toggleCase: evt
	"Toggle the case of the character under the cursor."
	| char index |
	
	index := self pointBlock stringIndex.
	index <= self text size ifTrue: [
		char := self text at: index.
		char isAlphaNumeric ifTrue: [
			char := char isLowercase ifTrue: [ char asUppercase ] ifFalse: [ char asLowercase ].
			self clipboardTextPut: char asString.
			self selectFrom: index to: index.
			self paste.
		].
	].
	self reset.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:29:32'!
undoLastAction: evt
	self undo.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 09:52:13'!
visualLineMode: evt
	"Switch to visual line mode for selecting text."

	"Select the current line."
	self selectLineWithEnding.

	self reset.
	^ #visualLine
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 16:18:48'!
visualMode: evt
	"Switch to visual mode for selecting text."
	| index |
	
	"Select charater at cursor."
	index := self pointBlock stringIndex.
	self selectFrom: index to: index.

	self reset.
	^ #visual
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 07:32:16'!
cut
	"Cut out the current selection and redisplay if necessary."
	"This is a user command, and generates undo"
	| selection |
	
	"TODO: I commented out this line because it breaks the
	ability to delete an empty line using the Vim dd command.
	self lineSelectAndEmptyCheck: [^ self]."
	
	selection := self selection.
	self replaceSelectionWith: self nullText.
	self clipboardTextPut: selection.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 08:21:15'!
deselect
	markBlock := pointBlock.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 15:32:35'!
initialize
	emphasisHere := #().
	initialSelectionStart := nil.
	initialSelectionStop := nil.
	doWordSelection := false.
	doParagraphSelection := false.
	defaultFont := nil.
	
	"TODO: Why does this affect Text Editor and Workspace windows, but not Browser code panes?"
	"defaultFont := FontFamily familyName: 'JetBrains Mono NL' pointSize: 14."! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 08:55:09'!
markBlock
	^markBlock! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 09:50:49'!
selectLineWithEnding
	"Make the receiver's selection, encompass the current line including the line ending character."
	| interval |
	
	interval := model actualContents encompassLine: self selectionInterval.
	"Add one to end of interval to include line ending character."
	interval setFrom: interval first to: interval last + 1 count: interval size + 1.
	self selectInterval: interval! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 16:32:47'!
textComposition

	^ textComposition! !
