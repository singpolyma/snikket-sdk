package xmpp;

import haxe.io.BytesData;
import xmpp.MessageSync;
import xmpp.ChatMessage;
import xmpp.Chat;
import xmpp.GenericStream;
import xmpp.queries.MAMQuery;
import xmpp.Color;

enum ChatType {
	ChatTypeDirect;
	ChatTypeGroup;
	ChatTypePublic;
}

abstract class Chat {
	private var client:Client;
	private var stream:GenericStream;
	private var persistence:Persistence;
	private var avatarSha1:Null<BytesData> = null;
	public var chatId(default, null):String;
	public var type(default, null):Null<ChatType>;

	private function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String, type:ChatType) {
		this.client = client;
		this.stream = stream;
		this.persistence = persistence;
		this.chatId = chatId;
	}

	abstract public function sendMessage(message:ChatMessage):Void;

	abstract public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void;

	public function isDirectChat():Bool { return type.match(ChatTypeDirect); };
	public function isGroupChat():Bool  { return type.match(ChatTypeGroup);  };
	public function isPublicChat():Bool { return type.match(ChatTypePublic); };

	public function onMessage(handler:ChatMessage->Void):Void {
		this.stream.on("message", function(event) {
			final stanza:Stanza = event.stanza;
			final from = JID.parse(stanza.attr.get("from"));
			if (from.asBare() != JID.parse(this.chatId)) return EventUnhandled;

			final chatMessage = ChatMessage.fromStanza(stanza, this.client.jid);
			if (chatMessage != null) handler(chatMessage);

			return EventUnhandled; // Allow others to get this event as well
		});
	}
}

class DirectChat extends Chat {
	public function new(client:Client, stream:GenericStream, persistence:Persistence, chatId:String) {
		super(client, stream, persistence, chatId, ChatTypeDirect);
	}

	public function getMessages(beforeId:Null<String>, beforeTime:Null<String>, handler:(Array<ChatMessage>)->Void):Void {
		persistence.getMessages(client.jid, chatId, beforeId, beforeTime, (messages) -> {
			if (messages.length > 0) {
				handler(messages);
			} else {
				var filter:MAMQueryParams = { with: this.chatId };
				if (beforeId != null) filter.page = { before: beforeId };
				var sync = new MessageSync(this.client, this.stream, filter);
				sync.onMessages((messages) -> {
					for (message in messages.messages) {
						persistence.storeMessage(chatId, message);
					}
					handler(messages.messages);
				});
				sync.fetchNext();
			}
		});
	}

	public function sendMessage(message:ChatMessage):Void {
		client.chatActivity(this);
		client.sendStanza(message.asStanza());
	}

	public function setAvatarSha1(sha1: BytesData) {
		this.avatarSha1 = sha1;
	}

	public function getPhoto(callback:(String)->Void) {
		if (avatarSha1 != null) {
			persistence.getMediaUri("sha-1", avatarSha1, (uri) -> {
				if (uri != null) {
					callback(uri);
				} else {
					callback(Color.defaultPhoto(chatId, chatId.charAt(0)));
				}
			});
		} else {
			callback(Color.defaultPhoto(chatId, chatId.charAt(0)));
		}
	}
}
