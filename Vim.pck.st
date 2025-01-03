'From Cuis7.3 [latest update: #6961] on 3 January 2025 at 8:25:34 am'!
'Description '!
!provides: 'Vim' 1 128!
SystemOrganization addCategory: #Vim!


!classDefinition: #Vim category: #Vim!
Object subclass: #Vim
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Vim'!
!classDefinition: 'Vim class' category: #Vim!
Vim class
	instanceVariableNames: ''!


!Vim commentStamp: 'RMV 1/1/2025 20:19:13' prior: 0!
This class only exists to call the `InnerTextMorph` class method `initialize`
when the Vim package is loaded by evaluating `Feature require: Vim`.!

!Vim class methodsFor: 'as yet unclassified' stamp: 'RMV 1/1/2025 20:18:15'!
initialize
	
	InnerTextMorph initialize! !

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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/3/2025 08:21:15'!
drawOn: aCanvas
	"Draw the receiver on a canvas"
	| lineWidth x |

	false ifTrue: [ self debugDrawLineRectsOn: aCanvas ].  "show line rects for debugging"

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
					color: Theme current textEmptyDisplayMessage ]].
	
	lineWidth := 5.
	x := extent x - lineWidth.
	aCanvas line: x @ 0 to: x @ extent y width: lineWidth color: self modeColor.
	
! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:32:35'!
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
	vimMode := #insert.! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/3/2025 08:23:00'!
