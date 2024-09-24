package snikket.streams;

import haxe.DynamicAccess;
import haxe.io.Bytes;
import haxe.io.BytesData;

import cpp.Char;
import cpp.ConstPointer;
import cpp.Function;
import cpp.NativeArray;
import cpp.NativeGc;
import cpp.NativeString;
import cpp.RawConstPointer;
import cpp.RawPointer;

import snikket.GenericStream;
import snikket.ID;
import snikket.Stanza;

@:include("strophe.h")
@:native("xmpp_mem_t*")
extern class StropheMem { }

@:include("strophe.h")
@:native("xmpp_log_t*")
extern class StropheLog { }

@:include("strophe.h")
@:native("xmpp_conn_event_t")
extern class StropheConnEvent { }

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

	@:native("xmpp_run_once")
	static function run_once(ctx:StropheCtx, timeout:cpp.UInt64):Void;

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
	private var iqHandlers: Map<IqRequestType, Map<String, Stanza->IqResult>> = [IqRequestType.Get => [], IqRequestType.Set => []];
	private final pending: Array<Stanza> = [];
	private var ready = false;

	override public function new() {
		super();
		StropheCtx.initialize(); // TODO: shutdown?
		untyped __cpp__("xmpp_log_t *logger = NULL;");
		if (Sys.getEnv("SNIKKET_XMPP_DEBUG") != null) {
			untyped __cpp__("logger = xmpp_get_default_logger(XMPP_LEVEL_DEBUG);");
		}
		ctx = StropheCtx.create(null, untyped __cpp__("logger"));
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

	public static function strophe_stanza(conn:StropheConn, sstanza:StropheStanza, userdata:RawPointer<Void>):Int {
		final stream: XmppStropheStream = untyped __cpp__("static_cast<hx::Object*>(userdata)");
		final stanza = convertToStanza(sstanza, null);

		final xmlns = stanza.attr.get("xmlns");
		if(xmlns == "jabber:client") {
			final name = stanza.name;
			if(name == "iq") {
				final type = stanza.attr.get("type");
				if(type == "result" || type == "error") {
					stream.onStanza(stanza);
				} else {
					// These are handled by onIq instead
					final child = stanza.getFirstChild();
					if (child != null) {
						final handler = stream.iqHandlers[type == "get" ? IqRequestType.Get : IqRequestType.Set]["{" + child.attr.get("xmlns") + "}" + child.name];
						if (handler != null) {
							final reply = new Stanza("iq", { type: "result", from: stanza.attr.get("to"), to: stanza.attr.get("from"), id: stanza.attr.get("id") });
							try {
								switch(handler(stanza)) {
									case IqResultElement(el): reply.addChild(el);
									case IqResult:  // Empty success reply
									case IqNoResult:
										reply.attr.set("result", "error");
										reply.tag("error", { type: "cancel" }).tag("service-unavailable", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" });
								}
							} catch (e) {
								reply.attr.set("result", "error");
								reply.tag("error", { type: "cancel" }).tag("internal-server-error", { xmlns: "urn:ietf:params:xml:ns:xmpp-stanzas" });
							}
							stream.sendStanza(reply);
						}
					}
				}
			} else {
				stream.onStanza(stanza);
			}
		}

		return 1;
	}

	public function onIq(type:IqRequestType, tag:String, xmlns:String, handler:(Stanza)->IqResult) {
		iqHandlers[type]["{" + xmlns + "}" + tag] = handler;
	}

	public static function strophe_connect(conn:StropheConn, event:StropheConnEvent, error:cpp.Int32, stream_error:StropheStreamError, userdata:RawPointer<Void>) {
		var stream: XmppStropheStream = untyped __cpp__("static_cast<hx::Object*>(userdata)");
		if (event == untyped __cpp__("XMPP_CONN_CONNECT")) {
			stream.ready = true;
			while (stream.pending.length > 0) {
				stream.sendStanza(stream.pending.shift());
			}
			stream.trigger("status/online", {});
		}
		if (event == untyped __cpp__("XMPP_CONN_DISCONNECT")) {
			if (!stream.ready) {
				// Never connected, auth failure
				stream.trigger("auth/fail", {});
			} else {
				stream.ready = false;
				stream.trigger("status/offline", {});
			}
		}
		if (event == untyped __cpp__("XMPP_CONN_FAIL")) {
			stream.ready = false;
			stream.trigger("status/offline", {});
		}
	}

	public function connect(jid:String, sm:Null<BytesData>) {
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
		poll();
	}

	private function poll() {
		sys.thread.Thread.current().events.run(() -> {
			StropheCtx.run_once(ctx, 1);
			poll();
		});
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
		if (ready) {
			StropheConn.send(conn, convertFromStanza(stanza));
		} else {
			pending.push(stanza);
		}
	}

	public function finalize() {
		StropheCtx.stop(ctx);
		StropheConn.release(conn);
		StropheCtx.free(ctx);
	}
}
