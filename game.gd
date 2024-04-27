extends Node2D

@export var protocol = "ROBCO INDUSTRIES(TM) TERMLINK PROTOCOL"
@export var enterpw = "ENTER PASSWORD NOW"
@export var attemptstxt = "4 ATTEMPT(S) LEFT: ◼ ◼ ◼ ◼"

# typing anim
var typing_speed
var current_index: int = 0
var current_text: String
var current_label: Label
var typequeue = []
var time_accumulator: float = 0.0

# puzzle
var addr
var code
var wordlength
var words_to_use = []
var solution
var wordPositions
var glyphs = []
var glyphPositions
var codearray = []
var selectedWord = ""
var selectedGlyph = ""
var attemptsLeft = 4

# caret
const caretJump = Vector2(18,32)
var caretPos = Vector2(0,0)
var highlightobj = preload("res://highlight.tscn")
var canmove = false

# sounds
const charscroll_loop = "res://hacking sfx/char/ui_hacking_charscroll_lp.wav"
const passgood = "res://hacking sfx/ui_hacking_passgood.wav"
const passbad = "res://hacking sfx/ui_hacking_passbad.wav"
const kp_singles = ["res://hacking sfx/char/single/ui_hacking_charsingle_01.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_02.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_03.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_04.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_05.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_06.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_07.wav",
					"res://hacking sfx/char/single/ui_hacking_charsingle_08.wav"]
const kp_multiples = ["res://hacking sfx/char/multiple/ui_hacking_charmultiple_01.wav", 
					"res://hacking sfx/char/multiple/ui_hacking_charmultiple_02.wav", 
					"res://hacking sfx/char/multiple/ui_hacking_charmultiple_03.wav", 
					"res://hacking sfx/char/multiple/ui_hacking_charmultiple_04.wav"]
const kp_enters = ["res://hacking sfx/char/enter/ui_hacking_charenter_01.wav", 
					"res://hacking sfx/char/enter/ui_hacking_charenter_02.wav", 
					"res://hacking sfx/char/enter/ui_hacking_charenter_03.wav"]

var rng = RandomNumberGenerator.new()
var words = loadtxt()

const punc = """({<[)}>]!$%^&*@#':"?/|,"""
const openbrackets = "({<["
const closebrackets = ")}>]"

func restartSys():
	$PROTOCOL.text=""
	$ENTERPW.text=""
	$ATTEMPTS.text=""
	$L_CHAR.text=""
	$R_CHAR.text=""
	$INPUT.text="\u200e\n>"
	$LOCKOUT.visible = false
	attemptsLeft = 4
	code = ""
	wordlength = 0
	words_to_use = []
	solution = ""
	wordPositions = []
	glyphs = []
	glyphPositions = []
	codearray = []
	selectedWord = ""
	selectedGlyph = ""
	attemptsLeft = 4
	
	addr = genAddr()
	code = genCode()
	typequeue.append([$PROTOCOL,protocol,0.015])
	typequeue.append([$ENTERPW,enterpw,0.015])
	typequeue.append([$ATTEMPTS,attemptstxt,0.015])
	
	var lchar=""
	var rchar=""
	for c in range(17):
		lchar+=addr[0][c]+" "+code[0][c]+"\n"
	for c in range(17):
		rchar+=addr[1][c]+" "+code[1][c]+"\n"
	typequeue.append([$L_CHAR,lchar,0.000])
	typequeue.append([$R_CHAR,rchar,0.000])
	
	current_label=typequeue[0][0]
	current_text=typequeue[0][1]
	typing_speed=typequeue[0][2]
	
	playSound(charscroll_loop)

func playSound(filename: String):
	var sound = load(filename)
	
	if sound:
		$oneshot.stream = sound
		$oneshot.play()

func loadtxt():
	var file = FileAccess.open("res://wordlist.txt", FileAccess.READ)
	var words = file.get_as_text().split(" ")
	return Array(words)

func genAddr():
	var l_addr = []
	var r_addr = []
	var curAddr = rng.randi_range(4369,65127)
	for i in range(17):
		l_addr.append("0x%X"%curAddr)
		curAddr+=12
	for i in range(17):
		r_addr.append("0x%X"%curAddr)
		curAddr+=12
	return [l_addr,r_addr]
	
