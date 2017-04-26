app.read_state = {}

app.read_state._url_filter = (original_url) ->
  original_url = app.url.fix(original_url)
  scheme = app.url.getScheme(original_url)

  original: original_url
  replaced: original_url
    .replace(/// ^https?://\w+\.2ch\.net/ ///, "#{scheme}://*.2ch.net/")
  original_origin: original_url
    .replace(/// ^(https?://\w+\.2ch\.net)/.* ///, "$1")
  replaced_origin: "#{scheme}://*.2ch.net"

do ->
  app.read_state._openDB = new Promise( (resolve, reject) ->
    req = indexedDB.open("ReadState", 1)
    req.onerror = (e) ->
      app.critical_error("既読情報管理システムの起動に失敗しました")
      reject(e)
      return
    req.onupgradeneeded = (e) ->
      db = e.target.result
      objStore = db.createObjectStore("ReadState", keyPath: "url")
      objStore.createIndex("board_url", "board_url", unique: false)
      e.target.transaction.oncomplete = ->
        resolve(db)
      return
    req.onsuccess = (e) ->
      resolve(e.target.result)
      return
    return
  )

app.read_state.set = (read_state) ->
  if not read_state? or
      typeof read_state isnt "object" or
      typeof read_state.url isnt "string" or
      not Number.isFinite(read_state.last) or
      not Number.isFinite(read_state.read) or
      not Number.isFinite(read_state.received)
    app.log("error", "app.read_state.set: 引数が不正です", arguments)
    return Promise.reject()

  read_state = app.deep_copy(read_state)

  url = app.read_state._url_filter(read_state.url)
  read_state.url = url.replaced
  board_url = app.url.threadToBoard(url.original)
  read_state.board_url = app.read_state._url_filter(board_url).replaced

  return app.read_state._openDB.then( (db) =>
    return new Promise( (resolve, reject) =>
      req = db
        .transaction("ReadState", "readwrite")
        .objectStore("ReadState")
        .put(read_state)
      req.onsuccess = (e) ->
        delete read_state.board_url
        read_state.url = read_state.url.replace(url.replaced, url.original)
        app.message.send("read_state_updated", {board_url, read_state})
        resolve()
        return
      req.onerror = (e) ->
        app.log("error", "app.read_state.set: トランザクション失敗")
        reject(e)
        return
      return
    )
  )

app.read_state.get = (url) ->
  if app.assert_arg("app.read_state.get", ["string"], arguments)
    return Promise.reject()

  url = app.read_state._url_filter(url)

  return app.read_state._openDB.then( (db) =>
    new Promise( (resolve, reject) =>
      req = db
        .transaction("ReadState")
        .objectStore("ReadState")
        .get(url.replaced)
      req.onsuccess = (e) =>
        data = app.deep_copy(e.target.result)
        data.url = url.original
        resolve(data)
        return
      req.onerror = (e) ->
        app.log("error", "app.read_state.get: トランザクション中断")
        reject(e)
        return
      return
    )
  )

app.read_state.getAll = ->
  return app.read_state._openDB.then( (db) ->
    return new Promise( (resolve, reject) ->
      req = db
        .transaction("ReadState")
        .objectStore("ReadState")
        .getAll()
      req.onsuccess = (e) ->
        resolve(event.target.result)
        return
      req.onerror = (e) ->
        app.log("error", "app.read_state.getAll: トランザクション中断")
        reject(e)
        return
      return
    )
  )

app.read_state.get_by_board = (url) ->
  if app.assert_arg("app.read_state.get_by_board", ["string"], arguments)
    return Promise.reject()

  url = app.read_state._url_filter(url)

  return app.read_state._openDB.then( (db) ->
    return new Promise( (resolve, reject) ->
      req = db
        .transaction("ReadState")
        .objectStore("ReadState")
        .index("board_url")
        .getAll(IDBKeyRange.only(url.replaced))
      req.onsuccess = (e) ->
        data = e.target.result
        for key, val of data
          data[key].url = val.url.replace(url.replaced_origin, url.original_origin)
        resolve(data)
        return
      req.onerror = (e) ->
        app.log("error", "app.read_state.get_by_board: トランザクション中断")
        reject(e)
        return
      return
    )
  )

app.read_state.remove = (url) ->
  if app.assert_arg("app.read_state.remove", ["string"], arguments)
    return Promise.reject()

  url = app.read_state._url_filter(url)

  return app.read_state._openDB.then( (db) ->
    return new Promise( (resolve, reject) ->
      req = db
        .transaction("ReadState", "readwrite")
        .objectStore("ReadState")
        .delete(url.repalced)
      req.onsuccess = (e) ->
        app.message.send("read_state_removed", url: url.original)
        resolve()
        return
      req.onerror = (e) ->
        app.log("error", "app.read_state.remove: トランザクション中断")
        reject(e)
        return
      return
    )
  )

app.read_state.clear = ->
  return app.read_state._openDB.then( (db) ->
    return new Promise( (resolve, reject) ->
      req = db
        .transaction("ReadState", "readwrite")
        .objectStore("ReadState")
        .clear()
      req.onsuccess = (e) ->
        resolve()
        return
      req.onerror = (e) ->
        app.log("error", "app.read_state.clear: トランザクション中断")
        reject(e)
        return
      return
    )
  )
