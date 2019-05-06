## [{x: 距離, y: 標高, label: ラベル}, ...]からSVGを出力する。jQueryを利用する。
makeSVG = (data)->
    # 定数
    paperSize = {x: 297, y: 210}
    graphSize = {x: 230, y: 160}
    graphTopLeft = {x: 30, y: 20}
    graphMargin = {top: 10, bottom: 10, left: 0, right: 10}
    SVGNS = "http://www.w3.org/2000/svg"

    # 情報
    maxLength = 0
    minHeight = 99999
    maxHeight = -99999
    scaleX = 1
    scaleY = 1

    # Suger
    # SVGの名前空間でDOM要素を作る。
    $NS = (elementName, attr)->
        $elem = $ document.createElementNS SVGNS, elementName
        if attr? then $elem.attr attr else $elem

    # SVGの<path>要素を作る。
    $path = (type, data)->
        $NS "path", {
            class: type
            d: ((if i is 0 then "M#{o.x},#{o.y} L" else "#{o.x},#{o.y} ") for o, i in data).join("")
        }

    # SVGの<text>要素を作る。
    $text = (type, pos, anchor, str)->
        $t = $NS "text", {class: type, x: pos.x, y: pos.y}
        switch anchor
            when "N"
                $t.css {"text-anchor": "middle"}
            when "E"
                $t.css {"text-anchor": "start", "dominant-baseline": "central"}
            when "SW"
                $t.css {"text-anchor": "end", "dominant-baseline": "hanging"}
            when "S"
                $t.css {"text-anchor": "middle", "dominant-baseline": "hanging"}
            when "W"
                $t.css {"text-anchor": "end", "dominant-baseline": "central"}
        $t.text str

    # dataの値をSVG内での位置に変換する。
    xOnGraph = (x)-> graphTopLeft.x + graphMargin.left + x * scaleX
    yOnGraph = (y)-> graphTopLeft.y + graphSize.y - graphMargin.bottom - (y - minHeight) * scaleY
    posOnGraph = (p)-> {
        x: xOnGraph p.x
        y: yOnGraph p.y
    }

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

    $svg = $NS "svg", {
        xmlns: SVGNS
        version: "1.1"
        height: paperSize.y + "mm"
        width: paperSize.x + "mm"
        viewBox: "0 0 " + paperSize.x + " " + paperSize.y
    }

    $ "<style>"
        .text "
        .data {
            fill:none;
            stroke:#000000;
            stroke-width:0.2;
            stroke-linecap:butt;
            stroke-linejoin: miter;
            stroke-opacity:1;
        }

        .bg {
            fill: white;
            stroke: none;
        }

        .frame {
            fill:none;
            stroke:#000000;
            stroke-width:0.5;
            stroke-linecap:butt;
            stroke-linejoin: miter;
            stroke-opacity:1;
        }

        .scale {
            font-size:3.5pt;
            fill:#000000;
        }

        .label {
            font-size:4pt;
            fill:#000000;
        }

        .label-guide {
            fill:none;
            stroke:#808080;
            stroke-width:0.2;
            stroke-opacity:1;
        }
        "
        .appendTo $svg

    # レイヤー1
    $g = $NS "g"
        .appendTo $svg

    ##--------------------------------------------------------------------
    # 外枠
    $g.append $path "bg", [
        {x: 0, y: 0},
        {x: 0, y: paperSize.y},
        {x: paperSize.x, y: paperSize.y},
        {x: paperSize.x, y: 0},
        {x: 0, y: 0},
    ]
    # Lの字
    $g.append $path "frame", [
        {x: graphTopLeft.x, y: graphTopLeft.y},
        {x: graphTopLeft.x, y: graphTopLeft.y + graphSize.y},
        {x: graphTopLeft.x + graphSize.x, y: graphTopLeft.y + graphSize.y }
    ]
    # 左上
    $g.append $text "scale", graphTopLeft, "N", "標高(m)"
    # 右下
    $g.append $text "scale", {x: graphTopLeft.x + graphSize.x, y: graphTopLeft.y + graphSize.y}, "E", "距離(km)"
    # 左下
    $g.append $text "scale", {x: graphTopLeft.x, y: graphTopLeft.y+ graphSize.y}, "SW", ((scaleY/scaleX).toFixed 1) + ":1"

    # 距離目盛
    for len in [1000..maxLength] by 1000
        x = xOnGraph len
        y = graphTopLeft.y + graphSize.y
        if (len % 5000) is 0
            $g.append $path "frame", [{x: x, y: y}, {x: x, y: y + 5}]
            $g.append $text "scale", {x: x, y: y + 5}, "S", len / 1000
        else
            $g.append $path "frame", [{x: x, y: y}, {x: x, y: y + 2}]
    # 全距離
    x = xOnGraph maxLength
    y = graphTopLeft.y + graphSize.y
    $g.append $path "frame", [{x: x, y: y}, {x: x, y: y + 10}]
    $g.append $text "scale opaque", {x: x, y: y + 10}, "S", (maxLength / 1000).toFixed 1

    # 標高目盛
    for len in [minHeight + 100 .. maxHeight] by 100
        len2 = len - (len % 100)
        x = graphTopLeft.x;
        y = yOnGraph len2
        $g.append $path "frame", [{x: x - 5, y: y}, {x: x, y: y}]
        $g.append $text "scale", {x: x - 5, y: y}, "W", len2

    # 最低標高
    x = graphTopLeft.x;
    y = yOnGraph minHeight
    $g.append $path "frame", [{x: x-15, y: y}, {x: x, y: y}]
    $g.append $text "scale opaque", {x: x-15, y: y}, "W", minHeight.toFixed 0

    # 最高標高
    y = yOnGraph maxHeight
    $g.append $path "frame", [{x: x-15, y: y}, {x: x, y: y}]
    $g.append $text "scale opaque", {x: x-15, y: y}, "W", maxHeight.toFixed 0

    ##--------------------------------------------------------------------
    # UP-DOWN
    $g.append $path "data", (posOnGraph one for one in data)

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
            $g.append $path "label-guide", [{x: x, y: y}, {x: x, y: y + d}]
            $g.append $text "label", {x: x, y: y + d}, (if isUpper then "N" else "S"), one.label
            prevX = x

    $svg # makeSVG()の戻り値

