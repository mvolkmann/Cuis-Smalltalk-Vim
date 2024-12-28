'From Cuis7.3 [latest update: #6895] on 28 December 2024 at 6:41:53 am'!
'Description '!
!provides: 'Vim' 1 31!
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

!Object methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:00:25'!
logAs: aString
    "Writes logging information about receiver to the Transcript."
    | message sender template |

    sender := thisContext sender.
    template := 'In {1}, {2} is a {3} = {4}'.
    message := template format: {sender. aString. self class name. self}.
    message print.! !

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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/28/2024 06:40:47'!
processVimKeystrokeEvent: evt
	"Handle Vim keystrokes (called by processKeystrokeEvent:)"
	| block char handled key newMode value |
	
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
	
	handled := true. "assume for now"

	vimMode = #command
		ifTrue: [
			"Only add zero character to vimCount if it is already set
			in order to get values like 10 or 20."
			char isDigit and: [ char ~= $0 or: [ vimCount notNil ] ] ::
				ifTrue: [
					vimCount
						ifNil: [ vimCount := char digitValue ]
						ifNotNil: [ vimCount := vimCount asString, char asString :: asNumber ].
				]
				ifFalse: [
					key := value < 32 ifTrue: value ifFalse: char.
					block := VimMappings at: key ifAbsent: nil.
					block ifNotNil: [
						vimCount ifNil: [ vimCount := 1 ].
						vimCount timesRepeat: [ newMode := block value: evt value: self ].
						newMode isSymbol ifTrue: [
							vimMode := newMode.
							'Vim mode is {1}.' format: { vimMode} :: print.
						].
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

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 19:19:54'!
vimCount: aNumber
	vimCount := aNumber! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 18:30:14'!
vimMode
	^ vimMode! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:49:54'!
vimMotion
	^ vimMotion! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:51:46'!
vimMotion: aString
	vimMotion := aString! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:49:42'!
vimOperator
	^ vimOperator! !

!InnerTextMorph methodsFor: '*Vim' stamp: 'RMV 12/27/2024 14:51:34'!
vimOperator: aCharacter
	vimOperator := aCharacter! !

!InnerTextMorph class methodsFor: '*Vim' stamp: 'RMV 12/27/2024 19:29:32'!
initialize
	"Every time this is modified, evaluate the following: InnerTextMorph initialize"
	| reset |
	
	"Reset all the Vim-related instance variables."
	reset := [ :itm |					
		itm vimCount: nil.
		itm vimOperator: nil.
		itm vimMotion:​ nil.
	].
		
	VimMappings := Dictionary newFrom: {
		"itm is short for InnerTextMorph."
		$a -> [ :evt :itm | #append ].
		$A -> [ :evt :itm |
			itm editor cursorEnd: evt.
			#append
		].

		$d -> [ :evt :itm |
			itm vimOperator = $d
				ifTrue: [
					"Delete current line under cursor."
					| editor textLine |
					editor := itm editor.
					"editor pointBlock returns a CharacterBlock object."
					textLine := editor pointBlock textLine.
					editor selectFrom: textLine first to: textLine last.
					editor cut.
					reset value: itm.
				]
				ifFalse: [
					"Save the delete operator, waiting for motion."
					itm vimOperator: $d
				].
		].

		$i -> [ :evt :itm | #insert ].
		$I -> [ :evt :itm |
			itm editor cursorHome: evt.
			#insert
		].

		$h -> [ :evt :itm | itm editor cursorLeft: evt. reset value: itm ].
		28 -> [ :evt :itm | itm editor cursorLeft: evt. reset value: itm ].
		$j -> [ :evt :itm | itm editor cursorDown: evt. reset value: itm ].
		31 -> [ :evt :itm | itm editor cursorDown: evt. reset value: itm ].
		$k -> [ :evt :itm | itm editor cursorUp: evt. reset value: itm ].
		30 -> [ :evt :itm | itm editor cursorUp: evt. reset value: itm ].		
		$l -> [ :evt :itm | itm editor cursorRight: evt. reset value: itm ].
		29 -> [ :evt :itm | itm editor cursorRight: evt. reset value: itm ].
		
		$o -> [ :evt :itm |
			| editor |
			editor := itm editor.
			editor cursorEnd: evt.
			editor replaceSelectionWith: (Character newLineCharacter asString).
			#append. 
		].
				
		$w -> [ :evt :itm |
			itm vimOperator = $d
				ifTrue: [
					"Delete word under cursor."
					| allText atEndOfLine editor startIndex stopIndex range |

					editor := itm editor.
					"editor pointBlock returns a CharacterBlock object."
					startIndex := editor pointBlock stringIndex.
					range := editor wordRangeIncluding: startIndex.
					stopIndex := range last.
					allText := editor text.
					atEndOfLine := allText at: stopIndex + 1 :: isLineSeparator.
					atEndOfLine ifFalse: [ stopIndex := stopIndex + 1 ].
					editor selectFrom: startIndex to: stopIndex.
					editor cut.
					itm vimOperator: nil.
				]
				ifFalse: [
					"Move to next word."
					itm editor
						moveCursor:  [ :position | itm editor nextWordStart: position ]
						forward: true
						event: evt
				].
			reset value: itm.
		].
		$b -> [ :evt :itm |
			itm editor
				moveCursor:  [ :position | itm editor previousWordStart: position ]
				forward: false
				event: evt.
			reset value: itm.
		].

		$0 -> [ :evt :itm |
			| editor |
			editor := itm editor.
			editor
				moveCursor:  [ :position | editor beginningOfLine: position ]
				forward: false
				event: evt.
			reset value: itm.
		].

		"$^ -> [ :evt :itm | itm editor cursorHome: evt ]." "TODO: Fix"

		$$ -> [ :evt :itm |
			| editor |
			editor := itm editor.
			editor
				moveCursor:  [ :position | editor endOfLine: position ]
				forward: true
				event: evt.
			reset value: itm.
		].
	}.
! !

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

!TextEditor methodsFor: '*Vim' stamp: 'RMV 12/27/2024 08:52:30'!
textComposition
	"This instance variable is not exposed in the base image."

	^ textComposition! !
