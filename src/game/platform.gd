class_name Platform
## The only place that knows which platform the game runs on: screens ask here instead of checking OS features
## themselves.

const SAVE_EXT := "qmsave"

# Keeps the browser's file-picker callback alive while the picker is open.
static var _js_callback: JavaScriptObject
# Keeps the "already open in another tab" callback alive for the whole session.
static var _instance_callback: JavaScriptObject
static var _writes_blocked: bool = false
# Keeps the /api/me callback alive until the reply arrives.
static var _viewer_callback: JavaScriptObject
# Keeps confirm_saved's page callback alive for the whole session.
static var _save_callback: JavaScriptObject


## Callbacks waiting for one save to reach IndexedDB, keyed by the save's sequence number.
class SaveWait:
	var dir: String = ""
	var done: Array[Callable] = []

static var _save_waits: Dictionary[int, SaveWait] = {}
static var _save_seq := 0


## Running in a browser (the Web export).
static func is_web() -> bool:
	return OS.has_feature("web")


## Background threads are available. The Web export is single-threaded.
static func has_threads() -> bool:
	return not is_web()


## Runs `body` in the page as a function of `params` called with `args`. Every argument is JSON-encoded here,
## once, so text from the game (names, translations, paths) reaches the page as a value and never as code.
static func _js_call(params: String, body: String, args: Array) -> void:
	JavaScriptBridge.eval(_js_source(params, body, args), true)


static func _js_source(params: String, body: String, args: Array) -> String:
	var encoded := PackedStringArray()
	for a in args:
		encoded.append(JSON.stringify(a))
	return "(function (" + params + ") {" + body + "})(" + ", ".join(encoded) + ");"


## Web: makes this tab the only one with the game open. The browser storage (user://, IndexedDB) is copied into
## memory when a tab starts and written back whole on every save, so a second tab would work on a stale copy and its
## first write would delete what the other tab saved since. The first tab takes a browser lock (Web Locks API, or a
## BroadcastChannel ping where that is missing) and keeps it until it closes; a later tab covers the page with
## `blocked_text`, stops writing (`writes_blocked`) and calls `on_blocked`. It stays blocked even if the first tab
## closes, because its copy of the storage is already stale: the player reloads it. Does nothing on desktop.
static func claim_single_instance(blocked_text: String, on_blocked: Callable) -> void:
	if not is_web():
		return
	_instance_callback = JavaScriptBridge.create_callback(func(_args: Array):
		_writes_blocked = true
		on_blocked.call())
	JavaScriptBridge.get_interface("window").qmOnInstanceBlocked = _instance_callback
	_js_call("text", """
		if (window.qmInstance) return;
		window.qmInstance = 'pending';
		function owner() { window.qmInstance = 'owner'; }
		function blocked() {
			if (window.qmInstance === 'blocked') return;
			window.qmInstance = 'blocked';
			var d = document.createElement('div');
			d.textContent = text;
			d.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:2147483647;display:flex;' +
				'align-items:center;justify-content:center;padding:2em;box-sizing:border-box;text-align:center;' +
				'white-space:pre-line;background:rgba(12,10,8,0.94);color:#f1e6cc;font:20px/1.5 sans-serif';
			document.body.appendChild(d);
			if (window.qmOnInstanceBlocked) window.qmOnInstanceBlocked();
		}
		var name = 'quidditch-manager-instance';
		if (navigator.locks && navigator.locks.request) {
			navigator.locks.request(name, {ifAvailable: true}, function (lock) {
				if (!lock) { blocked(); return; }
				owner();
				return new Promise(function () {});   // held until the tab closes
			}).catch(owner);
		} else if (window.BroadcastChannel) {
			var ch = new BroadcastChannel(name);
			ch.onmessage = function (e) {
				if (e.data === 'ping' && window.qmInstance === 'owner') ch.postMessage('pong');
				else if (e.data === 'pong' && window.qmInstance === 'pending') blocked();
			};
			ch.postMessage('ping');
			setTimeout(function () { if (window.qmInstance === 'pending') owner(); }, 400);
		} else {
			owner();
		}
	""", [blocked_text])


