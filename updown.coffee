## UP-DOWN3 written by KUMA. licensed under the CC0 2019.

##==============================================================================
# Suger for getter and setter method of CoffeeScript.
Function::property = (prop, desc)->
    Object.defineProperty @prototype, prop, desc

##==============================================================================
# JQueryを利用し、SVGを生成する。
class SVGGenerator
    # paper サイズの空のSVGを生成する。
    constructor: (paper)->
        switch paper
            when 'A4' then @paperSize = {x: 297, y: 210}
            else @paperSize = {x: 297, y: 210}
        @$svg = @$NS "svg", {
            xmlns: _NS
            version: "1.1"
            height: @paperSize.y + "mm"
            width: @paperSize.x + "mm"
            viewBox: "0 0 " + @paperSize.x + " " + @paperSize.y
        }
        .append $ "<style>"
        @lastLayer = @$svg

    # SVGの名前空間でDOM要素を作る。
    $NS: (elementName, attr)->
        $elem = $ document.createElementNS _NS, elementName
        if attr? then $elem.attr attr else $elem

    # 新しいレイヤー<g>を追加する。
    newLayer: (id)->
        @lastLayer = @$NS("g").appendTo @$svg
        if id? then @lastLayer.attr 'id', id
        @lastLayer[0]

    # SVGの<path>要素を作る。
    newPath: (type, data)->
        $p = @$NS "path", {
            class: type
            d: ((if i is 0 then "M#{o.x},#{o.y} L" else "#{o.x},#{o.y} ") for o, i in data).join("")
        }
        .appendTo @lastLayer
        $p[0]

    # SVGの<text>要素を作る。
    newText: (type, pos, anchor, str)->
        $t = @$NS "text", { class: type, x: pos.x, y: pos.y }
        switch anchor
            when "E"
                $t.css {"text-anchor": "start", "dominant-baseline": "central"}
            when "SW"
                $t.css {"text-anchor": "end", "dominant-baseline": "hanging"}
            when "S"
                $t.css {"text-anchor": "middle", "dominant-baseline": "hanging"}
            when "W"
                $t.css {"text-anchor": "end", "dominant-baseline": "central"}
            else # "N"
                $t.css {"text-anchor": "middle"}
        $t.text str
        $t.appendTo @lastLayer
        $t[0]

    # スタイル要素を設定する。
    @property 'css',
        set: (data)->
            @$svg.find("style").text _toStyleString data

    # SVGファイルを構成する文字列を作る。
    @property 'html',
        get: ->
            '<?xml version="1.0" encoding="UTF-8"?>' + @$svg[0].outerHTML

    @property 'dom',
        get: -> @$svg[0]

    ##--------------------------------------------------------------------
    # static private
    _NS = "http://www.w3.org/2000/svg"

    # オブジェクトをCSS文字列に変換する。
    _toStyleString = (obj)->
        if (typeof data) is 'string'
            return obj
        buf = ""
        for one of obj
            buf += "#{one} { "
            data = obj[one]
            for o of data
                buf += "#{o}:#{data[o]}; "
            buf += " } "
        buf


##==============================================================================
# 画像キャッシュサーバー
# JQueryを利用する。
class ImageServer
    # store は非表示の <div> 要素。<canvas>のキャッシュが貯まる。
    # checker は、URLを受け取り、正か負を返す関数。
    # 負を返すと画像がキャッシュから消去される
    constructor: (store, @_checker)->
        @_$s = $ store

    # urlの画像を読み込み、cb(canvas)で呼び出す。
    # エラー時には、errorcb が呼び出される。
    loadImage: (url, cb, errorcb)->
        $can = @_$s.children 'canvas[src="' + url + '"]'
        if 0 < $can.length
            # console.log "do recycle #{url}"
            cb $can[0]
        else
            outer = @
            # console.log "start loading of #{url}"
            $img = $ "<img>"
            .attr "crossOrigin", "Anonymous"
            .on "load", (e)->
                # console.log "load completed"
                img = e.target
                $can = $ "<canvas>"
                .attr {width: img.width, height: img.height, src: img.src}
                ctx = $can[0].getContext('2d')
                ctx.drawImage img, 0, 0

                # 古いのを削除する。
                outer._$s.children 'canvas'
                .each (idx)->
                    $t = $ @
                    u = $t.attr "src"
                    $t.remove() if not outer._checker u

                outer._$s.append $can
                cb $can[0]
            .on "error", errorcb
            .attr "src", url

