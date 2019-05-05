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
    $NS = (elementName)->
        $ document.createElementNS SVGNS, elementName

    $path = (type, data)->
        $p = $NS "path"
        d = ""
        for one, idx in data
            d += "M" if idx is 0
            d += one.x + "," + one.y + " "
            d += "L" if idx is 0
        $p.attr { class: type, d: d }
        $p

    $text = (type, pos, anchor, str)->
        $t = $NS "text"
        $t.attr {class: type, x: pos.x, y: pos.y}
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
        $t

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

    $svg = $NS "svg"
    $svg.attr {
        xmlns: SVGNS
        version: "1.1"
        height: paperSize.y + "mm"
        width: paperSize.x + "mm"
        viewBox: "0 0 " + paperSize.x + " " + paperSize.y
    }

    $style = $ "<style>"
    $style.text "
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

    $svg.append $style

    $g = $NS "g"
    $svg.append $g


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
    $g.append $path "frame", [{x: x, y: y}, {x: x, y: y + 5}]
    $g.append $text "scale", {x: x, y: y + 5}, "S", (maxLength / 1000).toFixed 1


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
    $g.append $path "frame", [{x: x-5, y: y}, {x: x, y: y}]
    $g.append $text "scale", {x: x - 5, y: y}, "W", minHeight.toFixed 0
    # 最高標高
    y = yOnGraph maxHeight
    $g.append $path "frame", [{x: x-5, y: y}, {x: x, y: y}]
    $g.append $text "scale", {x: x - 5, y: y}, "W", maxHeight.toFixed 0

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
##==============================================================================
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