##------------------------------------------------------------------------------
# SVG要素からSVGファイルを構成する文字列を作る。
makeSVGfile = (svg)->
    '<?xml version="1.0" encoding="UTF-8"?>' + $(svg).html()

##==============================================================================
## jQuery使わない系関数

# 磁北点を得る。
getNorthMagneticPole = ()->
    L.latLng 86.5, -172.6

# 長さ
calcLength = (p)->
    Math.sqrt p.x * p.x + p.y * p.y

# 正規化
normalize = (p)->
    l = calcLength p
    L.point p.x / l, p.y / l

# 引き算
subtract = (p1, p2)->
    L.point p1.x - p2.x, p1.y - p2.y

# 内積
getDotOf = (p1, p2) ->
    p1.x * p2.x + p1.y * p2.y

# 外積
getCrossOf = (p1, p2) ->
    p1.x * p2.y - p1.y * p2.x

# 全タイル内での位置から、現在のタイル位置を得る。
getTileXYFromCoord = (p)->
    L.point Math.floor(p.x / 256), Math.floor(p.y / 256)

# 全タイル内での位置から、現在のタイル左上を原点とする位置に変換する。
getPointOnTileFromCoord = (p)->
    new L.Point Math.floor(p.x % 256), Math.floor(p.y % 256)

# タイル位置から、標高タイル画像のURLを得る。
getDEM5AURLFromTileXY = (p)->
    "https://cyberjapandata.gsi.go.jp/xyz/dem5a_png/15/#{p.x}/#{p.y}.png"

# タイル位置から、標高タイル画像のURLを得る。
getDEMURLFromTileXY = (p, zoom)->
    if 0 <= zoom <= 14
        "https://cyberjapandata.gsi.go.jp/xyz/dem_png/#{zoom}/#{p.x}/#{p.y}.png"
    else
        "https://cyberjapandata.gsi.go.jp/xyz/dem5a_png/15/#{p.x}/#{p.y}.png"

# URLからタイル情報を得る。
getTileInfoFromURL = (url)->
    JSON.parse url.replace /.*\/(\d+)\/(\d+)\/(\d+)\.png$/, '{"zoom":$1, "x":$2, "y":$3}'