################################################################################
# Leaflet ラッパ。jQueryを利用します。
# 国土地理院地図を利用し、日本を表示します。
# データ書式
# { lat: 緯度, lng: 経度, x: 距離, y: 標高, label: ラベル, pitch: 傾斜 }
# pitch は付近の等高線のつまり具合の指標を表す。
#

##==============================================================================
# extends L.Point
# 長さ
L.Point.property 'length',
    get: ->
        Math.sqrt @x * @x + @y * @y
# 正規化
L.Point::normalized = ->
    l = @length
    L.point @x / l, @y / l
# 内積
L.Point::dotOf = (p2) ->
    @x * p2.x + @y * p2.y
# 外積
L.Point::crossOf = (p2) ->
    @x * p2.y - @y * p2.x
# 点が線分上にあるか
L.Point::isOnTheLineOf = (p1, p3, crossBorder)->
    crossBorder = 0.1 if not crossBorder?
    v21 = @subtract p1
    v31 = p3.subtract p1
    nv21 = v21.normalized()
    nv31 = v31.normalized()
    v21.length < v31.length and 0 < v21.dotOf(v31) and Math.abs(nv31.crossOf(nv21)) < crossBorder

##==============================================================================
# Leafletの国土地理院地図チューン
class GSIMap extends L.Map
    constructor: (id)->
        super id

        # マップ右下のリンクを出す。
        L.tileLayer 'https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png',
            attribution: '<a href="https://maps.gsi.go.jp/development/ichiran.html" target="_blank">地理院タイル</a>'
            maxZoom: 18
        .addTo @

        # 日本を表示する。
        @resetDefaultLocation()


    # マップを初期状態にする。
    resetDefaultLocation: -> @setView [36.104611,140.084556], 5

    ##--------------------------------------------------------------------
    # static

    # あるズームレベルにおけるマップの全サイズ(ピクセル)
    @MAP_SIZE: (z)-> 256 * (2 ** z)

    # 指定のズームレベル、緯度で1pixelが何メートルになるか。
    # ただし、地球は球であると近似する。
    @getLengthOfPixel: (zoom, lat)->
        EARTH_CIRCLE * Math.cos(lat * TO_RADIAN) / GSIMap.MAP_SIZE(zoom)

    # 全タイル内での位置から、現在のタイル位置を得る。
    @getTileXYFromCoord: (p)->
        L.point Math.floor(p.x / 256), Math.floor(p.y / 256)

    # 全タイル内での位置から、現在のタイル左上を原点とする位置に変換する。
    @getPointOnTileFromCoord: (p)->
        new L.Point Math.floor(p.x % 256), Math.floor(p.y % 256)

    @URL: "https://cyberjapandata.gsi.go.jp/xyz/"

    # タイル位置から、標高タイル画像のURLを得る。
    @getDEMURLFromTileXY: (p, zoom)->
        if 0 <= zoom <= 14
            "#{GSIMap.URL}dem_png/#{zoom}/#{p.x}/#{p.y}.png"
        else
            "#{GSIMap.URL}dem5a_png/15/#{p.x}/#{p.y}.png"

    # URLからタイル情報を得る。
    # {zoom:, x:, y:}
    @getTileInfoFromURL: (url)->
        JSON.parse url.replace /.*\/(\d+)\/(\d+)\/(\d+)\.png$/, '{"zoom":$1, "x":$2, "y":$3}'

    ##--------------------------------------------------------------------
    # static private

    # 地球の半径(m)(赤道の値。ただし、ここで地球は真球と近似する。)
    # https://ja.wikipedia.org/wiki/%E5%9C%B0%E7%90%83%E5%8D%8A%E5%BE%84
    EARTH_RADIUS = 6378136.6

    # 地球の円周
    EARTH_CIRCLE = EARTH_RADIUS * 2 * Math.PI

    # degree to radian
    TO_RADIAN = Math.PI / 180