## Web: the game is open in another tab, so this one must not write to user:// (see claim_single_instance).
static func writes_blocked() -> bool:
	return _writes_blocked


## Web: while `on`, closing or reloading the tab asks the browser's "leave site?" question, since a tab has no
## close dialog of its own.
static func set_leave_guard(on: bool) -> void:
	if not is_web():
		return
	_js_call("on", """
		window.qmUnsaved = on;
		if (window.qmLeaveGuard) return;
		window.qmLeaveGuard = true;
		window.addEventListener('beforeunload', function (e) {
			if (!window.qmUnsaved) return;
			e.preventDefault();
			e.returnValue = '';
		});
	""", [on])


## Calls `on_done(true)` once the save just written to `dir_name` (SaveManager.last_saved_*) is really on disk, or
## `on_done(false)` if that can't be confirmed within 30 s. Desktop: at once, the files are written when save()
## returns. Web: user:// lives in memory and the browser copies it to IndexedDB some seconds later, so a tab closed
## in between keeps the previous save; this polls IndexedDB ('/userfs', store 'FILE_DATA') until the save's
## meta.json there has the same saved_at and save_id.
## A newer save to the same folder overwrites that meta.json before an older wait can find its own: the older waits
## then follow the newer save (which holds everything they held) instead of timing out with a false warning.
static func confirm_saved(dir_name: String, saved_at: String, save_id: String, on_done: Callable) -> void:
	if not is_web():
		on_done.call(true)
		return
	_save_seq += 1
	var wait := SaveWait.new()
	wait.dir = dir_name
	for s in _save_waits.keys():
		if _save_waits[s].dir == dir_name:
			wait.done.append_array(_save_waits[s].done)
			_save_waits.erase(s)
	wait.done.append(on_done)
	_save_waits[_save_seq] = wait
	if _save_callback == null:
		_save_callback = JavaScriptBridge.create_callback(func(args: Array):
			var seq := int(args[0]) if args.size() > 0 else 0
			var synced: SaveWait = _save_waits.get(seq)
			_save_waits.erase(seq)
			if synced == null:
				return
			var ok := args.size() > 1 and str(args[1]) == "ok"
			for cb in synced.done:
				if cb.is_valid():
					cb.call(ok))
		JavaScriptBridge.get_interface("window").qmOnSaveSynced = _save_callback
	_js_call("seq, suffix, at, id", """
		var t0 = Date.now();
		function done(ok) { window.qmOnSaveSynced(seq, ok ? 'ok' : 'timeout'); }
		function retry() {
			if (Date.now() - t0 > 30000) done(false);
			else setTimeout(check, 700);
		}
		function check() {
			var req;
			try { req = indexedDB.open('/userfs'); } catch (e) { retry(); return; }
			req.onerror = retry;
			req.onsuccess = function () {
				var db = req.result, found = false;
				function fin() { db.close(); if (found) done(true); else retry(); }
				try {
					var store = db.transaction('FILE_DATA', 'readonly').objectStore('FILE_DATA');
					var keys = store.getAllKeys();
					keys.onerror = fin;
					keys.onsuccess = function () {
						var key = null;
						keys.result.forEach(function (k) { if (String(k).endsWith(suffix)) key = k; });
						if (key === null) { fin(); return; }
						var get = store.get(key);
						get.onerror = fin;
						get.onsuccess = function () {
							try {
								var m = JSON.parse(new TextDecoder().decode(get.result.contents));
								found = m.saved_at === at && String(m.save_id || '') === id;
							} catch (e) {}
							fin();
						};
					};
				} catch (e) { fin(); }
			};
		}
		check();
	""", [_save_seq, "/saves/" + dir_name + "/meta.json", saved_at, save_id])


