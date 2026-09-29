class_name Share
## Opens the Android share sheet with plain text (WhatsApp, X, Instagram, ...).
## Uses Godot's Java bridge with static calls only, so no Gradle build or plugin is needed.


static func text(message: String) -> void:
	var runtime := Engine.get_singleton("AndroidRuntime") if Engine.has_singleton("AndroidRuntime") else null
	if runtime == null:
		# Desktop: no share sheet; put it on the clipboard so it can be pasted anywhere.
		DisplayServer.clipboard_set(message)
		print("Share (copied to clipboard): ", message)
		return
	var activity = runtime.getActivity()
	var intent_class = JavaClassWrapper.wrap("android.content.Intent")
	# ACTION_SEND intent built from an intent URI: avoids calling Java constructors/overloads.
	var uri := "intent:#Intent;action=android.intent.action.SEND;type=text/plain;S.android.intent.extra.TEXT=%s;end" % message.uri_encode()
	var send = intent_class.parseUri(uri, intent_class.URI_INTENT_SCHEME)
	var chooser = intent_class.createChooser(send, "Share your score")
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(func(): activity.startActivity(chooser)))