func placeWords(words: Array, words_pos: Array, spaces: int = 408,sameline: bool = false):
	var goodSpace
	var space
	var positions = []
	for word in words:
		goodSpace = false
		while not goodSpace:
			goodSpace = true
			space = rng.randi_range(0,spaces-1)
			if space+len(word)-1>spaces-1:
				goodSpace = false
			else:
				for i in range(space,len(word)+space-1):
					if words_pos[i] != null:
						goodSpace = false
			if space >= 2:
				if words_pos[space-2] != null:
					goodSpace = false
			if space+len(word)-1 <= spaces-2:
				if words_pos[space+len(word)-1] != null:
					goodSpace = false
			if sameline and (space/12 != (space+len(word)-1)/12):
				goodSpace=false
		for i in range(len(word)):
			words_pos[space+i] = word[i]
		var charposlist = []
		for i in range(len(word)):
			charposlist.append(space+i)
		positions.append(charposlist)
	return [words_pos,positions]
	
func getOtherBracket(bracket):
	var obf = openbrackets.find(bracket)
	var cbf = closebrackets.find(bracket)
	if obf != -1:
		return closebrackets[obf]
	if cbf != -1:
		return openbrackets[cbf]

func genCodeColumn(add):
	var column = []
	var newrow
	for row in range(17):
		newrow = ""
		var usedbrackets = []
		for char in range(12):
			var newpunc
			if codearray[12*row+char+add] != null:
				newpunc = codearray[12*row+char+add]
				newrow += newpunc
				if (newpunc in openbrackets) or (newpunc in closebrackets):
					usedbrackets.append(newpunc)
					usedbrackets.append(getOtherBracket(newpunc))
			else:
				newpunc = punc[rng.randi_range(0,len(punc)-1)]
				while newpunc in usedbrackets:
					newpunc = punc[rng.randi_range(0,len(punc)-1)]
				if getOtherBracket(newpunc):
					usedbrackets.append(newpunc)
					usedbrackets.append(getOtherBracket(newpunc))
				newrow+=newpunc
		column.append(newrow)
	return column

func genCode():
	var l_code = []
	var r_code = []
	var placed
	codearray=[]
	codearray.resize(408)
	
	var nextword = words.pick_random()
	wordlength = len(nextword)
	for i in range(rng.randi_range(5,10)):
		nextword = words.pick_random()
		while nextword in words_to_use or len(nextword) != wordlength:
			nextword = words.pick_random()
		words_to_use.append(nextword)
		
	for i in range(max(wordlength, 7)):
		var hInst = highlightobj.instantiate()
		hInst.visible = false
		$Highlights.add_child(hInst)
	
	var gibberish
	var newgibchar
	var bracketindex
	for i in range(rng.randi_range(3,7)):
		bracketindex = rng.randi_range(0,3)
		gibberish=""
		for j in range(rng.randi_range(0,5)):
			newgibchar = punc[rng.randi_range(0,len(punc)-1)]
			while newgibchar == openbrackets[bracketindex] or newgibchar == closebrackets[bracketindex]:
				newgibchar = punc[rng.randi_range(0,len(punc)-1)]
			gibberish+=newgibchar
		glyphs.append(openbrackets[bracketindex] + gibberish + closebrackets[bracketindex])
	
	solution = words_to_use.pick_random()
	
	placed = placeWords(words_to_use,codearray)
	codearray = placed[0]
	wordPositions = placed[1]
	
	placed = placeWords(glyphs,codearray,408,true)
	codearray = placed[0]
	glyphPositions = placed[1]
	
	l_code = genCodeColumn(0)
	r_code = genCodeColumn(204)
	
	codearray = ""
	for a in l_code:
		for b in a:
			codearray+=b
	for a in r_code:
		for b in a:
			codearray+=b
	
	return [l_code,r_code]

