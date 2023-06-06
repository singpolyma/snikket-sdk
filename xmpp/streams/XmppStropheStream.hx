package xmpp.streams;

import haxe.DynamicAccess;

import cpp.Char;
import cpp.ConstPointer;
import cpp.Function;
import cpp.NativeArray;
import cpp.NativeGc;
import cpp.NativeString;
import cpp.RawConstPointer;
import cpp.RawPointer;

import xmpp.GenericStream;
import xmpp.ID;
import xmpp.Stanza;

@:include("strophe.h")
@:native("xmpp_mem_t*")
extern class StropheMem { }

@:include("strophe.h")
@:native("xmpp_log_t*")
extern class StropheLog { }

@:include("strophe.h")
@:native("xmpp_conn_event_t")
extern enum StropheConnEvent { }

@:include("strophe.h")
@:native("xmpp_stream_error_t*")
extern class StropheStreamError { }

@:include("strophe.h")
@:native("xmpp_ctx_t*")
extern class StropheCtx {
	@:native("xmpp_ctx_new")
	static function create(mem:StropheMem, log:StropheLog):StropheCtx;

	@:native("xmpp_ctx_free")
	static function free(ctx:StropheCtx):Void;

	@:native("xmpp_initialize")
	static function initialize():Void;

	@:native("xmpp_run")
	static function run(ctx:StropheCtx):Void;

	@:native("xmpp_stop")
	static function stop(ctx:StropheCtx):Void;
}

@:include("strophe.h")
@:native("xmpp_conn_t*")
extern class StropheConn {
	@:native("xmpp_conn_new")
	static function create(ctx:StropheCtx):StropheConn;

	@:native("xmpp_conn_set_jid")
	static function set_jid(conn:StropheConn, jid:ConstPointer<Char>):Void;

	@:native("xmpp_conn_set_pass")
	static function set_pass(conn:StropheConn, pass:ConstPointer<Char>):Void;

	@:native("xmpp_connect_client")
	static function connect_client(
		conn:StropheConn,
		altdomain:ConstPointer<Char>,
		altport:cpp.UInt16,
		callback:cpp.Callable<StropheConn->StropheConnEvent->cpp.Int32->StropheStreamError->RawPointer<Void>->Void>,
		userdata:RawPointer<Void>
	):cpp.Int32;

	@:native("xmpp_handler_add")
	static function handler_add(
		conn:StropheConn,
		handler:cpp.Callable<StropheConn->StropheStanza->RawPointer<Void>->Int>,
		altdomain:ConstPointer<Char>,
		altdomain:ConstPointer<Char>,
		altdomain:ConstPointer<Char>,
		userdata:RawPointer<Void>
	):cpp.Int32;

	@:native("xmpp_send")
	static function send(conn:StropheConn, stanza:StropheStanza):Void;

	@:native("xmpp_conn_release")
	static function release(conn:StropheConn):Void;
}


@:include("strophe.h")
@:native("xmpp_stanza_t*")
extern class StropheStanza {
	@:native("xmpp_stanza_new")
	static function create(ctx:StropheCtx):StropheStanza;

	@:native("xmpp_stanza_get_name")
	static function get_name(stanza:StropheStanza):ConstPointer<Char>;

	@:native("xmpp_stanza_get_attribute_count")
	static function get_attribute_count(stanza:StropheStanza):Int;

	@:native("xmpp_stanza_get_attributes")
	static function get_attributes(stanza:StropheStanza, attr:RawPointer<RawConstPointer<Char>>, attrlen:Int):Int;

	@:native("xmpp_stanza_get_children")
	static function get_children(stanza:StropheStanza):StropheStanza;

	@:native("xmpp_stanza_get_next")
	static function get_next(stanza:StropheStanza):StropheStanza;

	@:native("xmpp_stanza_is_text")
	static function is_text(stanza:StropheStanza):Bool;

	@:native("xmpp_stanza_get_text_ptr")
	static function get_text_ptr(stanza:StropheStanza):RawConstPointer<Char>;

	@:native("xmpp_stanza_set_name")
	static function set_name(stanza:StropheStanza, name:ConstPointer<Char>):Void;

	@:native("xmpp_stanza_set_attribute")
	static function set_attribute(stanza:StropheStanza, key:ConstPointer<Char>, value:ConstPointer<Char>):Void;

	@:native("xmpp_stanza_add_child_ex")
	static function add_child_ex(stanza:StropheStanza, child:StropheStanza, clone:Bool):Void;

	@:native("xmpp_stanza_set_text")
	static function set_text(stanza:StropheStanza, text:ConstPointer<Char>):Void;

	@:native("xmpp_stanza_release")
	static function release(stanza:StropheStanza):Void;
}