modeColor

	^ vimMode caseOf: {
		[#command] -> [Color red].
		[#insert] -> [Color transparent].
		[#visual] -> [Color blue].
		[#visualLine] -> [Color purple]
	} otherwise: [Color gray]! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:22:07'!
pendingChangeTo: aBoolean
	
	pendingChangeTo := aBoolean! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:22:12'!
pendingDeleteTo: aBoolean
	
	pendingDeleteTo := aBoolean! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:22:18'!
pendingFind: aBoolean
	
	pendingFind := aBoolean! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:22:24'!
pendingReplace: aBoolean
	
	pendingReplace := aBoolean! !

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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:42:28'!
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
		].
		[pendingDeleteTo] -> [
			editor deleteToCharacter: char event: evt.
			pendingDeleteTo := false.
		].
		[pendingFind] -> [
			editor moveToCharacter: char event: evt.
			pendingFind := false.
		].
		[pendingReplace] -> [
			editor replaceCharacter: char event: evt.
			pendingReplace := false.
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
					vimCount = nil or: [char = $G] ::
						ifTrue: [
							newMode := editor perform: message with: evt
						]
						ifFalse: [
							vimCount timesRepeat: [ newMode := editor perform: message with: evt ].
						].
					
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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:30:30'!
vimCommand
	
	^ vimCommand! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:30:34'!
vimCommand: aString
	
	vimCommand := aString
! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:30:25'!
vimCount
	
	^ vimCount! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:30:41'!
vimCount: aNumber
	
	vimCount := aNumber! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:30:45'!
vimMode
	
	^ vimMode! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 1/2/2025 18:30:52'!
vimMode: aSymbol
	
	vimMode := aSymbol.
	self redrawNeeded.! !

!InnerTextMorph class methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:52:10'!
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
		#da -> #noop:.
		#di -> #noop:.

		"Delete a word under cursor."
		#daw -> #deleteAWord:.
		
		"Delete line under cursor."
		#dd -> #deleteCursorLine:.
		
		"Delete inner word under cursor."
		#diw -> #deleteInnerWord:.
		
		"Delete to a given character."
		#dt -> #deleteToCharacter:.
	
		"Delete word under cursor."
		#dw -> #deleteEndOfWord:.

		"Delete word under cursor."
		'd$' asSymbol -> #deleteCursorToEndOfLine:.

		"Find a given character."
		#f -> #findCharacter:.
		
		#g -> #noop:.
		
		"Scroll to bottom."
		#G -> #cursorToLine:.
		
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

		"Replace character at cursor."
		#r -> #replaceCharacter:.
		
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
		
		"Yank (copy) current word."
		#yw -> #copyCursorWord:.
	
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

!TextComposition methodsFor: '*Vim' stamp: 'RMV 1/3/2025 08:22:32'!
displayTextCursorAtX: x top: top bottom: bottom emphasis: emphasis on: aCanvas textLeft: textLeft
	"x, top, bottom, textLeft are relative to the morph currently being drawn."
	| textCursorColor x1 isBold isItalic x0 h w halfW r d extraW corner origin |
	
	isBold := emphasis allMask: 1.
	isItalic := emphasis allMask: 2.
	
	"textCursorColor := Theme current textCursor."
	textCursorColor := editor morph modeColor.
	textCursorColor = Color transparent ifTrue: [textCursorColor := Color black].
	
	h := bottom - top.
	w := isBold
		ifTrue: [ h // 25 + 2 ]
		ifFalse: [ h // 30 + 1 ].
	halfW := w // 2.
	isItalic
		ifTrue: [	
			"Keep tweaking if needed!! For italics with descenders (i.e. p), cursor shows a bit to the left..."
			d := isBold ifTrue: [ h // 8 ] ifFalse: [ h // 9].
			x0 := x- (h*5//24) + d.
			x1 := x + d ]
		ifFalse: [
			x0 := x - halfW.
			x1 := x - halfW].
	x0-textLeft < -1 ifTrue: [
		x1 := x1 - x0 + textLeft.
		x0 := textLeft ].
	r := extentForComposing x-halfW-1.
	r < (x1-textLeft) ifTrue: [
		x0 := x0 + r - x1+textLeft.
		x1 := r +textLeft].
	extraW := isBold
		ifTrue: [ 3 ]
		ifFalse: [ 2 ].
	origin := x0-halfW@ top.
	corner := x1+halfW+extraW @ (bottom+2).
	lastTextCursorRect
		ifNil: [ lastTextCursorRect := origin corner: corner ]
		ifNotNil: [lastTextCursorRect
			setOrigin: (lastTextCursorRect origin min: origin)
			corner: (lastTextCursorRect corner max: corner)].

	aCanvas
		line: x0+halfW@(bottom-w-w+halfW) to: x1+halfW@top
		width: w + 1
		color: textCursorColor! !

!TextComposition methodsFor: '*Vim' stamp: 'RMV 12/31/2024 16:36:12'!
selectionStopIndex

	^ selectionStopBlock stringIndex.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:20:49'!
moveCursor: directionBlock forward: forward event: aKeyboardEvent
	"Private - Move cursor.
	directionBlock is a one argument Block that computes the new Position from a given one.
	This method was modified to take the Vim mode into account."
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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:47:19'!
append: evt
	"Move right one character and enter insert mode."
	
	self moveRight: evt.
	^ #insert.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:47:36'!
appendEndOfLine: evt
	"Move to end of current line and enter insert mode."
	
	self cursorEnd: evt.
	self reset.
	^ #insert.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/3/2025 06:31:01'!
beginningOfWord
	"Answer index of the start of the word under the cursor."
	| character index stopIndex text |
	
	index := pointBlock stringIndex - 1.
	stopIndex := pointBlock textLine first.
	text := self text.
	
	[
		character := text at: index.
		(character isAlphaNumeric or: [ character = $_]) and: [ index > stopIndex ]
	] whileTrue: [ index := index - 1 ].

	index > stopIndex ifTrue: [index := index + 1].
	
	^ index.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:48:05'!
changeCursorToEndOfLine: evt
	"Delete from cursor to end of line and enter insert mode."
		
	self deleteCursorToEndOfLine: evt.
	self reset.
	^ #insert.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/3/2025 06:18:19'!
changeCursorWord: evt
	"Delete from cursor to end of word under cursor and enter insert mode."
	| startIndex stopIndex |
		
	startIndex := self pointBlock stringIndex.
	stopIndex := self endOfWord..
	self selectFrom: startIndex to: stopIndex.
	self cut.

	^ #insert.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:19:07'!
changeToCharacter: evt
	
	morph pendingChangeTo: true! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:30:36'!
changeToCharacter: aCharacter event: evt
	"Change text from cursor to next occurrence of aCharacter in the current line and enter insert mode."
	| index |
	
	index := self indexOfNext: aCharacter.
	index > 0 ifTrue: [
		self selectFrom: self pointBlock stringIndex to: index - 1.
		self cut.
		morph vimMode: #insert.
	].
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:04:53'!
copyCursorLine: evt
	"Copy line containing cursor."
	| index |

	index := self pointBlock stringIndex.
	
	self selectLineWithEnding.
	self copySelection.
	self deselect.
	
	"Restore cursor position."
	self moveCursor: [:position | index] forward: false event: evt.
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:04:34'!
copyCursorWord: evt
	"Copy remainder of word containing cursor."
	| range startIndex stopIndex |
	
	startIndex := self pointBlock stringIndex.
	range := self wordRangeIncluding: startIndex.
	stopIndex := range last.
	self selectFrom: startIndex to: stopIndex.
	self copySelection.
	self moveCursor: [:position | startIndex] forward: false event: evt.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:58:36'!
copySelection: evt
	"Copy selection, if any."
	
	self hasSelection ifTrue: [
		| index |
		index := markBlock stringIndex.
		self copySelection.
		self deselectAndPlaceCursorAt: index.
		morph vimMode: #command.
		self reset.
	]
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:06:31'!
cursorBeginningOfLine: evt
	"Move cursor to beginning of line."

	self moveCursor: [:position | self beginningOfLine: position] forward: false event: evt.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:06:36'!
cursorEndOfLine: evt
	"Move cursor to end of line."

	self moveCursor: [:position | self endOfLine: position] forward: true event: evt.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:06:40'!
cursorFirstLine: evt
	"Move cursor to the beginning of the first line."
	
	self defaultFont logAs: 'defaultFont'.
	self moveCursor: [:position | 0] forward: false event: evt.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:06:45'!
cursorFirstNonBlankOfLine: evt
	"Move cursor to the first non-blank character in the current line."
	| character currentIndex index space stopIndex tab text |
	
	"editor pointBlock returns a CharacterBlock object."
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
	self moveCursor: [:position | index] forward: (index > currentIndex) event: evt.
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:06:54'!
cursorNextWord: evt
	"Move cursor to beginning of the next word."
	| atLastWordInLine |
	
	self moveCursor: [:position | self nextWordStart: position] forward: true event: evt.
	
	atLastWordInLine := pointBlock stringIndex = pointBlock textLine last.
	atLastWordInLine ifTrue: [
		"Do it again to move to the first word on the next line."
		self moveCursor: [:position | self nextWordStart: position] forward: true event: evt.
	].
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:07:31'!
cursorPreviousWord: evt
	"Move cursor to the beginning of the previous word."
	| atLastWordInLine |
	
	self moveCursor: [:position | self previousWordStart: position] forward: false event: evt.
	
	atLastWordInLine := pointBlock stringIndex = pointBlock textLine last.
	atLastWordInLine ifTrue: [
		"Do it again to move to the last word on the previous line."
		self moveCursor: [:position | self previousWordStart: position] forward: false event: evt.
	].	
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:27:18'!
cursorToLine: evt
	"Move cursor to given line or the last line."
	| lineNumber size |
	
	"If there is a count, go to that line."
	lineNumber := morph vimCount.
	lineNumber logAs: 'lineNumber'.
	lineNumber
		ifNil: [
			size := morph model actualContents size.
			self moveCursor: [:position | size] forward: false event: evt.
			self cursorBeginningOfLine: evt.
		]
		ifNotNil: [
			| column index line lines lineSize |

			lines := textComposition lines.
			line := lines at: (lineNumber min: lines size).
			lineSize := line last - line first.
			column := pointBlock stringIndex - pointBlock textLine first.
			index := line first + (column min: lineSize).
			self moveCursor: [:position | index] forward: true event: evt.
		].
	
	self reset.
	
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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/3/2025 06:49:13'!
deleteAWord: evt
	"Delete the word containing the cursor."
	| atEndOfLine startIndex stopIndex text |
	
	startIndex := self beginningOfWord.
	stopIndex := self endOfWord.
	stopIndex logAs: 'stopIndex'.
	
	text := pointBlock text.
	atEndOfLine := stopIndex = text size or: [ text at: stopIndex + 1 :: isLineSeparator].

	startIndex > 1 and: [(text at: startIndex - 1) = Character space] ::
		ifTrue: [ startIndex := startIndex - 1]
		ifFalse: [
			stopIndex < text size and: [(text at: stopIndex + 1) = Character space] ::
				ifTrue: [ stopIndex := stopIndex + 1 ]
		].

	self selectFrom: startIndex to: stopIndex.
	self cut.

	atEndOfLine
		ifTrue: [
			self moveCursor: [:position | startIndex - 1] forward: false event: evt.
		]
		ifFalse: [
			startIndex > 1 ifTrue: [
				self moveCursor: [:position | startIndex + 1] forward: false event: evt.
			]
		].
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:50:56'!
deleteCursorLine: evt
	"Delete the line containing the cursor."
	| first last textLine |
	
	"editor pointBlock returns a CharacterBlock object."
	textLine := self pointBlock textLine.
	first := textLine first.
	last := textLine last.
	self selectFrom: first to: last.
	self cut.
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 16:52:31'!
deleteCursorToEndOfLine: evt
	"Delete from the cursor to the end of the current line."
	| index last |
	
	index := pointBlock stringIndex.
	last := pointBlock textLine last.
	(self text at: last) isLineSeparator ifTrue: [ last := last - 1 ].
	self selectFrom: index to: last.
	self cut.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/3/2025 06:27:23'!
deleteEndOfWord: evt
	"Delete the end of the word containing the cursor."
	| atEndOfLine startIndex stopIndex text |
	
	startIndex := self pointBlock stringIndex.
	stopIndex := self endOfWord..
	text := self text.
	atEndOfLine := stopIndex = text size or: [ text at: stopIndex + 1 :: isLineSeparator].
	atEndOfLine ifFalse: [ stopIndex := stopIndex + 1 ].
	self selectFrom: startIndex to: stopIndex.
	self cut.
	atEndOfLine ifTrue: [ self moveCursor: [:position | startIndex - 1] forward: false event: evt].
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/3/2025 06:21:27'!
deleteInnerWord: evt
	"Delete the word containing the cursor."
	| startIndex stopIndex |
	
	startIndex := self beginningOfWord.
	stopIndex := self endOfWord.
	self selectFrom: startIndex to: stopIndex.
	self cut.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:52:17'!
deleteSelection: evt
	"Delete the selected text or character at the cursor."	
	| startIndex stopIndex |
	
	startIndex := markBlock stringIndex.
	stopIndex := pointBlock stringIndex - 1.
	startIndex > stopIndex ifTrue: [ self selectFrom: startIndex to: startIndex ].
	self cut.
	self reset.
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:19:17'!
deleteToCharacter: evt
	
	morph pendingDeleteTo: true! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:31:13'!
deleteToCharacter: aCharacter event: evt
	"Delete the text from the cursor to next occurrence of aCharacter in the current line."
	| index |
	
	index := self indexOfNext: aCharacter.
	index > 0 ifTrue: [
		self selectFrom: self pointBlock stringIndex to: index - 1.
		self cut.
	].
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:55:15'!
deselect
	"Deselect the current selection, if any."
	
	markBlock := pointBlock.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/3/2025 06:10:22'!
endOfWord
	"Answer index of the end of the word under the cursor."
	| character index stopIndex text |
	
	index := pointBlock stringIndex + 1.
	stopIndex := pointBlock textLine last.
	text := self text.
	
	[
		character := text at: index.
		(character isAlphaNumeric or: [ character = $_]) and: [ index < stopIndex ]
	] whileTrue: [ index := index + 1 ].
	
	^ index - 1.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:18:51'!
findCharacter: evt
	
	morph pendingFind: true! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:56:02'!
indexOfNext: aCharacter
	"Answer the index of next occurrence of aCharacter in the current line."
	| offset startIndex stopIndex substring |
	
	"Get the characters from the cursor position to the end of the current line."
	startIndex := pointBlock stringIndex + 1.
	stopIndex := pointBlock textLine last.
	substring := pointBlock text string copyFrom: startIndex to: stopIndex.

	offset := substring findString: aCharacter asString.
	offset > 0 ifTrue: [^ startIndex + offset - 1] ifFalse: [^ 0].
	! !

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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:57:05'!
insertAtBeginningOfLine: evt
	"Move cursor to the beginning of the line and enter insert mode."

	self cursorHome: evt.
	self reset.
	^ #insert.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:57:16'!
insertAtCursor: evt
	"Enter insert mode."
	
	self reset.
	^ #insert.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:57:36'!
joinLines: evt
	"Join the next line to the current line with a space between them."
	| index |
	
	index := self pointBlock textLine last.
	self selectFrom: index to: index.
	self replaceSelectionWith: ' '.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:00:36'!
moveDown: evt
	"Move the cursor down one line in the same column."
	
	self cursorDown: evt.
	self morph vimMode = #visualLine ifTrue: [ self selectLineWithEnding ].	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:00:13'!
moveLeft: evt
	"Move the cursor left one character."
	
	self cursorLeft: evt.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:00:00'!
moveRight: evt
	"Move the cursor right one character."
	
	self cursorRight: evt.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:31:31'!
moveToCharacter: aCharacter event: evt
	"Move cursor to the next occurrence of aCharacter in the current line."
	| index |
	
	index := self indexOfNext: aCharacter.
	index > 0 ifTrue: [
		self moveCursor: [:position | index] forward: true event: evt
	].
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:07:38'!
moveUp: evt
	"Move the cursor up one line in the same column."
	
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
		self moveCursor: [:position | savedIndex] forward: false event: evt.
	]."
	
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:45:02'!
noop: evt
	"Continue gathering command characters."! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:00:53'!
openLineAbove: evt
	"Open a new line above the line containing the cursor."
	
	self cursorUp: evt.
	self cursorEnd: evt.
	self replaceSelectionWith: (Character newLineCharacter asString).
	self reset.
	^ #insert.
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:01:01'!
openLineBelow: evt
	"Open a new line below the line containing the cursor."
	
	self cursorEnd: evt.
	self replaceSelectionWith: (Character newLineCharacter asString).
	self reset.
	^ #insert.
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/2/2025 19:16:22'!
pasteAtCursor: evt
	"Paste the clipboard contents at the cursor location."
	| endsWithNewline text |
	
	text := self clipboardStringOrText.
	endsWithNewline := text isEmpty not and: [text last isLineSeparator].

	"When the selection ends in a newline character, assume we are pasting whole lines." 	
	endsWithNewline
		ifTrue: [
			self moveDown: evt.
			self cursorBeginningOfLine: evt.
			self paste.
			self moveUp: evt.
		]
		ifFalse: [
			self cursorRight: evt.
			self paste.
		].

	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:21:22'!
replaceCharacter: evt
	
	morph pendingReplace: true! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:34:16'!
replaceCharacter: aCharacter event: evt
	"Insert aCharacter at cursor location."
	| index |
	
	index := pointBlock stringIndex.
	index logAs: 'index'.
	aCharacter logAs: 'aCharacter'.
	
	self selectFrom: index to: index.
	self replaceSelectionWith: aCharacter asString.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:02:56'!
reset
	"Reset instance variables related to Vim mode in the associated InnerTextMorph instance."
	
	morph reset! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:03:19'!
selectLineWithEnding
	"Make the receiver's selection, encompass the current line including the line ending character."
	| interval |
	
	interval := model actualContents encompassLine: self selectionInterval.
	
	"Add one to end of interval to include line ending character."
	interval setFrom: interval first to: interval last + 1 count: interval size + 1.
	
	self selectInterval: interval! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 18:46:00'!
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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:05:14'!
undoLastAction: evt
	"Undo the last change."
	
	self undo.
	self reset.! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:05:40'!
visualLineMode: evt
	"Switch to visual line mode for selecting text by entire lines."
	
	"Select the current line."
	self selectLineWithEnding.
	
	self reset.
	^ #visualLine
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 1/1/2025 19:09:18'!
visualMode: evt
	"Switch to visual mode for selecting text by characters."
	| index |
	
	"Select charater at cursor."
	index := self pointBlock stringIndex.
	self selectFrom: index to: index.
	
	self reset.
	^ #visual! !
Vim initialize!
