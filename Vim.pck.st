'From Cuis7.3 [latest update: #6895] on 29 December 2024 at 6:08:43 am'!
'Description '!
!provides: 'Vim' 1 53!
SystemOrganization addCategory: #Vim!



!Object methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:00:25'!
logAs: aString
    "Writes logging information about receiver to the Transcript."
    | message sender template |

    sender := thisContext sender.
    template := 'In {1}, {2} is a {3} = {4}'.
    message := template format: {sender. aString. self class name. self}.
    message print.! !

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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/29/2024 06:08:01'!
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
					vimMode := #command.
					'Vim mode is {1}.' format: { vimMode} :: print.	
					"TODO: I think we don't need the next two lines because
					we want the escape key to be specific to Vim handling.
					action := self escAction.
					action ifNotNil: [ ^action value ]"
				]
				ifFalse: [
					self handleInteraction: [ editor processKeystrokeEvent: evt ].	
				].
			
			(owner is: #ScrollPane) ifTrue: [
				owner scrollSelectionIntoView ].
			
			"Only accept (on any) if we have unaccepted edits, otherwise the morph will flash."
			(hasUnacceptedEdits and: [ acceptOn == #any ]) ifTrue: [ self acceptContents ].
		]
		ifFalse: [
			self processVimKeystrokeEvent: evt.
			evt wasHandled ifTrue: [
				"The next two lines were copied from handleInteraction:."
				self selectionChanged.
				self updateFromTextComposition.
			].
		].

! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 13:35:16'!
processVimKeystrokeEvent: evt
	"Handle Vim keystrokes (called by processKeystrokeEvent:)"
	| char key mapping newMode value |
	
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
				vimCommand := vimCommand, char asString.
				vimCommand asSymbol.
			].
			
			mapping := VimMappings at: key ifAbsent: nil.
			mapping
				ifNil: [
					"Got invalid key sequence, so clear count and command."
					vimCount := nil.
					vimCommand := ''.
				]
				ifNotNil: [
					mapping isBlock ifTrue: [
						vimCount ifNil: [ vimCount := 1 ].
						vimCount timesRepeat: [ newMode := mapping value: evt value: editor ].
						newMode isSymbol ifTrue: [
							vimMode := newMode.
							'Vim mode is {1}.' format: { vimMode} :: print.
						].
					]
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

!InnerTextMorph class methodsFor: '*Vim' stamp: 'RMV 12/28/2024 13:21:12'!
initialize
	"Every time this is modified, evaluate the following: InnerTextMorph initialize"
	| moveDown moveLeft moveRight moveUp reset |
	
	"Reset all the Vim-related instance variables."
	reset := [ :editor |	
		| innerTextMorph |
		innerTextMorph := editor morph.			
		innerTextMorph vimCount: nil.
		innerTextMorph vimCommand: ''.
	].
		
	moveDown := [ :evt :editor | editor cursorDown: evt. reset value: editor ].
	moveLeft := [ :evt :editor | editor cursorLeft: evt. reset value: editor ].
	moveRight := [ :evt :editor | editor cursorRight: evt. reset value: editor ].
	moveUp := [ :evt :editor | editor cursorUp: evt. reset value: editor ].

	VimMappings := Dictionary newFrom: {
		"itm is short for InnerTextMorph."
		#a -> [ :evt :editor |
			"Move right one character and enter insert mode."
			moveRight value: evt value: editor.
			#insert
		].
		
		#A -> [ :evt :editor |
			"Move to end of line and enter insert mode."
			editor cursorEnd: evt.
			#insert
		].
	
		#b -> [ :evt :editor |
			"Move to previous word."
			editor cursorPreviousWord: evt.
			reset value: editor.
		].

		#d -> true. "continue gathering characters"

		#dd -> [ :evt :editor |
			"Delete line under cursor."
			editor deleteCursorLine: evt.
			reset value: editor.
		].
	
		#dw -> [ :evt :editor |
			"Delete word under cursor."
			editor deleteCursorWord: evt.
			reset value: editor.
		].

		#i -> [ :evt :editor |
			"Enter insert mode."
			#insert
		].

		#I -> [ :evt :editor |
			"Move to beginning of line and enter insert mode."
			editor cursorHome: evt.
			#insert
		].

		"The numbers below are key codes for the arrow keys."
		#h -> moveLeft.
		28 -> moveLeft.
		#j -> moveDown.
		31 -> moveDown.
		#k -> moveUp.
		30 -> moveUp.		
		#l -> moveRight.
		29 -> moveRight.
		
		#o -> [ :evt :editor |
			"Open new line below current line and enter insert mode."
			editor openLineBelow: evt.
			#insert. 
		].
				
		#O -> [ :evt :editor |
			"Open new line above current line and enter insert mode."
			editor openLineAbove: evt.
			#insert. 
		].

		#p -> [ :evt :editor |
			"Paste clipboard contents at cursor position."
			editor paste.
			reset value: editor.
		].

		#w -> [ :evt :editor |
			"Move to next word."
			editor cursorNextWord: evt.
			reset value: editor.
		].

		#x -> [ :evt :editor |
			"Delete character under cursor."
			editor deleteCursorCharacter: evt.
			reset value: editor.
		].

		#y -> true. "continue gathering characters"
		
		#yy -> [ :evt :editor |
			"Yank (copy) current line."
			editor copyCursorLine: evt.
			reset value: editor.
		].
	
		'0' asSymbol -> [ :evt :editor |
			"Move to start of current line."
			editor cursorBeginningOfLine: evt.
			reset value: editor.
		].

		'^' asSymbol -> [ :evt :editor |
			"Move to first non-whitespace character in current line."
			editor cursorFirstNonBlankOfLine: evt.
			reset value: editor.
		].

		'$' asSymbol -> [ :evt :editor |
			"Move to end of current line."
			editor cursorEndOfLine: evt.
			reset value: editor.
		].
	}.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:45:14'!