func typingLoop(delta: float):
	if current_index >= current_text.length():
		typequeue.pop_front()
		current_index=0
		time_accumulator=0
		if current_text[len(current_text)-1] != "\n" and current_text[len(current_text)-1] != "◼" and current_text[len(current_text)-1] != ">":
			current_label.position.y+=8.5
		if len(typequeue) > 0:
			current_label=typequeue[0][0]
			current_text=typequeue[0][1]
			typing_speed=typequeue[0][2]
		else:
			$oneshot.stop()
			canmove = true
			$KEYHOVER.visible = true
			moveCaret(Vector2(0,0))
	if time_accumulator > typing_speed:
		current_label.text = (current_text.left(current_index + 1)+"◼").substr(0,len(current_text))
		if typing_speed == 0:
			current_index += 3
		else: current_index += 1
		time_accumulator = 0.0
	time_accumulator += delta

func moveCaret(dir:Vector2):
	var activeHighlights = activeHighlights()
	if len(activeHighlights) > 0:
		if dir.x == -1:
			$KEYHOVER.position = activeHighlights[0].position
			caretPos = xy_to_pos(activeHighlights[0].position)
		else:
			$KEYHOVER.position = activeHighlights[-1].position
			caretPos = xy_to_pos(activeHighlights[-1].position)
	if (caretPos.x+dir.x < 0) or (caretPos.x+dir.x > 23) or (caretPos.y+dir.y < 0 or caretPos.y+dir.y > 16):
		print(caretPos)
		return
	else:			
		clearHighlights()	
		if (caretPos.x == 11 and dir.x == 1) or (caretPos.x == 12 and dir.x == -1):
			$KEYHOVER.position.x += 165*dir.x
		caretPos += dir
		$KEYHOVER.position += dir*caretJump
		caretCheckForWords(pos_to_index(caretPos))
		if selectedWord != "":
			terminal_print_temp(">%s" % [selectedWord]) 
			playSound(kp_multiples.pick_random())
		elif selectedGlyph != "":
			terminal_print_temp(">%s" % [selectedGlyph]) 
			playSound(kp_multiples.pick_random())
		else:
			terminal_print_temp(">%s" % [codearray[pos_to_index(xy_to_pos($KEYHOVER.position))]])
			playSound(kp_singles.pick_random())
	print(caretPos)
	
func caretCheckForWords(pos):
	selectedWord = ""
	selectedGlyph = ""
	for word in wordPositions:
		if int(pos) in word:
			selectedWord = words_to_use[wordPositions.find(word)]
			highlightWord(word)
	for word in glyphPositions:
		if word[0] == pos or word[-1] == pos:
			selectedGlyph = glyphs[glyphPositions.find(word)]
			highlightWord(word)	
		
func activeHighlights():
	var active = []
	for obj in $Highlights.get_children():
		if obj.visible:
			active.append(obj)
	return active
		
func clearHighlights():
	for obj in $Highlights.get_children():
		obj.visible = false	
	
func highlightWord(word):
	var highlightPos
	var highlightObjs = $Highlights.get_children()
	for i in range(len(word)):
		highlightPos = pos_to_xy(index_to_pos(word[i]))
		
		highlightObjs[i].visible = true
		highlightObjs[i].position = highlightPos
	
func index_to_pos(index):
	var pos: Vector2
	if index > 203:
		pos.y = (index-204)/12
		pos.x = 12+(index%12)
	else:
		pos.y = index/12
		pos.x = index%12
	return pos
	
func pos_to_index(pos):
	var index: int
	if pos.x > 11:
		index = (pos.x)+(pos.y-1)*12+204
	else:
		index = (pos.x)+(pos.y)*12
	return index
	
func pos_to_xy(pos):
	var xy = Vector2(180,219)
	if pos.x > 11:
		xy.x += 363
		xy.x += (pos.x - 11)*caretJump.x
	else:
		xy.x += pos.x*caretJump.x
	xy.y += pos.y*caretJump.y
	return xy
	
func xy_to_pos(xy):
	var pos = xy - Vector2(180,219)
	if int(pos.x) % int(caretJump.x) == 0:
		pos.x = pos.x / caretJump.x
	else:
		pos.x = (pos.x-165) / caretJump.x
	pos.y = pos.y / caretJump.y
	return pos
						
