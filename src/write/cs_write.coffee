(->
  origin = chrome.extension.getURL("").slice(0, -1)

  exec = (javascript) ->
    script = document.createElement("script")
    script.innerHTML = javascript
    document.body.appendChild(script)

  send_message_ping = ->
    exec """
      parent.postMessage(JSON.stringify({type : "ping"}), "#{origin}");
    """

  send_message_success = ->
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
    if ///^http://\w+\.2ch\.net/test/read\.cgi/\w+/\d+/1\?///.test(location.href)
      form = document.createElement("form")
      form.action = "/test/bbs.cgi"
      form.method = "POST"

      arg = app.url.parse_query(location.href)
      form_data =
        submit: "書きこむ"
        time: Math.floor(Date.now() / 1000) - 60
        bbs: location.href.split("/")[5]
        key: location.href.split("/")[6]
        FROM: arg.rcrx_name
        mail: arg.rcrx_mail

      for key, val of form_data
        input = document.createElement("input")
        input.name = key
        input.setAttribute("value", val)
        form.appendChild(input)

      textarea = document.createElement("textarea")
      textarea.name = "MESSAGE"
      textarea.value = arg.rcrx_message
      form.appendChild(textarea)

      form.__proto__.submit.call(form)

    else if ///^http://\w+\.2ch\.net/test/bbs\.cgi///.test(location.href)
      if /書きこみました/.test(document.title)
        send_message_success()
      else if /確認/.test(document.title)
        send_message_confirm()
      else if /ＥＲＲＯＲ/.test(document.title)
        send_message_error()

    else if ///^http://jbbs\.livedoor\.jp/bbs/read\.cgi/\w+/\d+/\d+/1\?///.test(location.href)
      tmp = location.href.split("/")

      form = document.createElement("form")
      form.action = "/bbs/write.cgi/#{tmp[5]}/#{tmp[6]}/#{tmp[7]}/"
      form.method = "POST"

      arg = app.url.parse_query(location.href)

      form_data =
        TIME: Math.floor(Date.now() / 1000) - 60
        DIR: tmp[5]
        BBS: tmp[6]
        KEY: tmp[7]
        NAME: arg.rcrx_name
        MAIL: arg.rcrx_mail

      for key, val of form_data
        input = document.createElement("input")
        input.name = key
        input.setAttribute("value", val)
        form.appendChild(input)

      textarea = document.createElement("textarea")
      textarea.name = "MESSAGE"
      textarea.value = arg.rcrx_message
      form.appendChild(textarea)

      form.submit()

    else if ///^http://jbbs\.livedoor\.jp/bbs/write.cgi/\w+/\d+/\d+/$///.test(location.href)
      if /書きこみました/.test(document.title)
        send_message_success()
      else if /ERROR/.test(document.title)
        send_message_error()

    #p2
    else if ///^http://w\d+\.p2\.2ch\.net/p2/post_form\.php///.test(location.href)
      if form = document.getElementById("resform")
        console.log form

        arg = app.url.parse_query(location.href)
        form.FROM.value = arg.rcrx_name
        form.mail.value = arg.rcrx_mail
        form.MESSAGE.value = arg.rcrx_message
        form.__proto__.submit.call(form)

      else
        send_message_error("p2にログインしていません。ログインしていてもこのメッセージが出る場合、p2サーバーの設定が間違っている可能性が有ります。その場合はオプションページから修正して下さい。")

    else if ///^http://w\d+\.p2\.2ch\.net/p2/post\.php///.test(location.href)
      if /書きこみました/.test(document.title)
        send_message_success()
      else if document.querySelector("meta[http-equiv=\"refresh\"]")
        send_message_error(document.body.innerText)
        location.href = "about:blank"
      else
        send_message_error()

  boot = ->
    window.addEventListener "message", (e) ->
      if e.origin is origin and e.data is "write_iframe_pong"
        main()
      return

    send_message_ping()

  setTimeout(boot, 0)
)()
