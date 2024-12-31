'From Cuis7.3 [latest update: #6895] on 31 December 2024 at 8:50:12 am'!
'Description '!
!provides: 'Vim' 1 80!
SystemOrganization addCategory: #Vim!



!Object methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:00:25'!
logAs: aString
    "Writes logging information about receiver to the Transcript."
    | message sender template |

    sender := thisContext sender.
    template := 'In {1}, {2} is a {3} = {4}'.
    message := template format: {sender. aString. self class name. self}.
    message print.! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/31/2024 08:36:52'!
drawOn: aCanvas
	"Draw the receiver on a canvas"
	| rect |

	false ifTrue: [ self debugDrawLineRectsOn: aCanvas ].  "show line rects for debugging"

	vimMode = #command or: [ vimMode = #visual] :: ifTrue: [
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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/31/2024 08:48:56'!
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
			vimMode = #visual and: [ evt isEsc ] ::
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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:45:50'!
processVimKeystrokeEvent: evt
	"Handle Vim keystrokes (called by processKeystrokeEvent:)"
	| char key message newMode value |
	
	char := evt keyCharacter.
	value := evt keyValue.
	"'keyCharacter = {1}, keyValue = {2}' format: { char. value } :: print."
	
	"Only add zero character to vimCount if it is already set
	in order to get values like 10 or 20."
	char isDigit and: [ char ~= $0 or: [ vimCount notNil ] ] ::
		ifTrue: [
			vimCount
				ifNil: [ vimCount := char digitValue ]
				ifNotNil: [ vimCount := vimCount asString, char asString :: asNumber ].
		]
		ifFalse: [
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

!InnerTextMorph class methodsFor: '*Vim' stamp: 'RMV 12/31/2024 08:50:02'!
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

		"Change word under cursor."
		#cw -> #changeCursorWord:.

		"Change characters from cursor to end of line."
		'c$' asSymbol -> #changeCursorToEndOfLine:.

		#d -> #noop:.

		"Delete line under cursor."
		#dd -> #deleteCursorLine:.
	
		"Delete word under cursor."
		#dw -> #deleteCursorWord:.

		#g -> #noop.
		
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

		"Move to next word."
		#w -> #cursorNextWord:.

		"Delete character under cursor."
		#x -> #deleteCursorCharacter:.

		#y -> #noop:.
		
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

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:32:01'!
copyCursorLine: evt
	"Copy line containing cursor."
	| index |

	index := self pointBlock stringIndex.
	"This moves the cursor to the end of the line."
	"TODO: This is not including the newline at the end, but needs to!!"
	self selectLine.
	self copySelection.
	self deselect.
	"Restore cursor position."
	self moveCursor: [ :position | index ] forward: false event: evt.
	self reset.! !

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

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:30:39'!
cursorNextWord: evt
	"Move cursor to beginning of next word."

	self moveCursor:  [ :position | self nextWordStart: position ] forward: true event: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:12:39'!
cursorPreviousWord: evt
	"Move cursor to beginning of previous word."

	self moveCursor:  [ :position | self previousWordStart: position ] forward: false event: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:31:42'!
deleteCursorCharacter: evt
	"Delete character at cursor."	
	| lastIndex pointBlock startIndex |

	pointBlock := self pointBlock.
	startIndex := pointBlock stringIndex.
	lastIndex := pointBlock textLine last.
	startIndex > lastIndex ifTrue: [startIndex := startIndex - 1].
	self selectFrom: startIndex to: startIndex.
	self cut.
	self reset.
! !

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

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 08:43:52'!
moveCursor: directionBlock forward: forward event: aKeyboardEvent
	"Private - Move cursor.
	directionBlock is a one argument Block that computes the new Position from a given one."
	| char selecting shiftPressed indices newPosition vimMode |

	char := aKeyboardEvent keyCharacter.
	shiftPressed := aKeyboardEvent notNil and: [aKeyboardEvent shiftPressed].
	selecting := shiftPressed or: [ morph vimMode = #visual ].
	indices := self
		setIndices: selecting
		forward: forward.
	newPosition := directionBlock value: (indices at: #moving).

	vimMode := morph isKindOf: InnerTextMorph :: ifTrue: [ morph vimMode ] ifFalse: nil.
	selecting and: [ vimMode ~= #command ] ::
		ifTrue: [
			self
				selectMark: (indices at: #fixed)
				point: newPosition - 1 ]
		ifFalse: [ self deselectAndPlaceCursorAt: newPosition ]! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 05:59:52'!
moveDown: evt
	self cursorDown: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:06:19'!
moveLeft: evt
	self cursorLeft: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:00:18'!
moveRight: evt
	self cursorRight: evt.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:00:25'!
moveUp: evt
	self cursorUp: evt.
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

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 06:26:15'!
pasteAtCursor: evt
	"Paste clipboard contents at cursor location."
	
	"TODO: Fix this to only move down if clipboard contents ends in a newline."
	self cursorDown: evt.
	self paste.
	self reset.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/31/2024 05:58:16'!
reset
	| innerTextMorph |
	innerTextMorph := self morph.			
	innerTextMorph vimCount: nil.
	innerTextMorph vimCommand: ''.! !

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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/29/2024 06:37:04'!
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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/29/2024 19:34:10'!
initialize
	emphasisHere := #().
	initialSelectionStart := nil.
	initialSelectionStop := nil.
	doWordSelection := false.
	doParagraphSelection := false.
	"defaultFont := nil."
	"TODO: Why does this affect Text Editor and Workspace windows, but not Browser code panes?"
	defaultFont := FontFamily familyName: 'JetBrains Mono NL' pointSize: 14.! !