func press_enter():
	playSound(kp_enters.pick_random())
	if selectedWord != "":
		var similarity = 0
		for i in range(wordlength):
			if selectedWord[i] == solution[i]:
				similarity+=1
		if similarity == wordlength:
			unlock_terminal()
			return
		playSound(passbad)
		attemptsLeft-=1
		print_to_terminal("%s\n>Entry denied\n>%d/%d correct." % [selectedWord, similarity, wordlength])
		$ATTEMPTS.text = ("%s ATTEMPT(S) LEFT: " % [attemptsLeft]) + "◼ ".repeat(attemptsLeft)
		if attemptsLeft == 0:
			$ATTEMPTS.position.y+=8.5
			terminal_lockout()
			return
	elif selectedGlyph != "":
		if selectedGlyph == glyphs[0]:
			attemptsLeft = 4
			print_to_terminal(">%s\n>Allowance\n>replenished." % [selectedGlyph])
			$ATTEMPTS.text = ("%s ATTEMPT(S) LEFT: " % [attemptsLeft]) + "◼ ".repeat(attemptsLeft)
		else:
			print_to_terminal(">%s\n>Dud removed." % [selectedGlyph])
			var rnd_word_to_remove = rng.randi_range(0,wordPositions.size()-1)
			while words_to_use[rnd_word_to_remove] == solution:
				rnd_word_to_remove = rng.randi_range(0,wordPositions.size()-1)
			dot_out(wordPositions[rnd_word_to_remove])
			wordPositions[rnd_word_to_remove] = [-1]
		dot_out(glyphPositions[glyphs.find(selectedGlyph)])
		glyphPositions[glyphs.find(selectedGlyph)] = [-1]
		
	
func dot_out(word):
	var rchar = $R_CHAR.text
	var lchar = $L_CHAR.text
	for index in word:
		if index > 203:
			rchar[index-(17*20)+((index/12)*8)+7] = "."
		else:
			print(index)
			lchar[index+((index/12)*8)+7] = "."
		codearray[index] = "."
	$R_CHAR.text = rchar
	$L_CHAR.text = lchar
	
func print_to_terminal(str):
	var lines = $INPUT.text.split("\n")
	lines.insert(lines.size()-2,str)
	print(str)
	if lines.size() > 13:
		lines = lines.slice(lines.size()-14,lines.size())
	$INPUT.text = "\n".join(lines)
	
func terminal_print_temp(str):
	var lines = $INPUT.text.split("\n")
	lines[lines.size()-2] = "\u200e"
	lines[lines.size()-1] = str
	$INPUT.text = "\n".join(lines)
				
func unlock_terminal():
	playSound(passgood)
	canmove = false
	$KEYHOVER.visible = false
	clearHighlights()
	print_to_terminal(">%s\n>Exact match!\n>Please wait\n>while system\n>is accessed." % [solution])
	terminal_print_temp(">")
	await get_tree().create_timer(2.0).timeout
	$PROTOCOL.position.y-=8.5
	$ENTERPW.position.y-=8.5
	restartSys()
	
func terminal_lockout():
	print_to_terminal(">Lockout in\n>Progress.")
	canmove = false
	$KEYHOVER.visible = false
	clearHighlights()
	terminal_print_temp(">")
	await get_tree().create_timer(2.0).timeout
	$PROTOCOL.text=""
	$ENTERPW.text=""
	$ATTEMPTS.text=""
	$L_CHAR.text=""
	$R_CHAR.text=""
	$INPUT.text=""
	$LOCKOUT.visible = true
	await get_tree().create_timer(4.0).timeout
	$PROTOCOL.position.y-=8.5
	$ENTERPW.position.y-=8.5
	restartSys()

func _input(event):
	if canmove:
		if event.is_action_pressed("left"):
			moveCaret(Vector2(-1,0))
		if event.is_action_pressed("right"):
			moveCaret(Vector2(1,0))		
		if event.is_action_pressed("up"):
			moveCaret(Vector2(0,-1))
		if event.is_action_pressed("down"):
			moveCaret(Vector2(0,1))
		if event.is_action_pressed("enter"):
			press_enter()
		
# Called when the node enters the scene tree for the first time.
func _ready():
	restartSys()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if len(typequeue) > 0: typingLoop(delta)