##==============================================================================
# ルート全体(赤い線)
class RouteMarkerGenerator extends L.Polyline
    # map is L.Map
    # hs is HeightServer
    constructor: (@_map, @_hs)->
        super [], {color: 'red'}
        @_markers = []
        @addTo @_map
        @on 'click', (e)->
            pos = @_find e.latlng
            if 0 < pos
                @create e.latlng, pos
            L.DomEvent.stopPropagation(e)

    # マーカーを表示する。
    show: ->
        if 0 < @_markers.length
            $(@_markers[0].getPane()).show()
    # マーカーを隠す。
    hide: ->
        if 0 < @_markers.length
            $(@_markers[0].getPane()).hide()

    # マーカーに合わせて赤い線を更新する。
    update: ->
        @setLatLngs (m.getLatLng() for m in @_markers)

    # 全消去
    clearAll: ->
        for one in @_markers
            one.remove()
        @_markers = []
        @setLatLngs []

    # 一括読み込み。
    load: (data)->
        @clearAll()
        for one in data
            m = @create one
            m.title = one.label if one.label?
            m.height = one.y if one.y?
            m.pitch = one.pitch if one.pitch?

    # latlng の位置、idx の順番にマーカーを追加する。
    # idx を省略した場合は最後に追加される。
    create: (latlng, idx)->
        m = new RouteMarker @, latlng
        .addTo @_map
        if idx? then @_markers.splice idx, 0, m else @_markers.push m
        @update()
        return m

    # ドラッグ中は他のマーカーを消す。
    dragStart: (m)->
        for one in @_markers
            one.setOpacity(0) if one isnt m

    # ドラッグが終ったらマーカーを表示する。
    dragEnd: ()->
        for one in @_markers
            one.setOpacity(1.0)

    # マーカーを消す。
    remove: (m)->
        @_markers = @_markers.filter (one)=>one isnt m
        m.remove()
        @update()

    # マーカーのバルーンに標高値と傾斜を設定する。
    queryHeightAndPitch: (m, cb)->
        height = m.height
        pitch = m.pitch
        if isNaN(height) or isNaN(pitch)
            @_hs.getHeightAndPitchFromLatLng m.getLatLng(), 15, (h, p)->
                m.height = h
                m.pitch = p
                cb? h, p
        else
            cb? height, pitch


    # 全てのマーカーに標高、傾斜を設定し、コールバックを呼び出す。
    # cb([L.Markers])
    queryAllHeightAndPitch: (progressbar, cb)->
        outer = @
        $bar = $ progressbar
        .attr {max: @_markers.length, value: 0}
        progress = -1

        proc = ()->
            ++progress;
            $bar.val progress
            if progress < outer._markers.length
                outer.queryHeightAndPitch outer._markers[progress], proc
            else
                $bar.val 0
                cb outer._markers

        proc()

    # lls ルート上の点 latlng が含まれる線分のインデックスを返す。
    # みつからなければ -1 を返す。
    _find: (latlng)->
        p2 = @_map.project latlng
        lls = @getLatLngs()
        for ll, idx in lls
            break if lls.length <= idx + 1
            p1 = @_map.project ll
            p3 = @_map.project lls[idx+1]
            if p2.isOnTheLineOf p1, p3
                return idx + 1
        return -1


##==============================================================================
# ルートマーカー
class RouteMarker extends L.Marker
    ##--------------------------------------------------------------------
    # public

    # g は RouteMarkerGenerator
    # latlng は位置
    constructor: (@_g, latlng)->
        super latlng, {riseOnHover: true, draggable: true}
        outer = @
        # 中身
        @_$c = $ "
            <div><input type='text' class='title'></input><br>
            緯度軽度: <span class='latlng'></span><br>
            標高: <input type='text' class='height' val='N/A'></input>m<br>
            傾斜: <span class='pitch'>N/A</span><br>
            <button>削除</button></div>"

        # 削除ボタン
        @_$c.find("button").on "click", (e)-> outer._g.remove outer
        # テキストボックスで ESC を押したらバルーンを閉じる。
        @_$c.find("input").on "keyup", (e)->
            if e.keyCode is 0x1b
                outer.closePopup()
                e.preventDefault()

        @bindPopup @_$c[0]
        @on 'click', (e)->
            ll = @getLatLng()
            @_$c.find("span.latlng").text "#{ll.lat.toFixed(2)}, #{ll.lng.toFixed(2)}"
            @_g.queryHeightAndPitch @, ()->
                outer._$c.find("input.title").focus()
        @on 'drag', (e)-> @_g.update()
        @on 'dragstart', (e)-> @_g.dragStart @
        @on 'dragend', (e)->
            @height = "N/A"
            @pitch = "N/A"
            @_g.dragEnd()

    # バルーンのタイトルを得る。
    @property 'title',
        get: ->
            @_$c.find("input.title").val()
        set: (s)->
            @_$c.find("input.title").val s

    # バルーン内の標高を得る。
    @property 'height',
        get: ->
            val = @_$c.find("input.height").val()
            if not val then Number.NaN else parseFloat val
        set: (h)->
            @_$c.find("input.height").val if (typeof h) is 'number' then h.toFixed 2 else h

    # バルーン内の傾斜を得る。
    @property 'pitch',
        get: ->
            parseFloat @_$c.find("span.pitch").text()
        set: (p)->
            @_$c.find("span.pitch").text if (typeof p) is 'number' then p.toFixed 2 else p



