package hxparse;
import hxparse.Types;

typedef Pos = {
	var psource : String;
	var pline : Int;
	var pmin : Int;
	var pmax : Int;
}

class Lexer {
	public var current:String;
	var buffer:haxe.io.Bytes;
	var bsize:Int;
	var bin:Int;
	var bpos:Int;
	var cin:Int;
	var cpos:Int;
	var input:haxe.io.Input;
	var source:String;
	var line:Int;
	var pos:Int;
	var carriage:Bool;
	
	public function new(input:haxe.io.Input, sourceName:String = "<null>") {
		var bufsize = 4096;
		carriage = false;
		current = "";
		buffer = haxe.io.Bytes.alloc(bufsize);
		bsize = bufsize;
		bin = 0;
		cin = 0;
		bpos = bufsize;
		cpos = bufsize;
		this.input = input;
		source = sourceName;
		line = 0;
		pos = 0;
	}
	
	public function curPos() {
		return {
			psource: source,
			pline: line,
			pmin: pos - current.length,
			pmax: pos
		}
	}
	
	public function char():Null<Int> {
		try {
			var c = read();
			bpos--;
			bin++;
			incLine(c);
			return c;
		} catch (e:Dynamic) {
			return null;
		}
	}
	
	function read() {
		if (bin == 0) {
			if (bpos == bsize) {
				var buf = haxe.io.Bytes.alloc(bsize * 2);
				buf.blit(bsize, buffer, 0, bsize);
				cpos += bsize;
				bpos += bsize;
				buffer = buf;
				bsize *= 2;
			}
			var delta = bpos - cpos;
			buffer.blit(0, buffer, cpos, delta);
			bpos = delta;
			cpos = 0;
			var k = input.readBytes(buffer, delta, (bsize - delta));
			bin += k;
			cin += k;
		}
		var c = buffer.get(bpos);
		bpos++;
		bin--;
		return c;
	}
	
	function incLine(c) {
		if (c == "\r".code)
			carriage = true;
		else if (c == "\n".code || carriage) {
			carriage = false;
			line++;
		}
	}

	public function token<T>(ruleset:Ruleset<T>):T {
		var state = ruleset.engine.firstState();
		var n = 0;
		var cur = 0;
		var last = 0;
		function process(eof) {
			if (state == null) {
				current = "";
				if (!eof) {
					bpos -= (cur + 1);
					bin += (cur + 1);
				}
			} else {
				cin -= last;
				bin = cin;
				current = buffer.sub(cpos, last).toString();
				cpos += last;
				bpos = cpos;
				pos += last;
				var i = 0;
				while (i < last) {
					incLine(current.charCodeAt(i));
					i++;
				}
			}
		}
		try {
			while (true) {
				if (state.finals.length > 0)
					last = n;
				var i = read();
				cur = n;
				var newState = state.trans.get(i);
				if (newState == null)
					throw "Exit";
				else
					state = newState;
				n++;
			}
		} catch (e:haxe.io.Eof) {
			process(true);
		} catch (e:String) {
			process(false);
		}
		if (state == null || state.finals.length == 0)
			throw "Unexpected";
		// TODO: [0] doesn't seem right
		return ruleset.functions[state.finals[0].pid](this);
	}
	
	static public function build<Token>(rules:Map<String,Lexer->Token>) {
		var cases = [];
		var functions = [];
		for (k in rules.keys()) {
			cases.push(LexEngine.parse(k));
			functions.push(rules.get(k));
		}
		return new Ruleset(new LexEngine(cases),functions);
	}
}