copyCursorLine: evt
	"Copy line containing cursor."
	| index |

	index := self pointBlock stringIndex.
	"This moves the cursor to the end of the line."
	self selectLine.
	self copySelection.
	self deselect.
	"Restore cursor position."
	self moveCursor: [ :position | index ] forward: false event: evt.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:51:35'!
cursorBeginningOfLine: evt
	"Move cursor to beginning of line."

	self moveCursor:  [ :position | self beginningOfLine: position ] forward: false event: evt.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:49:56'!
cursorEndOfLine: evt
	"Move cursor to end of line."

	self moveCursor:  [ :position | self endOfLine: position ] forward: true event: evt.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 13:12:03'!
cursorFirstNonBlankOfLine: evt
	"Move cursor to first non-blank character in line."
	| currentIndex index pointBlock space stopIndex text |

	"editor pointBlock returns a CharacterBlock object."
	pointBlock := self pointBlock.
	index := pointBlock textLine first.
	stopIndex := pointBlock textLine last.

	text := self text.
	space := Character space.
	[ (text at: index) = space and: [ index < stopIndex ] ] whileTrue: [ index := index + 1 ].
	
	currentIndex := pointBlock stringIndex.
	self moveCursor:  [ :position | index ] forward: (index > currentIndex) event: evt.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 11:24:24'!
cursorNextWord: evt
	"Move cursor to beginning of next word."

	self moveCursor:  [ :position | self nextWordStart: position ] forward: true event: evt! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 11:23:21'!
cursorPreviousWord: evt
	"Move cursor to beginning of previous word."

	self moveCursor:  [ :position | self previousWordStart: position ] forward: false event: evt! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:43:22'!
deleteCursorCharacter: evt
	"Delete character at cursor."	
	| lastIndex pointBlock startIndex |

	pointBlock := self pointBlock.
	startIndex := pointBlock stringIndex.
	lastIndex := pointBlock textLine last.
	lastIndex logAs: 'lastIndex'.
	startIndex > lastIndex ifTrue: [startIndex := startIndex - 1].
	startIndex logAs: 'startIndex'.
	self selectFrom: startIndex to: startIndex.
	"Why does the screen flash when deleting a space character and it fails to do so?"
	self cut.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 11:35:46'!
deleteCursorLine: evt
	"Delete line containing cursor."
	| textLine |

	"editor pointBlock returns a CharacterBlock object."
	textLine := self pointBlock textLine.
	self selectFrom: textLine first to: textLine last.
	self cut.
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 11:38:52'!
deleteCursorWord: evt
	"Delete word containing cursor."
	| allText atEndOfLine range startIndex stopIndex |

	"editor pointBlock returns a CharacterBlock object."
	startIndex := self pointBlock stringIndex.
	range := self wordRangeIncluding: startIndex.
	stopIndex := range last.
	allText := self text.
	atEndOfLine := allText at: stopIndex + 1 :: isLineSeparator.
	atEndOfLine ifFalse: [ stopIndex := stopIndex + 1 ].
	self selectFrom: startIndex to: stopIndex.
	self cut.! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/27/2024 18:35:58'!
moveCursor: directionBlock forward: forward event: aKeyboardEvent
	"Private - Move cursor.
	directionBlock is a one argument Block that computes the new Position from a given one."
	| char shift indices newPosition vimMode |

	char := aKeyboardEvent keyCharacter.
	shift := aKeyboardEvent notNil and: [aKeyboardEvent shiftPressed].
	indices := self
		setIndices: shift
		forward: forward.
	newPosition := directionBlock value: (indices at: #moving).

	vimMode := morph isKindOf: InnerTextMorph :: ifTrue: [ morph vimMode ] ifFalse: nil.
	shift and: [ vimMode ~= #command ] ::
		ifTrue: [
			self
				selectMark: (indices at: #fixed)
				point: newPosition - 1 ]
		ifFalse: [ self deselectAndPlaceCursorAt: newPosition ]! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:38:25'!
openLineAbove: evt
	"Open a new line above the line containing cursor."
	
	self cursorUp: evt.
	self cursorEnd: evt.
	self replaceSelectionWith: (Character newLineCharacter asString).
! !

!Editor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:38:46'!
openLineBelow: evt
	"Open a new line below the line containing cursor."
	
	self cursorEnd: evt.
	self replaceSelectionWith: (Character newLineCharacter asString).
! !

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/28/2024 08:21:15'!
deselect
	markBlock := pointBlock.! !
