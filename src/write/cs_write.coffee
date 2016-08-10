do ->
  origin = chrome.extension.getURL("").slice(0, -1)

  submitThreadFlag = false

  exec = (javascript) ->
    script = document.createElement("script")
    script.innerHTML = javascript
    document.body.appendChild(script)

  send_message_ping = ->
    exec """
      parent.postMessage(JSON.stringify({type : "ping"}), "#{origin}");
    """

  send_message_success = ->
    if submitThreadFlag
      exec """
        if((location.href.indexOf("2ch.net") !== -1) || (location.href.indexOf("bbspink.com") !== -1) || (location.href.indexOf("open2ch.net") !== -1)) {
          metas = document.getElementsByTagName("meta");
          for(var i = 0; i < metas.length; i++) {
            if(metas[i].getAttribute("http-equiv") === "refresh") {
              jumpurl = metas[i].getAttribute("content");
              break;
            }
          }
        } else if (location.href.indexOf("2ch.sc") !== -1) {
          as = document.getElementsByTagName("a");
          jumpurl = as[0].href;
        } else {
          jumpurl = ""
        }
        parent.postMessage(JSON.stringify({
          type : "success",
          key: jumpurl
        }), "#{origin}");
      """
    else
      exec """
        parent.postMessage(JSON.stringify({type : "success"}), "#{origin}");
      """

  send_message_confirm = ->
    exec """
      parent.postMessage(JSON.stringify({type : "confirm"}), "#{origin}");
    """

  send_message_error = (message) ->
    if typeof message is "string"
      exec """
        parent.postMessage(JSON.stringify({
          type: "error",
          message: "#{message.replace(/\"/g, "&quot;")}"
        }), "#{origin}");
      """
    else
      exec """
        parent.postMessage(JSON.stringify({type : "error"}), "#{origin}");
      """

  main = ->
    #2ch投稿確認
    if ///^http://\w+\.(2ch\.net|bbspink\.com|2ch\.sc|open2ch\.net)/test/bbs\.cgi///.test(location.href)
      if /書きこみました/.test(document.title)
        send_message_success()
      else if /確認/.test(document.title)
        setTimeout(send_message_confirm , 1000 * 6)
      else if /ＥＲＲＯＲ/.test(document.title)
        send_message_error()

    #したらば投稿確認
    else if ///^http://jbbs\.shitaraba\.net/bbs/write.cgi/\w+/\d+/(?:\d+|new)/$///.test(location.href)
      if /書きこみました/.test(document.title)
        send_message_success()
      else if /ERROR|スレッド作成規制中/.test(document.title)
        send_message_error()

  boot = ->
    window.addEventListener "message", (e) ->
      if e.origin is origin
        if e.data is "write_iframe_pong"
          main()
        else if e.data is "write_iframe_pong:thread"
          submitThreadFlag = true
          main()
      return

    send_message_ping()

  setTimeout(boot, 0)
