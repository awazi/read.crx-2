window.UI ?= {}

###*
@namespace UI
@class ThreadContent
@constructor
@param {String} URL
@param {Element} container
@requires MediaContainer
###
class UI.ThreadContent
  constructor: (@url, @container) ->
    ###*
    @property idIndex
    @type Object
    ###
    @idIndex = new Map()

    ###*
    @property slipIndex
    @type Object
    ###
    @slipIndex = new Map()

    ###*
    @property tripIndex
    @type Object
    ###
    @tripIndex = new Map()

    ###*
    @property repIndex
    @type Object
    ###
    @repIndex = new Map()

    ###*
    @property harmImgIndex
    @type Array
    ###
    @harmImgIndex = new Set()

    ###*
    @property oneId
    @type null | String
    ###
    @oneId = null

    ###*
    @property _lastScrollInfo
    @type Object
    @private
    ###
    @_lastScrollInfo =
      resNum: 0
      animate: false
      offset: 0

    ###*
    @property _timeoutID
    @type Number
    @private
    ###
    @_timeoutID = 0

    ###*
    @property _existIdAtFirstRes
    @type Boolean
    @private
    ###
    @_existIdAtFirstRes = false

    ###*
    @property _existSlipAtFirstRes
    @type Boolean
    @private
    ###
    @_existSlipAtFirstRes = false

    ###*
    @property _hiddenSelectors
    @type
    @private
    ###
    @_hiddenSelectors = null

    try
      @harmfulReg = new RegExp(app.config.get("image_blur_word"))
      @findHarmfulFlag = true
    catch e
      app.message.send("notify",
        html: """
          画像ぼかしの正規表現を読み込むのに失敗しました
          画像ぼかし機能は無効化されます
        """
        background_color: "red"
      )
      @findHarmfulFlag = false

    return

  ###*
  @method _reScrollTo
  @private
  ###
  _reScrollTo: ->
    @scrollTo(@_lastScrollInfo.resNum, @_lastScrollInfo.animate, @_lastScrollInfo.offset, true)
    return

  ###*
  @method _isHidden
  @private
  ###
  _isHidden: (ele) ->
    unless @_hiddenSelectors?
      @_hiddenSelectors = []
      css = $$.I("user_css").sheet.cssRules
      for {selectorText, style, type} in css when type is 1
        if style.display is "none"
          @_hiddenSelectors.push(selectorText)
    return (
      (ele.hasClass("ng") and not app.config.isOn("display_ng")) or
      @_hiddenSelectors.some( (selector) ->
        return ele.matches(selector)
      )
    )

  ###*
  @method _loadNearlyImages
  @param {Number} resNum
  @param {Number} [offset=0]
  @return {Boolean} loadFlag
  ###
  _loadNearlyImages: (resNum, offset = 0) ->
    loadFlag = false
    target = @container.children[resNum - 1]

    {offsetHeight: containerHeight, scrollHeight: containerScroll} = @container
    viewTop = target.offsetTop
    viewTop += offset if offset < 0
    viewBottom = viewTop + containerHeight
    if viewBottom > containerScroll
      viewBottom = containerScroll
      viewTop = viewBottom - containerHeight

    # 遅延ロードの解除
    loadImageByElement = (targetElement) =>
      for media in targetElement.$$("img[data-src], video[data-src]")
        loadFlag = true
        media.dispatchEvent(new Event("immediateload", {"bubbles": true}))
      return

    # 表示範囲内の要素をスキャンする
    # (上方)
    tmpTarget = target
    while (
      tmpTarget and
      (
        (isHidden = @_isHidden(tmpTarget)) or
        tmpTarget.offsetTop + tmpTarget.offsetHeight > viewTop
      )
    )
      loadImageByElement(tmpTarget) unless isHidden
      tmpTarget = tmpTarget.prev()
    # (下方)
    tmpTarget = target.next()
    while (
      tmpTarget and
      (
        (isHidden = @_isHidden(tmpTarget)) or
        tmpTarget.offsetTop < viewBottom
      )
    )
      loadImageByElement(tmpTarget) unless isHidden
      tmpTarget = tmpTarget.next()

    # 遅延スクロールの設定
    if (
      (loadFlag or @_timeoutID isnt 0) and
      not app.config.isOn("image_height_fix")
    )
      clearTimeout(@_timeoutID) if @_timeoutID isnt 0
      delayScrollTime = parseInt(app.config.get("delay_scroll_time"))
      @_timeoutID = setTimeout( =>
        @_timeoutID = 0
        @_reScrollTo()
      , delayScrollTime)

    return loadFlag

  ###*
  @method scrollTo
  @param {Element | Number} target
  @param {Boolean} [animate=false]
  @param {Number} [offset=0]
  @param {Boolean} [rerun=false]
  ###
  scrollTo: (target, animate = false, offset = 0, rerun = false) ->
    if typeof target is "number"
      resNum = target
    else
      resNum = +target.C("num")[0].textContent
    @_lastScrollInfo.resNum = resNum
    @_lastScrollInfo.animate = animate
    @_lastScrollInfo.offset = offset
    loadFlag = false

    target = @container.children[resNum - 1]

    # 検索中で、ターゲットが非ヒット項目で非表示の場合、スクロールを中断
    if (
      target and
      @container.hasClass("searching") and
      not target.hasClass("search_hit")
    )
      target = null

    # もしターゲットがNGだった場合、その直前/直後の非NGレスをターゲットに変更する
    if target and @_isHidden(target)
      replaced = target
      while (replaced = replaced.prev())
        unless @_isHidden(replaced)
          target = replaced
          break
        if !replaced?
          replaced = target
          while (replaced = replaced.next())
            unless @_isHidden(replaced)
              target = replaced
              break

    if target
      # 前後に存在する画像を事前にロードする
      loadFlag = @_loadNearlyImages(resNum, offset) unless rerun

      # offsetが比率の場合はpxを求める
      if 0 < offset < 1
        offset = Math.round(target.offsetHeight * offset)

      # 遅延スクロールの設定
      if (
        (loadFlag or @_timeoutID isnt 0) and
        not app.config.isOn("image_height_fix")
      )
        @container.scrollTop = target.offsetTop + offset
        return
      return if rerun and @container.scrollTop is target.offsetTop + offset

      # スクロールの実行
      if animate
        do =>
          @container.dispatchEvent(new Event("scrollstart"))

          to = target.offsetTop + offset
          change = (to - @container.scrollTop)/15
          min = Math.min(to-change, to+change)
          max = Math.max(to-change, to+change)
          requestAnimationFrame(_scrollInterval = =>
            before = @container.scrollTop
            # 画像のロードによる座標変更時の補正
            if to isnt target.offsetTop + offset
              to = target.offsetTop + offset
              min = Math.min(to-change, to+change)
              max = Math.max(to-change, to+change)
            # 例外発生時の停止処理
            if (
              (change > 0 and @container.scrollTop > max) or
              (change < 0 and @container.scrollTop < min)
            )
              @container.scrollTop = to
              @container.dispatchEvent(new Event("scrollfinish"))
              return
            # 正常時の処理
            if min <= @container.scrollTop <= max
              @container.scrollTop = to
              @container.dispatchEvent(new Event("scrollfinish"))
              return
            else
              @container.scrollTop += change
            if @container.scrollTop is before
              @container.dispatchEvent(new Event("scrollfinish"))
              return
            requestAnimationFrame(_scrollInterval)
            return
          )
      else
        @container.scrollTop = target.offsetTop + offset
    return

  ###*
  @method getRead
  @return {Number} 現在読んでいると推測されるレスの番号
  ###
  getRead: ->
    {left, height, bottom} = @container.getBoundingClientRect()
    y = bottom - 1
    res = document.elementFromPoint(left, y)

    while true
      if res?
        if res.closest("article")?
          resNum = parseInt(res.closest("article").C("num")[0].textContent)
          # 最後のレスがすべて表示されているとき
          if (
            (resNum is @container.child().length) and
            (y+1 < height)
          )
            return resNum
          return Math.max(resNum-1, 1)
        else if res is @container
          return @container.child().length
      else
        return 1
      y -= res.getBoundingClientRect().height
      res = document.elementFromPoint(left, y)
    return

  ###*
  @method getDisplay
  @return {Object} 現在表示していると推測されるレスの番号とオフセット
  ###
  getDisplay: ->
    containerTop = @container.scrollTop
    containerBottom = containerTop + @container.clientHeight
    resRead = {resNum: 1, offset: 0, bottom: false}

    # 既に画面の一番下までスクロールしている場合
    # (いつのまにか位置がずれていることがあるので余裕を設ける)
    if containerBottom >= @container.scrollHeight - 60
      resRead.bottom = true

    # スクロール位置のレスを抽出
    {top, left} = @container.getBoundingClientRect()
    res = document.elementFromPoint(left, top)
    if res?.closest("article")?
      res = res.closest("article")
      {top: resTop, height: resHeight} = res.getBoundingClientRect()
      resRead.resNum = parseInt(res.C("num")[0].textContent)
      resRead.offset = (top - resTop) / resHeight
    return resRead

  ###*
  @method getSelected
  @return {Element|null}
  ###
  getSelected: ->
    return @container.$("article.selected")

  ###*
  @method select
  @param {Element | Number} target
  @param {Boolean} [preventScroll = false]
  @param {Boolean} [animate = false]
  @param {Number} [offset = 0]
  ###
  select: (target, preventScroll = false, animate = false, offset = 0) ->
    @container.$("article.selected")?.removeClass("selected")

    if typeof target is "number"
      target = @container.$("article:nth-child(#{target}), article:last-child")

    return unless target

    target.addClass("selected")
    if not preventScroll
      @scrollTo(target, animate, offset)
    return

  ###*
  @method clearSelect
  ###
  clearSelect: ->
    @getSelected()?.removeClass("selected")
    return

  ###*
  @method selectNext
  @param {number} [repeat = 1]
  ###
  selectNext: (repeat = 1) ->
    current = @getSelected()
    containerHeight = @container.offsetHeight

    if current
      {top, bottom} = current.getBoundingClientRect()
      # 現在選択されているレスが表示範囲外だった場合、それを無視する
      if top >= containerHeight or bottom <= 0
        current = null

    unless current
      @select(@container.child()[@getRead() - 1], true)
    else
      target = current

      for [0...repeat]
        prevTarget = target

        {bottom: targetBottom} = target.getBoundingClientRect()
        if targetBottom <= containerHeight and target.next()
          target = target.next()

          while target and @_isHidden(target)
            target = target.next()

        if not target
          target = prevTarget
          break

        {bottom: targetBottom, height: targetHeight} = target.getBoundingClientRect()
        if containerHeight < targetBottom
          if targetHeight >= containerHeight
            @container.scrollTop += containerHeight * 0.5
          else
            @container.scrollTop += (
              targetBottom -
              containerHeight +
              10
            )
        else if not target.next()
          @container.scrollTop += containerHeight * 0.5
          if target is prevTarget
            break

      if target and target isnt current
        @select(target, true)
    return

  ###*
  @method selectPrev
  @param {number} [repeat = 1]
  ###
  selectPrev: (repeat = 1) ->
    current = @getSelected()
    containerHeight = @container.offsetHeight

    if current
      {top, bottom} = current.getBoundingClientRect()
      # 現在選択されているレスが表示範囲外だった場合、それを無視する
      if top >= containerHeight or bottom <= 0
        current = null

    unless current
      @select(@container.child()[@getRead() - 1], true)
    else
      target = current

      for [0...repeat]
        prevTarget = target

        {top: targetTop, height: targetHeight} = target.getBoundingClientRect()
        if 0 <= targetTop and target.prev()
          target = target.prev()

          while target and @_isHidden(target)
            target = target.prev()

        if not target
          target = prevTarget
          break

        {top: targetTop, height: targetHeight} = target.getBoundingClientRect()
        if targetTop < 0
          if targetHeight >= containerHeight
            @container.scrollTop -= containerHeight * 0.5
          else
            @container.scrollTop = target.offsetTop - 10
        else if not target.prev()
          @container.scrollTop -= containerHeight * 0.5
          if target is prevTarget
            break

      if target and target isnt current
        @select(target, true)
    return

  ###*
  @method addItem
  @param {Object | Array}
  ###
  addItem: (items) ->
    return new Promise( (resolve, reject) =>
      items = [items] unless Array.isArray(items)

      unless items.length > 0
        resolve()
        return

      resNum = @container.child().length

      app.WriteHistory.getByUrl(@url).then( (writtenRes) =>
        html = ""

        for res in items
          resNum++

          res.num = resNum
          res.class = []
          res.attr = []
          scheme = app.URL.getScheme(@url)

          res = app.ReplaceStrTxt.do(@url, document.title, res)

          if /(?:\u3000{5}|\u3000\u0020|[^>]\u0020\u3000)(?!<br>|$)/i.test(res.message)
            res.class.push("aa")

          for writtenHistory in writtenRes when writtenHistory.res is resNum
            res.class.push("written")
            break

          articleHtml = "<header>"

          #.num
          articleHtml += """<span class="num">#{resNum}</span> """

          #.name
          articleHtml += """<span class="name"""
          if /^\s*(?:&gt;|\uff1e){0,2}([\d\uff10-\uff19]+(?:[\-\u30fc][\d\uff10-\uff19]+)?(?:\s*,\s*[\d\uff10-\uff19]+(?:[\-\u30fc][\d\uff10-\uff19]+)?)*)\s*$/.test(res.name)
            articleHtml += " name_anchor"
          tmp = (
            res.name
              .replace(/<(?!(?:\/?b|\/?font(?: color="?[#a-zA-Z0-9]+"?)?)>)/g, "&lt;")
              .replace(/<\/b>\(([^<>]+? [^<>]+?)\)<b>$/, ($0, $1) =>
                res.slip = $1

                @slipIndex.set($1, new Set()) unless @slipIndex.has($1)
                @slipIndex.get($1).add(resNum)

                return ""
               )
              .replace(/<\/b>(◆[^<>]+?) <b>/, ($0, $1) =>
                res.trip = $1

                @tripIndex.set($1, new Set()) unless @tripIndex.has($1)
                @tripIndex.get($1).add(resNum)

                return """<span class="trip">#{$1}</span>"""
              )
              .replace(/<\/b>(.*?)<b>/g, """<span class="ob">$1</span>""")
              .replace(/&lt;span.*?>(.*?)&lt;\/span>/g, "<span class=\"ob\">$1</span>")
              .replace(/&lt;small.*?>(.*?)&lt;\/small>/g, "<small>$1</small>")
          )
          articleHtml += """">#{tmp}</span>"""

          #.mail
          tmp = res.mail.replace(/<.*?(?:>|$)/g, "")
          articleHtml += """ [<span class="mail">#{tmp}</span>] """

          #.other
          tmp = (
            res.other
              #be
              .replace(/<\/div><div class="be .*?"><a href="(https?:\/\/be\.2ch\.net\/user\/\d+?)".*?>(.*?)<\/a>/, "<a class=\"beid\" href=\"$1\" target=\"_blank\">$2</a>")
              #タグ除去
              .replace(/<(?!(?:a class="beid".*?|\/a)>).*?(?:>|$)/g, "")
              #.id
              .replace(/(?:^| |(\d))(ID:(?!\?\?\?)[^ <>"']+|発信元:\d+.\d+.\d+.\d+)/, ($0, $1, $2) =>
                fixedId = $2.replace(/\u25cf$/, "") #末尾●除去

                res.id = fixedId

                if resNum is 1
                  @oneId = fixedId
                  @_existIdAtFirstRes = true

                if fixedId is @oneId
                  res.class.push("one")

                if fixedId.endsWith(".net")
                  res.class.push("net")

                @idIndex.set(fixedId, new Set()) unless @idIndex.has(fixedId)
                @idIndex.get(fixedId).add(resNum)

                return """#{$1 ? ""}<span class="id">#{$2}</span>"""
              )
              #.beid
              .replace /(?:^| )(BE:(\d+)\-[A-Z\d]+\(\d+\))/,
                """<a class="beid" href="#{scheme}://be.2ch.net/test/p.php?i=$3" target="_blank">$1</a>"""
          )
          # slip追加
          if res.slip?
            if (index = tmp.indexOf("<span class=\"id\">")) isnt -1
              tmp = tmp.slice(0, index) + """<span class="slip">SLIP:#{res.slip}</span>""" + tmp.slice(index, tmp.length)
            else
              tmp += """<span class="slip">SLIP:#{res.slip}</span>"""
            if resNum is 1
              @_existSlipAtFirstRes = true

          articleHtml += """<span class="other">#{tmp}</span>"""

          articleHtml += "</header>"

          #文字色
          color = res.message.match(/<font color="(.*?)">/i)

          # id, slip, tripが取り終わったタイミングでNG判定を行う
          # NG判定されるものは、ReplaceStrTxtで置き換え後のテキストなので注意すること
          if ngType = app.NG.checkNGThread(res)
            res.class.push("ng")
            res.attr["ng-type"] = ngType
          else
            guessType = app.URL.guessType(@url)
            if guessType.bbsType is "2ch" and resNum <= 1000
              # idなしをNG
              if (
                app.config.isOn("nothing_id_ng") and !res.id? and
                ((app.config.get("how_to_judgment_id") is "first_res" and @_existIdAtFirstRes) or
                 (app.config.get("how_to_judgment_id") is "exists_once" and @idIndex.size isnt 0))
              )
                res.class.push("ng")
                res.attr["ng-type"] = "IDなし"
              # slipなしをNG
              else if (
                app.config.isOn("nothing_slip_ng") and !res.slip? and
                ((app.config.get("how_to_judgment_id") is "first_res" and @_existSlipAtFirstRes) or
                 (app.config.get("how_to_judgment_id") is "exists_once" and @slipIndex.size isnt 0))
              )
                res.class.push("ng")
                res.attr["ng-type"] = "SLIPなし"

          tmp = (
            res.message
              #imgタグ変換
              .replace(/<img src="([\w]+):\/\/(.*?)".*?>/ig, "$1://$2")
              .replace(/<img src="\/\/(.*?)".*?>/ig, "#{scheme}://$1")
              #Rock54
              .replace(/(?:<small.*?>&#128064;|<i>&#128064;<\/i>)<br>Rock54: (Caution|Warning)\((.+?)\) ?.*?(?:<\/small>)?/ig, "<div class=\"rock54\">&#128064; Rock54: $1($2)</div>")
              #SLIPが変わったという表示
              .replace(/<hr>VIPQ2_EXTDAT: (.+): EXT was configured /i, "<div class=\"slipchange\">VIPQ2_EXTDAT: $1: EXT configure</div>")
              #タグ除去
              .replace(/<(?!(?:br|hr|div class="(?:rock54|slipchange)"|\/?b)>).*?(?:>|$)/ig, "")
              #URLリンク
              .replace(/(h)?(ttps?:\/\/(?!img\.2ch\.net\/(?:ico|emoji|premium)\/[\w\-_]+\.gif)(?:[a-hj-zA-HJ-Z\d_\-.!~*'();\/?:@=+$,%#]|\&(?!gt;)|[iI](?![dD]:)+)+)/g,
                '<a href="h$2" target="_blank">$1$2</a>')
              #Beアイコン埋め込み表示
              .replace(///^(?:\s*sssp|https?)://(img\.2ch\.net/(?:ico|premium)/[\w\-_]+\.gif)\s*<br>///, ($0, $1) =>
                if app.URL.tsld(@url) in ["2ch.net", "bbspink.com", "2ch.sc"]
                  return """<img class="beicon" src="/img/dummy_1x1.webp" data-src="#{scheme}://#{$1}"><br>"""
                return $0
              )
              #エモーティコン埋め込み表示
              .replace(///(?:\s*sssp|https?)://(img\.2ch\.net/emoji/[\w\-_]+\.gif)\s*///g, ($0, $1) =>
                if app.URL.tsld(@url) in ["2ch.net", "bbspink.com", "2ch.sc"]
                  return """<img class="beicon emoticon" src="/img/dummy_1x1.webp" data-src="#{scheme}://#{$1}">"""
                return $0
              )
              #アンカーリンク
              .replace(app.util.Anchor.reg.ANCHOR, ($0) =>
                anchor = app.util.Anchor.parseAnchor($0)

                if anchor.targetCount >= 25
                  disabled = true
                  disabledReason = "指定されたレスの量が極端に多いため、ポップアップを表示しません"
                else if anchor.targetCount is 0
                  disabled = true
                  disabledReason = "指定されたレスが存在しません"
                else
                  disabled = false

                #グロ/死ねの返信レス
                isThatHarmImg = @findHarmfulFlag and @harmfulReg.test(res.message)

                #rep_index更新
                if not disabled
                  for segment in anchor.segments
                    target = segment[0]
                    while target <= segment[1]
                      @repIndex.set(target, new Set()) unless @repIndex.has(target)
                      @repIndex.get(target).add(resNum)
                      @harmImgIndex.add(target) if isThatHarmImg
                      target++

                return "<a href=\"javascript:undefined;\" class=\"anchor" +
                (if disabled then " disabled\" data-disabled-reason=\"#{disabledReason}\"" else "\"") +
                ">#{$0}</a>"
              )
              #IDリンク
              .replace(/id:(?:[a-hj-z\d_\+\/\.\!]|i(?!d:))+/ig, "<a href=\"javascript:undefined;\" class=\"anchor_id\">$&</a>")
          )

          articleHtml += "<div class=\"message\""
          if color? then articleHtml += " style=\"color:##{color[1]};\""
          articleHtml += ">#{tmp}</div>"

          if app.config.isOn("display_ng") and res.class.includes("ng")
            res.class.push("disp_ng")

          tmp = ""
          tmp += " class=\"#{res.class.join(" ")}\""
          tmp += " data-id=\"#{res.id}\"" if res.id?
          tmp += " data-slip=\"#{res.slip}\"" if res.slip?
          tmp += " data-trip=\"#{res.trip}\"" if res.trip?
          for key, val of res.attr
            tmp += " #{key}=\"#{val}\""

          articleHtml = """<article#{tmp}>#{articleHtml}</article>"""
          html += articleHtml

        @container.insertAdjacentHTML("BeforeEnd", html)

        @updateIds()

        #サムネイル追加処理
        Promise.all(
          Array.from(@container.$$(
            ".message > a:not(.anchor):not(.thumbnail):not(.has_thumbnail):not(.expandedURL):not(.has_expandedURL)"
          )).map( (a) =>
            return @checkUrlExpand(a).then( ({a, link}) =>
              {res, err} = app.ImageReplaceDat.do(link)
              unless err?
                href = res.text
              else
                href = a.href
              mediaType = app.URL.getExtType(
                href
                audio: app.config.isOn("audio_supported")
                video: app.config.isOn("audio_supported")
                oggIsAudio: app.config.isOn("audio_supported_ogg")
                oggIsVideo: app.config.isOn("video_supported_ogg")
              )
              mediaType ?= "image" unless err?
              # サムネイルの追加
              @addThumbnail(a, href, mediaType, res) if mediaType
              return
            )
          )
        ).catch( -> return).then( ->
          resolve()
          return
        )
        return
      )
      return
    )

  ###*
  @method updateId
  @param {String} className
  @param {Map} map
  @param {String} prefix
  ###
  updateId: (className, map, prefix) ->
    numbersReg = /(?:\(\d+\))?$/
    for [id, index] from map
      count = index.size
      for resNum from index
        elm = @container.child()[resNum - 1].C(className)[0]
        elm.textContent = "#{prefix}#{id}(#{count})"
        if count >= 5
          elm.removeClass("link")
          elm.addClass("freq")
        else if count >= 2
          elm.addClass("link")
    return

  ###*
  @method updateIds
  ###
  updateIds: ->
    #id, slip, trip更新
    @updateId("id", @idIndex, "")
    @updateId("slip", @slipIndex, "SLIP:")
    @updateId("trip", @tripIndex, "")

    #harmImg更新
    do =>
      for res from @harmImgIndex
        elm = @container.child()[res - 1]
        continue unless elm
        elm.addClass("has_blur_word")
        if elm.hasClass("has_image") and app.config.isOn("image_blur")
          UI.MediaContainer.setImageBlur(elm, true)
      return

    #参照関係再構築
    do =>
      for [resKey, index] from @repIndex
        res = @container.child()[resKey - 1]
        continue unless res
        resCount = index.size
        if elm = res.C("rep")[0]
          newFlg = false
        else
          newFlg = true
          elm = $__("span")
        elm.textContent = "返信 (#{resCount})"
        elm.className = if resCount >= 5 then "rep freq" else "rep link"
        res.dataset.rescount = [1..resCount].join(" ")
        if newFlg
          res.C("other")[0].addLast(
            document.createTextNode(" ")
          )
          res.C("other")[0].addLast(elm)
        #連鎖NG
        if app.config.isOn("chain_ng") and res.hasClass("ng")
          for r from index
            continue if @container.child()[r - 1].hasClass("ng")
            @container.child()[r - 1].addClass("ng")
            @container.child()[r - 1].setAttr("ng-type", "chain")
            if app.config.isOn("display_ng")
              @container.child()[r - 1].addClass("disp_ng")
        #自分に対してのレス
        if res.hasClass("written")
          for r from index
            @container.child()[r - 1].addClass("to_written")
    return

  ###*
  @method addThumbnail
  @param {HTMLAElement} sourceA
  @param {String} thumbnailPath
  @param {String} [mediaType="image"]
  @param {Object} res
  ###
  addThumbnail: (sourceA, thumbnailPath, mediaType = "image", res) ->
    sourceA.addClass("has_thumbnail")

    thumbnail = $__("div")
    thumbnail.addClass("thumbnail")
    thumbnail.setAttr("media-type", mediaType)

    if mediaType in ["image", "video"]
      article = sourceA.closest("article")
      article.addClass("has_image")
      # グロ画像に対するぼかし処理
      if article.hasClass("has_blur_word") and app.config.isOn("image_blur")
        thumbnail.addClass("image_blur")
        v = app.config.get("image_blur_length")
        webkitFilter = "blur(#{v}px)"
      else
        webkitFilter = "none"

    switch mediaType
      when "image"
        thumbnailLink = $__("a")
        thumbnailLink.href = app.safeHref(sourceA.href)
        thumbnailLink.target = "_blank"

        thumbnailImg = $__("img")
        thumbnailImg.addClass("image")
        thumbnailImg.src = "/img/dummy_1x1.webp"
        thumbnailImg.style.WebkitFilter = webkitFilter
        thumbnailImg.style.maxWidth = "#{app.config.get("image_width")}px"
        thumbnailImg.style.maxHeight = "#{app.config.get("image_height")}px"
        thumbnailImg.dataset.src = thumbnailPath
        thumbnailImg.dataset.type = res.type
        if res.extract? then thumbnailImg.dataset.extract = res.extract
        if res.extractReferrer? then thumbnailImg.dataset.extractReferrer = res.extractReferrer
        if res.pattern? then thumbnailImg.dataset.pattern = res.pattern
        if res.cookie? then thumbnailImg.dataset.cookie = res.cookie
        if res.cookieReferrer? then thumbnailImg.dataset.cookieReferrer = res.cookieReferrer
        if res.referrer? then thumbnailImg.dataset.referrer = res.referrer
        if res.userAgent? then thumbnailImg.dataset.userAgent = res.userAgent
        thumbnailLink.addLast(thumbnailImg)

        thumbnailFavicon = $__("img")
        thumbnailFavicon.addClass("favicon")
        thumbnailFavicon.src = "/img/dummy_1x1.webp"
        thumbnailFavicon.dataset.src = "https://www.google.com/s2/favicons?domain=#{sourceA.hostname}"
        thumbnailLink.addLast(thumbnailFavicon)

      when "audio", "video"
        thumbnailLink = $__(mediaType)
        thumbnailLink.src = ""
        thumbnailLink.dataset.src = thumbnailPath
        thumbnailLink.preload = "metadata"
        switch mediaType
          when "audio"
            thumbnailLink.style.width = "#{app.config.get("audio_width")}px"
            thumbnailLink.setAttr("controls", "")
          when "video"
            thumbnailLink.style.WebkitFilter = webkitFilter
            thumbnailLink.style.maxWidth = "#{app.config.get("video_width")}px"
            thumbnailLink.style.maxHeight = "#{app.config.get("video_height")}px"
            if app.config.isOn("video_controls")
              thumbnailLink.setAttr("controls", "")

    thumbnail.addLast(thumbnailLink)

    # 高さ固定の場合
    if app.config.isOn("image_height_fix")
      switch mediaType
        when "image"
          h = parseInt(app.config.get("image_height"))
        when "video"
          h = parseInt(app.config.get("video_height"))
        else
          h = 100   # 最低高
      thumbnail.style.height = "#{h}px"

    sib = sourceA
    while true
      pre = sib
      sib = pre.next()
      if !sib? or sib.tagName is "BR"
        if sib?.next()?.hasClass("thumbnail")
          continue
        pre.addAfter(thumbnail)
        if not pre.hasClass("thumbnail")
          pre.addAfter($__("br"))
        break
      return

  ###*
  @method addExpandedURL
  @param {HTMLAElement} sourceA
  @param {String} finalUrl
  ###
  addExpandedURL: (sourceA, finalUrl) ->
    sourceA.addClass("has_expandedURL")

    expandedURL = $__("div")
    expandedURL.addClass("expandedURL")
    expandedURL.setAttr("short-url", sourceA.href)
    if app.config.get("expand_short_url") is "popup"
      expandedURL.addClass("hide_data")

    if finalUrl
      expandedURLLink = $__("a")
      expandedURLLink.textContent = finalUrl
      expandedURLLink.href = app.safeHref(finalUrl)
      expandedURLLink.target = "_blank"
      expandedURL.addLast(expandedURLLink)
    else
      expandedURL.addClass("expand_error")
      expandedURLLink = null

    sib = sourceA
    while true
      pre = sib
      sib = pre.next()
      if !sib? or sib.tagName is "BR"
        if sib?.next()?.hasClass("expandedURL")
          continue
        pre.addAfter(expandedURL)
        if not pre.hasClass("expandedURL")
          pre.addAfter($__("br"))
        break
     return expandedURLLink

  ###*
  @method checkUrlExpand
  @param {HTMLAElement} a
  ###
  checkUrlExpand: (a) ->
    return new Promise( (resolve, reject) =>
      if (
        app.config.get("expand_short_url") isnt "none" and
        app.URL.SHORT_URL_LIST.has(app.URL.getDomain(a.href))
      )
        # 短縮URLの展開
        app.URL.expandShortURL(a.href).then( (finalUrl) =>
          newLink = @addExpandedURL(a, finalUrl)
          if finalUrl
            resolve({a, link: newLink.href})
          else
            resolve({a, link: a.href})
          return
        )
        return
      resolve({a, link: a.href})
      return
    )

  ###*
  @method addClassWithOrg
  @param {Element} $res
  @param {String} className
  ###
  addClassWithOrg: ($res, className) ->
    $res.addClass(className)
    resnum = parseInt($res.C("num")[0].textContent)
    @container.child()[resnum-1].addClass(className)
    return

  ###*
  @method removeClassWithOrg
  @param {Element} $res
  @param {String} className
  ###
  removeClassWithOrg: ($res, className) ->
    $res.removeClass(className)
    resnum = parseInt($res.C("num")[0].textContent)
    @container.child()[resnum-1].removeClass(className)
    return

  ###*
  @method addWriteHistory
  @param {Element} $res
  ###
  addWriteHistory: ($res) ->
    resnum = parseInt($res.C("num")[0].textContent)
    name = $res.C("name")[0].textContent
    mail = $res.C("mail")[0].textContent
    message = $res.C("message")[0].textContent
    date = @stringToDate($res.C("other")[0].textContent)
    if date?
      app.WriteHistory.add(@url, resnum, document.title, name, mail, name, mail, message, date.valueOf())
    return

  ###*
  @method removeWriteHistory
  @param {Element} $res
  ###
  removeWriteHistory: ($res) ->
    resnum = parseInt($res.C("num")[0].textContent)
    app.WriteHistory.remove(@url, resnum)
    return

  ###*
  @method stringToDate
  @param {String} string
  @return {Date}
  ###
  stringToDate: (string) ->
    date1 = string.match(/(\d+)\/(\d+)\/(\d+)\(.\)\s?(\d+):(\d+):(\d+)(?:\.(\d+))?.*/)
    if date1.length >= 6
      return new Date(date1[1], date1[2]-1, date1[3], date1[4], date1[5], date1[6])
    else if date1.length >= 5
      return new Date(date1[1], date1[2]-1, date1[3], date1[4], date1[5])
    else
      return null