##==============================================================================
# 標高サーバー
# 国土地理院地図の標高マップから標高値を得る。
class HeightServer
    constructor: (@_map, @_is)->

    # 標高と傾斜を得る。
    getHeightAndPitchFromLatLng: (latlng, zoom, cb)->
        coord = @_map.project latlng, zoom
        url = GSIMap.getDEMURLFromTileXY GSIMap.getTileXYFromCoord(coord), zoom
        p = GSIMap.getPointOnTileFromCoord coord
        outer = @
        @_is.loadImage url, (canvas)->
            h = _getHeightFromImg canvas, p
            if isNaN(h) and zoom is 15
                outer.getHeightAndPitchFromLatLng latlng, 14, cb
            else
                cb h, _getPitchFromImg canvas, p, zoom, latlng.lat
        , (e)-> # 失敗したら10mBメッシュで取り直し。
            if zoom < 15 then cb Number.NaN, 0 else outer.getHeightAndPitchFromLatLng latlng, 14, cb

    ##--------------------------------------------------------------------
    # static private

    # RGBデータから標高を得る。(単位はm)
    _getHeightFromRGB = (rgb)->
        x = (rgb[0] << 16) + (rgb[1] << 8) + rgb[2]
        if x < (1 << 23)
            x * 0.01
        else if (1 << 23) < x
            (x - 1 << 24) * 0.01
        else
            Number.NaN

    # canvas要素から p の位置の標高を得る。
    _getHeightFromImg = (canvas, p)->
        _getHeightFromRGB canvas.getContext('2d').getImageData(p.x, p.y, 1, 1).data

    # canvas要素から p の位置の傾斜情報を得る。
    _getPitchFromImg = (canvas, p, zoom, lat)->
        data = canvas.getContext('2d').getImageData p.x - 1, p.y - 1, 3, 3
            .data
        max = -999999
        min = 999999
        truncatedRatio = 1 # 画像端の場合の調整
        for i in [0..data.length] by 4
            if data[i+3] is 0 # 透明ピクセルは範囲外
                truncatedRatio = 2
                continue
            h = _getHeightFromRGB data.slice i
            max = h if max < h
            min = h if h < min
        if max <= min then 0 else (max - min) * truncatedRatio / 2 / GSIMap.getLengthOfPixel zoom, lat


