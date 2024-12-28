'From Cuis7.3 [latest update: #6895] on 28 December 2024 at 12:52:26 pm'!
'Description '!
!provides: 'Vim' 1 46!
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

!VimEditor methodsFor: 'as yet unclassified' stamp: 'RMV 12/28/2024 11:44:32'!
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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:47:28'!
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
			evt isEsc ifTrue: [	
				vimMode := #command.
				'Vim mode is {1}.' format: { vimMode} :: print.
				evt wasHandled: true.	
				"TODO: Do we need the next two lines?
				Probably not because we want the escape key to be specific to Vim handling.
				action := self escAction.
				action ifNotNil: [ ^action value ]"
			].
			
			self handleInteraction: [ editor processKeystrokeEvent: evt ].	
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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 11:32:42'!
processVimKeystrokeEvent: evt
	"Handle Vim keystrokes (called by processKeystrokeEvent:)"
	| char key mapping newMode value |
	
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
						vimCount timesRepeat: [ newMode := mapping value: evt value: self ].
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

!InnerTextMorph class methodsFor: '*Vim' stamp: 'RMV 12/28/2024 12:52:06'!
initialize
	"Every time this is modified, evaluate the following: InnerTextMorph initialize"
	| moveDown moveLeft moveRight moveUp reset |
	
	"Reset all the Vim-related instance variables."
	reset := [ :itm |					
		itm vimCount: nil.
		itm vimCommand: ''.
	].
		
	moveDown := [ :evt :itm | itm editor cursorDown: evt. reset value: itm ].
	moveLeft := [ :evt :itm | itm editor cursorLeft: evt. reset value: itm ].
	moveRight := [ :evt :itm | itm editor cursorRight: evt. reset value: itm ].
	moveUp := [ :evt :itm | itm editor cursorUp: evt. reset value: itm ].

	VimMappings := Dictionary newFrom: {
		"itm is short for InnerTextMorph."
		#a -> [ :evt :itm |
			"Move right one character and enter insert mode."
			moveRight value: evt value: itm.
			#insert
		].
		#A -> [ :evt :itm |
			"Move to end of line and enter insert mode."
			itm editor cursorEnd: evt.
			#insert
		].
	
		#b -> [ :evt :itm |
			"Move to previous word."
			itm editor cursorPreviousWord: evt.
			reset value: itm.
		].

		#d -> true.

		#dd -> [ :evt :itm |
			"Delete line under cursor."
			itm editor deleteCursorLine: evt.
			reset value: itm.
		].
	
		#dw -> [ :evt :itm |
			"Delete word under cursor."
			itm editor deleteCursorWord: evt.
			reset value: itm.
		].

		#i -> [ :evt :itm |
			"Enter insert mode."
			#insert
		].

		#I -> [ :evt :itm |
			"Move to beginning of line and enter insert mode."
			itm editor cursorHome: evt. #insert
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
		
		#o -> [ :evt :itm |
			"Open new line below current line and enter insert mode."
			itm editor openLineBelow: evt.
			#insert. 
		].
				
		#O -> [ :evt :itm |
			"Open new line above current line and enter insert mode."
			itm editor openLineAbove: evt.
			#insert. 
		].

		#p -> [ :evt :itm |
			itm editor paste.
			reset value: itm.
		].

		#w -> [ :evt :itm |
			"Move to next word."
			itm editor cursorNextWord: evt.
			reset value: itm.
		].

		#x -> [ :evt :itm |
			"Delete character under cursor."
			itm editor deleteCursorCharacter: evt.
			reset value: itm.
		].

		#y -> true.
		
		#yy -> [ :evt :itm |
			"Yank (copy) current line."
			itm editor copyCursorLine: evt.
			reset value: itm.
		].
	
		'0' asSymbol -> [ :evt :itm |
			"Move to start of current line."
			itm editor cursorBeginningOfLine: evt.
			reset value: itm.
		].

		'^' asSymbol -> [ :evt :itm |
			"Move to first non-whitespace character in current line."
			itm editor cursorHome: evt.
			reset value: itm.
		].

		'$' asSymbol -> [ :evt :itm |
			"Move to end of current line."
			itm editor cursorEndOfLine: evt.
			reset value: itm.
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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/27/2024 08:52:30'!
textComposition
	"This instance variable is not exposed in the base image."

	^ textComposition! !