##==============================================================================
$ ()->
    # 説明画面
    storage = localStorage;
    helpPhase = storage.getItem "helpPhase"
    helpProgress = (e)->
        if 4 < helpPhase
            storage.setItem "helpPhase", helpPhase
            $("#help").hide()
        else if 0 < helpPhase
            $img = $ "<img>"
            $img.attr "src", "./img/help" + helpPhase + ".jpg"
            $("#help").empty().append $img
            helpPhase++
        else
            $("#js-caution").empty().text "クリックで使い方を説明します。"
            helpPhase = 1;

    $("#help").on "click", helpProgress
    helpProgress()



    # マップの初期化
    map = L.map "map"
    $store = $ "#store"

    # マップを初期状態にする。
    resetDefaultLocation = ()->
        map.setView [34.64302, 135], 5


    # 緯度軽度からピクセル値を得る。(原点は最左上タイルの左上。)
    getCoordFromLatLng = (latlng, zoom)->
        if 0 < zoom <= 14
            map.project latlng, zoom
        else
            map.project latlng, 15

    # タイルが現在の map上で見えているか。
    visibleOnMap = (tile)->
        mapB = map.getBounds()
        tl = getTileXYFromCoord getCoordFromLatLng mapB.getNorthWest(), tile.zoom
        br = getTileXYFromCoord getCoordFromLatLng mapB.getSouthEast(), tile.zoom
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
            $img.attr "crossOrigin", "Anonymous"
            $img.on "load", (e)->
                # console.log "load completed"
                img = e.target
                $can = $ "<canvas>"
                $can.attr "width", img.width
                $can.attr "height", img.height
                $can.attr "src", img.src
                ctx = $can[0].getContext('2d')
                ctx.drawImage img, 0, 0
                $store.append($can)
                cb $can[0]
            $img.on "error", errorcb
            $img.attr "src", url

            # 古いのを削除する。
            $store.children 'canvas'
            .each (idx)->
                $t = $ this
                u = $t.attr "src"
                $t.remove() if not visibleOnMap getTileInfoFromURL u
                # $tt = $t.remove() if not visibleOnMap getTileInfoFromURL u
                # if $tt?
                #     console.log "removing of " + $tt.attr "src"
                # true
                ##<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


    # 緯度軽度から標高を得る。
    getHeightFromLatLng = (latlng, zoom, cb) ->
        coord = getCoordFromLatLng latlng, zoom
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

    # マップ右下のリンクを出す。
    L.tileLayer 'https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png',
        attribution: '<a href="https://maps.gsi.go.jp/development/ichiran.html" target="_blank">地理院タイル</a>'
        maxZoom: 18
    .addTo map

    # 日本を表示する。
    resetDefaultLocation()

    # マーカー
    markers = []

    # マーカーの作成
    createMarkerAt = (latlng)->
        $cont = $ "<div><input class='title'></title><br>
                   緯度軽度: <span class='latlng'></span><br>
                   標高: <span class='height'></span><br>
                   標高(実際):<input class='trueheight'></input>m<br>
                   <button>削除</button></div>"

        m = L.marker latlng, {riseOnHover: true, draggable: true}
        .bindPopup $cont[0]
        .on 'click', (e)->
            ll = this.getLatLng()
            m = this
            getHeightFromLatLng ll, map.getZoom(), (h)->
                $p = $ m.getPopup().getContent()
                $p.find("span.latlng").text "#{ll.lat.toFixed(2)}, #{ll.lng.toFixed(2)}"
                $p.find("span.height").text h.toFixed 2
                m.openPopup()
                $p.find("input.title").focus()
                $p.find("input").on "keyup", (e)->
                    if e.keyCode is 0x0d or e.keyCode is 0x1b
                        m.closePopup()
                        e.preventDefault()
        .on 'drag', (e)->
            updatePolyLine()
        .on 'dragstart', (e)->
            for one in markers
                one.setOpacity(0.3) if one isnt this
        .on 'dragend', (e)->
            for one in markers
                one.setOpacity(1.0)
        .addTo map

        $cont.find("button").on "click", (e)->
            markers = markers.filter (one)=>one isnt m
            updatePolyLine()
            m.remove()

        return m

    # 地図上のクリックイベント
    map.on 'click', (e)->
        if helpPhase < 5
            helpPhase = 5
            helpProgress()

        m = createMarkerAt e.latlng
        markers.push m
        updatePolyLine()

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
    updatePolyLine = ()->
        polyline.setLatLngs markers.map (m)=>m.getLatLng()

    # UIの設定
    $("#menu").hide()
    $("#openButton").on "click", (e)->
        $(this).hide()
        $("#menu").show()

    $("#closeButton").on "click", (e)->
        $("#menu").hide()
        $("#openButton").show()

    #
    getTrueHeight = (m)->
        parseFloat $(m.getPopup().getContent()).find("input.trueheight").val()

    #
    getAllHeights = (cb)->
        heights = []
        progress = 0
        $bar = $ "#progressbar"
        $bar.attr {max: markers.length, value: 0}
        $bar.removeClass "hide"

        requestNext = ()->
            if progress < markers.length
                th = getTrueHeight markers[progress]
                if not isNaN th
                    proc th
                else
                    getHeightFromLatLng markers[progress].getLatLng(), 15, proc
            else
                $bar.addClass "hide"
                cb heights
        proc = (h)->
            heights.push h
            ++progress;
            $bar.attr "value", progress
            requestNext()

        requestNext()

    #
    clearAll = ()->
        for one in markers
            one.remove()
        markers = []
        updatePolyLine()
        $("#svgcanvas").empty()

    #
    getAllData = (cb)->
        getAllHeights (heights)->
            walklength = 0
            dists = []
            for one, idx in markers
                if idx is 0
                    dists.push 0
                else
                    walklength += markers[idx-1].getLatLng()
                        .distanceTo one.getLatLng()
                    dists.push walklength
            data = []
            for one, i in markers
                data.push { x: dists[i], y: heights[i], label: $(one.getPopup().getContent()).find("input.title").val()}

            cb data


    $("#createData").on "click", (e)->
        sel = ($ "#dataFormat")[0]
        switch sel.options[sel.selectedIndex].value
            when "CSV"
                getAllData (data)->
                    str = ""
                    for one in data
                        str += one.x.toFixed(2) + ", " + one.y.toFixed(2) + ", " + one.label + "\r\n"
                    $("#dataOutput").val str

            when "JSON"
                data = []
                for m in markers
                    p = m.getLatLng()
                    $c = $ m.getPopup().getContent()
                    data.push ({
                        lat: p.lat
                        lng: p.lng
                        title: $c.find("input.title").val()
                        trueHeight: Number $c.find("input.trueheight").val()
                    })
                $("#dataOutput").val JSON.stringify data

            when "SVG"
                $("#svgcanvas").empty()
                getAllData (data)->
                    $("#svgcanvas").append makeSVG data
                    $("#dataOutput").val '<?xml version="1.0" encoding="UTF-8"?>' + $("#svgcanvas").html()

    $("#clearAll").on "click", (e)->
        clearAll()

    $("#loadData").on "click", (e)->
        clearAll()
        for data in JSON.parse $("#dataOutput").val()
            m = createMarkerAt L.latLng data.lat, data.lng
            $c = $ m.getPopup().getContent()
            $c.find("input.title").val(data.title)
            $c.find("input.trueheight").val(data.trueHeight)
            markers.push m
        updatePolyLine()

    $("#showHelp").on "click", (e)->
        $("#help").show()
        helpPhase = 1
        helpProgress()