## Hands a file to the player: a download in the browser, a "save as" dialog on desktop.
static func offer_file(parent: Node, bytes: PackedByteArray, file_name: String) -> void:
	if is_web():
		JavaScriptBridge.download_buffer(bytes, file_name, "application/octet-stream")
		return
	var dlg := _file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dlg.current_file = file_name
	dlg.file_selected.connect(func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bytes)
			f.close())
	parent.add_child(dlg)
	dlg.popup_centered_ratio(0.6)


## Web: asks the accounts service who is signed in (GET /api/me, same-origin cookie) and calls `on_done` with the
## reply as a Dictionary ({logged_in, username, country, locale, profile_complete}); {} if there is no service (a
## local test server) or on desktop, where there are no accounts.
static func fetch_viewer(on_done: Callable) -> void:
	if not is_web():
		on_done.call({})
		return
	_viewer_callback = JavaScriptBridge.create_callback(func(args: Array):
		# No service (or an error) answers with an empty body: nothing to parse, and no "Parse JSON failed" in the log.
		var raw := str(args[0]).strip_edges() if not args.is_empty() else ""
		var data = JSON.parse_string(raw) if raw.begins_with("{") else null
		on_done.call(data if data is Dictionary else {}))
	JavaScriptBridge.get_interface("window").qmOnViewer = _viewer_callback
	JavaScriptBridge.eval("""fetch('/api/me', {credentials: 'same-origin', cache: 'no-store'})
		.then(function (r) { return r.ok ? r.text() : ''; })
		.then(function (t) { window.qmOnViewer(t); })
		.catch(function () { window.qmOnViewer(''); });""", true)


## Web: sends a finished season of the manager's career to the accounts service (POST /api/career/season). Fire
## and forget: no answer is awaited and a failure (no service, signed out, offline) is silent. Does nothing on
## desktop.
static func report_season(payload: Dictionary) -> void:
	if not is_web():
		return
	_js_call("body", """
		fetch('/api/career/season', {method: 'POST', credentials: 'same-origin', cache: 'no-store',
			headers: {'Content-Type': 'application/json'}, body: body}).catch(function () {});
	""", [JSON.stringify(payload)])


## Web: a loading card drawn by the page itself (HTML + CSS) over the game while a long task runs. The browser
## has a single thread for the game, so Godot cannot draw anything until the task ends (its own snitch would freeze);
## CSS transform animations run on the browser's compositor and keep moving meanwhile. Call hide_busy() after.
## Does nothing on desktop, where the work runs on a thread and Godot's own overlay animates.
static func show_busy(text: String, detail: String = "") -> void:
	if not is_web():
		return
	_js_call("text, detail", """
		var box = document.getElementById('qm-busy');
		if (!box) {
			var css = document.createElement('style');
			css.id = 'qm-busy-css';
			css.textContent = '#qm-busy{position:fixed;inset:0;z-index:10;display:flex;align-items:center;justify-content:center;background:rgba(20,13,9,.55)}'
				+ '#qm-busy .card{background:#f3ead3;border:1px solid #b89a5e;border-radius:6px;padding:26px 40px;text-align:center;font:600 17px Georgia,serif;color:#3a2a1c;box-shadow:0 8px 30px rgba(0,0,0,.4)}'
				+ '#qm-busy .detail{font:400 13px Georgia,serif;color:#6b5840;margin-top:6px}'
				+ '#qm-busy .sky{position:relative;width:120px;height:56px;margin:0 auto 14px}'
				+ '#qm-busy .snitch{position:absolute;left:44px;top:16px;width:32px;height:24px;animation:qmfly 2.6s ease-in-out infinite;will-change:transform}'
				+ '#qm-busy .ball{position:absolute;left:9px;top:5px;width:14px;height:14px;border-radius:50%;background:radial-gradient(circle at 35% 35%,#fff3b0,#e2b33c 45%,#9c6b12)}'
				+ '#qm-busy .wing{position:absolute;top:2px;width:13px;height:9px;background:#fbf8ee;border:1px solid #c9bfa6;border-radius:100% 0 100% 0;will-change:transform}'
				+ '#qm-busy .wing.l{left:-3px;transform-origin:100% 100%;animation:qmflapl .16s ease-in-out infinite alternate}'
				+ '#qm-busy .wing.r{left:22px;transform-origin:0 100%;animation:qmflapr .16s ease-in-out infinite alternate;border-radius:0 100% 0 100%}'
				+ '@keyframes qmfly{0%{transform:translate(-40px,6px)}25%{transform:translate(0,-12px)}50%{transform:translate(40px,4px)}75%{transform:translate(0,14px)}100%{transform:translate(-40px,6px)}}'
				+ '@keyframes qmflapl{from{transform:rotate(18deg)}to{transform:rotate(-28deg)}}'
				+ '@keyframes qmflapr{from{transform:rotate(-18deg)}to{transform:rotate(28deg)}}';
			document.head.appendChild(css);
			box = document.createElement('div');
			box.id = 'qm-busy';
			box.innerHTML = '<div class="card"><div class="sky"><div class="snitch"><div class="wing l"></div><div class="wing r"></div><div class="ball"></div></div></div><div class="text"></div><div class="detail"></div></div>';
			document.body.appendChild(box);
		}
		box.querySelector('.text').textContent = text;
		box.querySelector('.detail').textContent = detail;
		box.style.display = 'flex';
	""", [text, detail])