# RGBデータから標高を得る。(単位はm)
getHeightFromRGB = (rgb)->
    x = (rgb[0] << 16) + (rgb[1] << 8) + rgb[2]
    if x < (1 << 23)
        x * 0.01
    else if (1 << 23) < x
        (x - 1 << 24) * 0.01
    else
        Number.NaN

# img要素から p の位置のRGBデータを得る。
getRGBFromImg = (canvas, p)->
    canvas.getContext('2d').getImageData p.x, p.y, 1, 1
    .data

# local storage
needsHelp = (e)-> not localStorage.getItem "secondInvocation"
nomoreHelp = (e)-> localStorage.setItem "secondInvocation", true

##==============================================================================
# Leaflet ラッパ。jQueryを利用します。
# 国土地理院地図を利用し、日本を表示します。
# データ書式
# { lat: 緯度, lng: 経度, x: 距離, y: 標高, label: ラベル}
#
createMap = (store, progressbar)->
    # 初期化
    map = L.map "map"
    markers = [] # マーカー

    # マップを初期状態にする。
    map.resetDefaultLocation = -> @.setView [34.64302, 135], 4

    # 全消去
    map.clearAll = ->
        for one in markers
            one.remove()
        markers = []
        updatePolyLine()

    # 一括読み込み
    map.load = (data)->
        @.clearAll()
        for one in data
            m = createMarkerAt one
            $c = $ m.getPopup().getContent()
            $c.find("input.title").val(one.label)
            $c.find("input.height").val(one.y)
            markers.push m
        updatePolyLine()


    #
    map.getAllData = (cb)->
        getAllHeights (heights)->
            wl = 0
            cb({
                lat: one.getLatLng().lat
                lng: one.getLatLng().lng
                x: if i is 0 then 0 else wl+=markers[i-1].getLatLng().distanceTo one.getLatLng()
                y: heights[i],
                label: $(one.getPopup().getContent()).find("input.title").val()
            } for one, i in markers)


    ##--------------------------------------------------------------------
    ## privates
    ##--------------------------------------------------------------------
    $store = $ store # 非表示の、キャンバス入れとく所

    # マーカーの作成
    createMarkerAt = (latlng)->
        $cont = $ "
            <div><input type='text' class='title'></input><br>
            緯度軽度: <span class='latlng'></span><br>
            標高: <input type='text' class='height' val='N/A'></input>m<br>
            <button>削除</button></div>"

        m = L.marker latlng, {riseOnHover: true, draggable: true}
        .bindPopup $cont[0]
        .on 'click', (e)->
            ll = @.getLatLng()
            $p = $ @.getPopup().getContent()
            $p.find("span.latlng").text "#{ll.lat.toFixed(2)}, #{ll.lng.toFixed(2)}"
            val = $p.find("input.height").val()
            height = if not val then Number.NaN else Number val
            if isNaN height
                getHeightFromLatLng ll, map.getZoom(), (h)->
                    $p.find("input.height").val h.toFixed 2
                    m.openPopup()
                    $p.find("input.title").focus()
            else
                @.openPopup()
                $p.find("input.title").focus()

        .on 'drag', (e)->
            updatePolyLine()
        .on 'dragstart', (e)->
            for one in markers
                one.setOpacity(0) if one isnt this
        .on 'dragend', (e)->
            $(@.getPopup().getContent()).find("input.height").val "N/A"
            for one in markers
                one.setOpacity(1.0)
        .addTo map

        # 削除ボタン
        $cont.find("button").on "click", (e)->
            markers = markers.filter (one)=>one isnt m
            m.remove()
            updatePolyLine()

        # テキストボックスで Enter か ESC を押したらバルーンを閉じる。
        $cont.find("input").on "keyup", (e)->
            if e.keyCode is 0x0d or e.keyCode is 0x1b
                m.closePopup()
                e.preventDefault()

        return m

    # ルートの赤い線
    polyline = L.polyline([], {color: 'red'}).addTo(map)
    .on 'click', (e)->
        p2 = map.project e.latlng
        crossBorder = 18 / (map.getZoom() + 1)
        for one, idx in markers
            break if markers.length <= idx + 1
            p1 = map.project one.getLatLng()
            p3 = map.project markers[idx+1].getLatLng()
            v21 = subtract p2, p1
            v31 = subtract p3, p1
            nv21 = normalize v21
            nv31 = normalize v31
            if calcLength(v21) < calcLength(v31) and 0 < getDotOf(v21, v31) and Math.abs(getCrossOf(nv31, nv21)) < crossBorder
                m = createMarkerAt e.latlng
                markers.splice(idx + 1, 0, m)
                updatePolyLine()
                break
        L.DomEvent.stopPropagation(e)

    # ルートの更新
    updatePolyLine = ->
        polyline.setLatLngs(m.getLatLng() for m in markers)

    # タイルが現在の map上で見えているか。
    # tile = {x: x, y: y, zoom: zoom}
    visibleOnMap = (tile)->
        mapB = map.getBounds()
        tl = getTileXYFromCoord map.project mapB.getNorthWest(), tile.zoom
        br = getTileXYFromCoord map.project mapB.getSouthEast(), tile.zoom
        tl.x <= tile.x <= br.x and tl.y <= tile.y <= br.y

    # urlの画像を読み込み、cb(img)を呼び出す。
    loadImage = (z, url, cb, errorcb)->
        $can = $store.children 'canvas[src="' + url + '"]'
        if 0 < $can.length
            # console.log "do recycle #{url}"
            cb $can[0]
        else
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
                $store.append($can)
                cb $can[0]
            .on "error", errorcb
            $img.attr "src", url

            # 古いのを削除する。
            $store.children 'canvas'
            .each (idx)->
                $t = $ @
                u = $t.attr "src"
                $t.remove() if not visibleOnMap getTileInfoFromURL u

    # 緯度軽度から標高を得る。
    getHeightFromLatLng = (latlng, zoom, cb) ->
        coord = map.project latlng, zoom
        url = getDEMURLFromTileXY getTileXYFromCoord(coord), zoom
        p = getPointOnTileFromCoord coord
        loadImage zoom, url, (canvas)->
            h = getHeightFromRGB getRGBFromImg canvas, p
            if isNaN(h) and zoom is 15
                getHeightFromLatLng latlng, 14, cb
            else
                cb h
        , (e)-> # 失敗したら10mBメッシュで取り直し。
            if zoom < 15 then cb Number.NaN else getHeightFromLatLng latlng, 14, cb


    #
    getAllHeights = (cb)->
        heights = []
        progress = 0
        $bar = $ progressbar
        $bar.attr {max: markers.length, value: 0}

        requestNext = ()->
            if progress < markers.length
                th = getTrueHeight markers[progress]
                if not isNaN th
                    proc th
                else
                    getHeightFromLatLng markers[progress].getLatLng(), 15, proc
            else
                $bar.val 0
                cb heights
        proc = (h)->
            heights.push h
            ++progress;
            $bar.val progress
            requestNext()

        requestNext()

    # バルーン内の本当の標高を得る。
    getTrueHeight = (m)->
        parseFloat $(m.getPopup().getContent()).find("input.height").val()

    ##--------------------------------------------------------------------
    # マップ右下のリンクを出す。
    L.tileLayer 'https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png',
        attribution: '<a href="https://maps.gsi.go.jp/development/ichiran.html" target="_blank">地理院タイル</a>'
        maxZoom: 18
    .addTo map

    # 地図上のクリックイベント
    map.on 'click', (e)->
        m = createMarkerAt e.latlng
        markers.push m
        updatePolyLine()

    # 日本を表示する。
    map.resetDefaultLocation()
    map

##==============================================================================
## jQuery 開始
$ ->
    # 説明画面
    closeHelp = (e)->$("#help").hide()
    $(".closeHelp").on "click", closeHelp
    if needsHelp() then nomoreHelp() else closeHelp()

    # UIの設定
    $("#menu").hide()
    $("#openButton").on "click", (e)->
        $(this).hide()
        $("#menu").show()

    $("#closeButton").on "click", (e)->
        $("#menu").hide()
        $("#openButton").show()

    ##--------------------------------------------------------------------
    # マップの初期化
    map = createMap "#store", "#progressbar"

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
                    $("#svgcanvas").append makeSVG data
                    $("#dataOutput").val makeSVGfile $ "#svgcanvas"

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