##==============================================================================
# [{x: 距離, y: 標高, label: ラベル, pitch: 傾斜}, ...]からSVGを出力する。
# jQueryを利用する。
makeSVG = (data)->
    # 定数
    graphSize = {x: 230, y: 160}
    graphTopLeft = {x: 30, y: 20}
    graphMargin = {top: 10, bottom: 10, left: 0, right: 10}

    # 情報
    maxLength = 0
    minHeight = 99999
    maxHeight = -99999
    scaleX = 1
    scaleY = 1

    # dataの値をSVG内での位置に変換する。
    xOnGraph = (x)-> graphTopLeft.x + graphMargin.left + x * scaleX
    yOnGraph = (y)-> graphTopLeft.y + graphSize.y - graphMargin.bottom - (y - minHeight) * scaleY
    posOnGraph = (p)->
        x: xOnGraph p.x
        y: yOnGraph p.y

    # 傾斜の変換
    pitchOnGraph = (inc)->graphTopLeft.y + graphSize.y - graphMargin.bottom - inc  * inc * 40
    pitchPosOnGraph = (p)->
        x: xOnGraph p.x
        y: pitchOnGraph p.pitch

    ##--------------------------------------------------------------------
    # データ解析
    maxLength = data[data.length - 1].x
    for one in data
        minHeight = one.y if one.y < minHeight
        maxHeight = one.y if maxHeight < one.y
    scaleX = (graphSize.x - graphMargin.left - graphMargin.right) / maxLength
    scaleY = (graphSize.y - graphMargin.top - graphMargin.bottom) / (maxHeight - minHeight)


    ##--------------------------------------------------------------------
    # 描画
    ##--------------------------------------------------------------------
    #
    svgg = new SVGGenerator 'A4'
    svgg.css =
        'path':
            fill:'none'
            'stroke-linecap': 'butt'
            'stroke-linejoin': 'miter'
            'stroke-opacity': 1
        '.data':
            stroke:'#000000'
            'stroke-width':0.4
        '.pitch':
            stroke:'#ff8080'
            'stroke-width':0.4
        '.bg':
            fill: 'white'
            stroke: 'none'
        '.frame':
            stroke:'#000000'
            'stroke-width':0.8
        '.scale':
            'font-size':'3.5pt'
        '.label':
            'font-size':'4pt'
        '.label-guide':
            stroke:'#808080'
            'stroke-width':0.2

    # レイヤー1
    svgg.newLayer()

    # 外枠
    svgg.newPath "bg", [
        {x: 0, y: 0},
        {x: 0, y: svgg.paperSize.y},
        {x: svgg.paperSize.x, y: svgg.paperSize.y},
        {x: svgg.paperSize.x, y: 0},
        {x: 0, y: 0},
    ]

    # Lの字
    svgg.newPath "frame", [
        {x: graphTopLeft.x, y: graphTopLeft.y},
        {x: graphTopLeft.x, y: graphTopLeft.y + graphSize.y},
        {x: graphTopLeft.x + graphSize.x, y: graphTopLeft.y + graphSize.y }
    ]
    # 左上(標高)
    svgg.newText "scale", graphTopLeft, "N", "標高(m)"
    # 右下(水平距離)
    svgg.newText "scale", {x: graphTopLeft.x + graphSize.x, y: graphTopLeft.y + graphSize.y}, "E", "距離(km)"
    # 左下(倍率)
    svgg.newText "scale", {x: graphTopLeft.x, y: graphTopLeft.y+ graphSize.y}, "SW", ((scaleY/scaleX).toFixed 1) + ":1"

    # 全距離
    x = xOnGraph maxLength
    y = graphTopLeft.y + graphSize.y
    svgg.newPath "frame", [{x: x, y: y}, {x: x, y: y + 5}]
    svgg.newText "scale opaque", {x: x, y: y + 5}, "S", (maxLength / 1000).toFixed 1
    maxX = x;

    # 距離目盛
    for len in [1000..maxLength] by 1000
        x = xOnGraph len
        y = graphTopLeft.y + graphSize.y
        if (len % 5000) is 0 and 10 < (maxX - x)

            svgg.newPath "frame", [{x: x, y: y}, {x: x, y: y + 5}]
            svgg.newText "scale", {x: x, y: y + 5}, "S", len / 1000
        else
            svgg.newPath "frame", [{x: x, y: y}, {x: x, y: y + 2}]

    # 最低標高
    x = graphTopLeft.x;
    y = yOnGraph minHeight
    svgg.newPath "frame", [{x: x-5, y: y}, {x: x, y: y}]
    svgg.newText "scale opaque", {x: x-5, y: y}, "W", minHeight.toFixed 0
    minY = y;

    # 最高標高
    y = yOnGraph maxHeight
    svgg.newPath "frame", [{x: x-5, y: y}, {x: x, y: y}]
    svgg.newText "scale opaque", {x: x-5, y: y}, "W", maxHeight.toFixed 0
    maxY = y;

    # 標高目盛
    for len in [minHeight + 100 .. maxHeight] by 100
        len2 = len - (len % 100)
        x = graphTopLeft.x;
        y = yOnGraph len2
        svgg.newPath "frame", [{x: x - 5, y: y}, {x: x, y: y}]
        if 5 < (minY - y) and 5 < (y - maxY)
            svgg.newText "scale", {x: x - 5, y: y}, "W", len2

    ##--------------------------------------------------------------------
    # 傾斜
    svgg.newPath "pitch", (pitchPosOnGraph one for one in data)

    # UP-DOWN
    svgg.newPath "data", (posOnGraph one for one in data)

    ##--------------------------------------------------------------------
    # ラベル
    prevX = 0
    isUpper = true
    for one in data
        if 0 < one.label.length
            x = xOnGraph one.x
            if ((x - prevX) < 10) == isUpper
                d = 10
                isUpper = false
            else
                d = -10
                isUpper = true
            y = yOnGraph one.y
            svgg.newPath "label-guide", [{x: x, y: y}, {x: x, y: y + d}]
            svgg.newText "label", {x: x, y: y + d}, (if isUpper then "N" else "S"), one.label
            prevX = x

    return svgg