static func hide_busy() -> void:
	if is_web():
		JavaScriptBridge.eval("(function () { var b = document.getElementById('qm-busy'); if (b) b.style.display = 'none'; })();", true)


## Web: leaves the game for the account page of the accounts service (profile, data export, sign out).
static func open_account_page() -> void:
	if is_web():
		JavaScriptBridge.eval("window.location.assign('/account');", true)


## Lets the player pick a save file; calls `on_bytes(bytes)` with its contents. Nothing is called if they cancel.
static func pick_file(parent: Node, on_bytes: Callable) -> void:
	if is_web():
		_js_callback = JavaScriptBridge.create_callback(func(args: Array):
			on_bytes.call(Marshalls.base64_to_raw(str(args[0]))))
		JavaScriptBridge.get_interface("window").qmOnSaveFile = _js_callback
		# The MIME types keep the file selectable on iOS, which greys out unknown extensions.
		_js_call("ext, max_bytes", """
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.' + ext + ',application/zip,application/octet-stream';
			input.onchange = function () {
				var file = input.files[0];
				if (!file) return;
				if (file.size > max_bytes) { window.qmOnSaveFile(''); return; }
				var reader = new FileReader();
				reader.onload = function () {
					var b = new Uint8Array(reader.result), s = '';
					for (var i = 0; i < b.length; i += 0x8000) s += String.fromCharCode.apply(null, b.subarray(i, i + 0x8000));
					window.qmOnSaveFile(btoa(s));
				};
				reader.onerror = reader.onabort = function () { window.qmOnSaveFile(''); };
				reader.readAsArrayBuffer(file);
			};
			input.click();
		""", [SAVE_EXT, SaveManager.MAX_IMPORT_BYTES])
		return
	var dlg := _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dlg.file_selected.connect(func(path: String): on_bytes.call(FileAccess.get_file_as_bytes(path)))
	parent.add_child(dlg)
	dlg.popup_centered_ratio(0.6)


static func _file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dlg := FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = mode
	dlg.use_native_dialog = true
	dlg.filters = PackedStringArray(["*.%s" % SAVE_EXT])
	dlg.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	# A native dialog never shows the Window itself, so visibility_changed doesn't fire: free it when the player
	# picks a file or cancels (queue_free is deferred, so the caller's file_selected handler still runs). The
	# visibility check covers the non-native fallback.
	dlg.file_selected.connect(func(_path: String): dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	return dlg