@:buildXml("
<target id='haxe'>
  <lib name='-lstrophe'/>
</target>
")
@:headerInclude("strophe.h")
@:headerClassCode("
	private: xmpp_ctx_t *ctx;
	private: xmpp_conn_t *conn;
")
class XmppStropheStream extends GenericStream {
	extern private var ctx:StropheCtx;
	extern private var conn:StropheConn;

	override public function new() {
		super();
		StropheCtx.initialize(); // TODO: shutdown?
		ctx = StropheCtx.create(null, null);
		conn = StropheConn.create(ctx);
		StropheConn.handler_add(
			conn,
			cpp.Callable.fromStaticFunction(strophe_stanza),
			null,
			null,
			null,
			untyped __cpp__("(void*)this")
		);
		NativeGc.addFinalizable(this, false);
	}

	public function newId():String {
		return ID.long();
	}

	public static function strophe_stanza(conn:StropheConn, stanza:StropheStanza, userdata:RawPointer<Void>):Int {
		var stream: XmppStropheStream = untyped __cpp__("static_cast<hx::Object*>(userdata)");
		stream.onStanza(convertToStanza(stanza, null));
		return 1;
	}

	public static function strophe_connect(conn:StropheConn, event:StropheConnEvent, error:cpp.Int32, stream_error:StropheStreamError, userdata:RawPointer<Void>) {
		var stream: XmppStropheStream = untyped __cpp__("static_cast<hx::Object*>(userdata)");
		if (event == untyped __cpp__("XMPP_CONN_CONNECT")) {
			stream.trigger("status/online", {});
		}
		if (event == untyped __cpp__("XMPP_CONN_DISCONNECT")) {
			stream.trigger("status/offline", {});
		}
		if (event == untyped __cpp__("XMPP_CONN_FAIL")) {
			stream.trigger("status/offline", {});
		}
	}

	public function connect(jid:String) {
		StropheConn.set_jid(conn, NativeString.c_str(jid));
		this.on("auth/password", function (event) {
			var o = this;
			var pass = event.password;
			StropheConn.set_pass(conn, NativeString.c_str(pass));
			StropheConn.connect_client(
				this.conn,
				null,
				0,
				cpp.Callable.fromStaticFunction(strophe_connect),
				untyped __cpp__("o.GetPtr()")
			);

			return EventHandled;
		});
		this.trigger("auth/password-needed", {});
		StropheCtx.run(ctx);
	}

	public static function convertToStanza(el:StropheStanza, dummy:RawPointer<Void>):Stanza {
		var name = StropheStanza.get_name(el);
		var attrlen = StropheStanza.get_attribute_count(el);
		var attrsraw: RawPointer<cpp.Void> = NativeGc.allocGcBytesRaw(attrlen * 2 * untyped __cpp__("sizeof(char*)"), false);
		var attrsarray: RawPointer<RawConstPointer<Char>> = untyped __cpp__("static_cast<const char**>(attrsraw)");
		var attrsptr = cpp.Pointer.fromRaw(attrsarray);
		StropheStanza.get_attributes(el, attrsarray, attrlen * 2);
		var attrs: DynamicAccess<String> = {};
		for (i in 0...attrlen) {
			var key = ConstPointer.fromRaw(attrsptr.at(i*2));
			var value = ConstPointer.fromRaw(attrsptr.at((i*2)+1));
			attrs[NativeString.fromPointer(key)] = NativeString.fromPointer(value);
		}
		var stanza = new Stanza(NativeString.fromPointer(name), attrs);

		var child = StropheStanza.get_children(el);
		while(child != null) {
			if (StropheStanza.is_text(child)) {
				var r = StropheStanza.get_text_ptr(child);
				var x = NativeString.fromPointer(ConstPointer.fromRaw(StropheStanza.get_text_ptr(child)));
				stanza.text(x);
			} else {
				stanza.addChild(convertToStanza(child, null));
			}
			child = StropheStanza.get_next(child);
		}

		return stanza;
	}

	private function convertFromStanza(el:Stanza):StropheStanza {
		var xml = StropheStanza.create(ctx);
		StropheStanza.set_name(xml, NativeString.c_str(el.name));
		for (attr in el.attr.keyValueIterator()) {
			var key = attr.key;
			var value = attr.value;
			if (value != null) {
				StropheStanza.set_attribute(xml, NativeString.c_str(key), NativeString.c_str(value));
			}
		}
		if(el.children.length > 0) {
			for(child in el.children) {
				switch(child) {
					case Element(stanza):
						StropheStanza.add_child_ex(xml, convertFromStanza(stanza), false);
					case CData(text):
						var text_node = StropheStanza.create(ctx);
						StropheStanza.set_text(text_node, NativeString.c_str(text.serialize()));
						StropheStanza.add_child_ex(xml, text_node, false);
				};
			}
		}
		return xml;
	}

	public function sendStanza(stanza:Stanza) {
		StropheConn.send(conn, convertFromStanza(stanza));
	}

	public function finalize() {
		StropheCtx.stop(ctx);
		StropheConn.release(conn);
		StropheCtx.free(ctx);
	}
}