##==============================================================================
# メインフレーム
class MyMap extends GSIMap
    constructor: (id, store, @_progressbar)->
        super id
        outer = @
        @_is = new ImageServer store, (url)->
            outer._visibleOnMap GSIMap.getTileInfoFromURL url
        @_hs = new HeightServer @, @_is
        @_rmg = new RouteMarkerGenerator @, @_hs

        # 地図上のクリックイベント
        @on 'click', (e)->
            @_rmg.create e.latlng

        # シフトキーでマーカーを消す。
        $("body").on 'keydown', (e)->outer._rmg.hide() if e.keyCode is 16
        .on 'keyup', (e)-> outer._rmg.show() if e.keyCode is 16

    # 全消去
    clearAll: ->
        @_rmg.clearAll()

    # 一括読み込み
    load: (data)->
        @_rmg.load data

    # 一括書き出し
    getAllData: (cb)->
        @_rmg.queryAllHeightAndPitch @_progressbar, (m)->
            wl = 0
            cb({
                lat: one.getLatLng().lat
                lng: one.getLatLng().lng
                x: if i is 0 then 0 else wl+=m[i-1].getLatLng().distanceTo one.getLatLng()
                y: one.height
                label: one.title
                pitch: one.pitch
            } for one, i in m)

    # タイルが現在の map上で見えているか。
    # tile = {x: x, y: y, zoom: zoom}
    _visibleOnMap: (tile)->
        mapB = @getBounds()
        tl = GSIMap.getTileXYFromCoord @project mapB.getNorthWest(), tile.zoom
        br = GSIMap.getTileXYFromCoord @project mapB.getSouthEast(), tile.zoom
        tl.x <= tile.x <= br.x and tl.y <= tile.y <= br.y



################################################################################
##
## jQuery 開始
##
################################################################################
$ ->
    # 説明画面
    closeHelp = (e)->$("#help").hide()
    $(".closeHelp").on "click", closeHelp
    # local storage
    if not localStorage.getItem "secondInvocation"
        localStorage.setItem "secondInvocation", true
    else
         closeHelp()

    # UIの設定
    $("#menu").hide()
    $("#openButton").on "click", (e)->
        $(this).hide()
        $("#menu").show()

    $("#closeButton").on "click", (e)->
        $("#menu").hide()
        $("#openButton").show()

    # マップの初期化
    map = new MyMap "map", "#store", "#progressbar"

    # 全消去
    clearAll = ()->
        map.clearAll()
        $("#svgcanvas").empty()

    # データ作成する。
    $("#createData").on "click", (e)->
        sel = ($ "#dataFormat")[0]
        switch sel.options[sel.selectedIndex].value
            when "CSV"
                map.getAllData (data)->
                    $("#dataOutput").val ("#{o.x.toFixed(2)}, #{o.y.toFixed(2)}, \"#{o.label}\"" for o in data).join "\r\n"

            when "JSON"
                map.getAllData (data)->
                    $("#dataOutput").val JSON.stringify data

            when "SVG"
                $("#svgcanvas").empty()
                map.getAllData (data)->
                    svgg = makeSVG data
                    $("#svgcanvas").append svgg.dom
                    $("#dataOutput").val svgg.html

    #
    $("#clearAll").on "click", (e)->
        clearAll()

    #
    $("#loadData").on "click", (e)->
        clearAll()
        map.load JSON.parse $("#dataOutput").val()

    #
    $("#showHelp").on "click", (e)->
        $("#help").show()
