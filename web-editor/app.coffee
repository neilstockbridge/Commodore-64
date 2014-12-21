
# PLAN:
# - Reduce clutter: Remove Upload, Download and hires/muco mode selection UI since don't need it all the time
# - Upload an image and show it behind the sprite frame ( allows hand-drawn sprites to be scanned and used as background similar to Blender)
# - In Sprite mode, could use the last ( unused) byte of each 64-byte block to store the changeable color
# + indicate visually on the charset grid which character is selected
# - mirror, flip
# - In Sprite mode:
#   - Hi-res overlays
# - Be able to select a sequence of frames for animation such as $6, $7, $8, $7
# - In Character mode, only color IDs 0..7 may be chosen for the changeable color since the MSB of the Color RAM nybble is used to select hi-res character: 0:hi-res, 1:muco
# - Remember for each character and sprite whether it's intended for display as hi-res or multi-color
# - copy range of entities
# - remove all use of <table> since <div> of <canvas> works nicely
# - Use mouse to position cursor but then use KEYS to paint in the various
#   colors, eliminates "mode" of selected color
# - copy and paste should copy the changeable color too
# - should be able to choose different shared colors #1 and #2 in sprite mode
# - copy and paste should use hover target rather than selected character
# - bug: try noticing mouseOut in the editor and picking up the brush
# - be able to export an array for lookup of changeable color to use per character
# - performance: maybe instead of watching mouseMove events, watch for mouseEnter and paint if the button is held down
# - be able to draw directly on to the macro, so that large assemblies of characters can be edited as if they were a single entity


# FEATURES
# - Edit both characters and sprites in both hi-res and multi-color mode in the
#   same bank
# - 256 characters or sprites from the bank are shown
# - The data model is 16K of bytes, so hi-res and multi-color can be mixed in
#   the same session
# - Entity ( either character or sprite) manipulation:
#   - Blank
#   - Copy
#   - Slide
# - In hi-res mode, clicking on a pixel within the editor inverts that pixel.
#   Holding down will paint not by inverting but the inverted value of the
#   pixel under the initial click
# - Save to and load from HTML5 local storage, or export and import as base64.
#   No server-side other than a web server that can serve static files with the
#   correct MIME type is required.
# - Assemble characters in to 4x4 tiles and paint them on to a scrollable world
#   map


class Color

  background_color: 0
  shared_color_1: 9
  shared_color_2: 8
  id_for: {'charset':{}, 'sprites':{}}
  for i in [0..255]
    Color::id_for['charset'][i] = 10
    Color::id_for['sprites'][i] = 10


  # @param  hex  Example: '#68372B'
  constructor: ( @hex ) ->
    @r = parseInt @hex.substr( 1, 2 ), 16
    @g = parseInt @hex.substr( 3, 2 ), 16
    @b = parseInt @hex.substr( 5, 2 ), 16

  with_id: ( color_id ) ->
    C64_COLORS[ color_id ]

  choose: ( pixel_value, color_id ) ->
    switch mode.color_mode
      when 'hi-res'
        switch pixel_value
          when 0 then Color::background_color = color_id
          when 1 then Color::id_for[mode.asset_type][selected_character_code] = color_id
      when 'multi-color'
        switch pixel_value
          when 0 then Color::background_color = color_id
          when 1 then Color::shared_color_1 = color_id
          when 2 then Color::shared_color_2 = color_id
          when 3 then Color::id_for[mode.asset_type][selected_character_code] = color_id

  # @param  index  The character code or sprite number
  for_pixel_value: ( pixel_value, index ) ->
    index ?= selected_character_code
    color_id = switch mode.color_mode
      when 'hi-res'
        switch pixel_value
          when 0 then Color::background_color
          when 1 then Color::id_for[mode.asset_type][index]
      when 'multi-color'
        switch pixel_value
          when 0 then Color::background_color
          when 1 then Color::shared_color_1
          when 2 then Color::shared_color_2
          when 3 then Color::id_for[mode.asset_type][index]
    C64_COLORS[ color_id]


# FIXME: Move in to Color class
C64_COLORS = ( new Color hex for hex in [
  '#000000',
  '#FFFFFF',
  '#68372B',
  '#70A4B2',
  '#6F3D86',
  '#588D43',
  '#352879',
  '#B8C76F',
  '#6F4F25',
  '#433900',
  '#9A6759',
  '#444444',
  '#6C6C6C',
  '#9AD284',
  '#6C5EB5',
  '#959595',
])
# http://www.pepto.de/projects/colorvic/
COLORS_BY_LUMA = [
  [ 0],
  [ 6, 9],
  [ 2, 0xb],
  [ 4, 8],
  [ 0xc, 0xe],
  [ 5, 0xa],
  [ 3, 0xf],
  [ 7, 0xd],
  [ 1],
]

scale = 3 # number of on-screen pixels to each C64 pixel

character_set = null
editor = null
tile_palette = null
tile_editor = null
world = null

in_hex = ( number ) ->
  hex = number.toString 16
  padding = if 1 < hex.length then '' else '0'
  padding+ hex

render_everything = () ->
  character_set.render()
  editor.render()
  tile_palette.render()
  tile_editor.render()
  world.render()

selected_character_code = 0
selected_character = ->
  character_set.characters[ selected_character_code ]

copy_from_index = 0


# Mode is a handy box of numbers required for accessing memory correctly
# depending on whether a character set or sprites are being edited and whether
# multi-color or hi-res mode is in use.
#
#  row_stride:  The number of bytes to add to a memory address to step from the
#               beginning of one row to the beginning of the next
#
class Mode
  # @param  asset_type  'charset' or 'sprites'
  # @param  color_mode  'hi-res' or 'multi-color'
  constructor: ( @asset_type, @color_mode ) ->
    @entity_width = switch @asset_type
      when 'charset' then @entity_height = 8;  8
      when 'sprites' then @entity_height = 21; 24
    @entity_width /= 2 if @color_mode is 'multi-color'
    @entity_stride = if @asset_type is 'sprites' then 64 else 8
    @row_stride = if @asset_type is 'sprites' then 3 else 1
    @pixels_per_byte = if @color_mode is 'hi-res' then 8 else 4

  # Provides the bit shift required to move the value of a ( intra-byte) pixel
  # down to the LSB
  shift: ( column ) ->
    switch @color_mode
      when 'hi-res' then 7 - (column & 0x7)
      when 'multi-color' then 2 * (3 - (column & 0x3))

  mask: ->
    if @color_mode is 'hi-res' then 0x1 else 0x3

  rotate_left: ( value, filler ) ->
    switch @color_mode
      when 'hi-res' then [ value << 1  & 0xff | filler, value >> 7  & 0x1 ]
      when 'multi-color' then [ value << 2  & 0xff | filler, value >> 6  & 0x3 ]

  rotate_right: ( value, filler ) ->
    switch @color_mode
      when 'hi-res' then [ value >> 1 | filler, (value & 0x1) << 7 ]
      when 'multi-color' then [ value >> 2 | filler, (value & 0x3) << 6 ]

MODE = {}
for asset_mode in ['charset','sprites']
  MODE[ asset_mode] = {}
  for color_mode in ['hi-res','multi-color']
    MODE[ asset_mode][ color_mode] = new Mode asset_mode, color_mode

mode = MODE['charset']['multi-color']


class Character

  constructor: ( @code ) ->
    @canvas = elm 'canvas', width:8*scale, height:8*scale
    @build()

  build: ->
    @internal_canvas = elm 'canvas', width:mode.entity_width, height:mode.entity_height
    @context = @internal_canvas.getContext '2d'
    @image_data = @context.createImageData  mode.entity_width, mode.entity_height

  pixel_at: ( row, column ) ->
    [ address, shift, mask ] = @directions_to  row, column
    ( character_set.data[address] & mask ) >> shift & mode.mask()

  # @param  color  0..3
  set_pixel: ( row, column, pixel_value ) ->
    [ address, shift, mask ] = @directions_to  row, column
    character_set.data[address] = character_set.data[address] & ~mask | pixel_value << shift

  # Provides the memory address of the byte that controls the pixel at the
  # specified row and column along with the shift required to being the pixel
  # down to the LSB and the mask required to isolate the pixel from other
  # pixels controlled by the same byte
  directions_to: ( row, column ) ->
    address = mode.entity_stride * @code + mode.row_stride * row + parseInt( column / mode.pixels_per_byte)
    shift = mode.shift  column
    mask = mode.mask() << shift
    [ address, shift, mask ]

  render: =>
    # Go through every pixel in the canvas
    for y in [0..@image_data.height - 1]
      # Work out the y ordinate within the character data that sources the
      # color for this ( on-screen) pixel
      sy = parseInt  y * mode.entity_height / @image_data.height
      for x in [0..@image_data.width - 1]
        sx = parseInt  x * mode.entity_width / @image_data.width
        color = Color::for_pixel_value @pixel_at( sy, sx), @code
        # Work out the base index within image_data.data of the 4 bytes that
        # control RGBA for the pixel
        pb = 4 * ( @image_data.width * y + x )
        @image_data.data[pb+0] = color.r
        @image_data.data[pb+1] = color.g
        @image_data.data[pb+2] = color.b
        @image_data.data[pb+3] = 255 # A
    @context.putImageData  @image_data, 0, 0
    @canvas.getContext('2d').drawImage @internal_canvas, 0, 0, @canvas.width, @canvas.height

  blank: ->
    for row in [0..mode.entity_height-1]
      for column in [0..mode.entity_width-1]
        @set_pixel row, column, 0
    render_everything()

  copy_from: ( index ) ->
    from_base = mode.entity_stride * copy_from_index
    to_base = mode.entity_stride * @code
    for row in [0..mode.entity_height-1]
      for ofs in [0..mode.row_stride-1]
        character_set.data[ to_base+ mode.row_stride*row+ ofs] = character_set.data[ from_base+ mode.row_stride*row+ ofs]
    render_everything()

  slide: ( direction) ->
    [ address, shift, mask ] = @directions_to  0, 1
    last_row_index = mode.entity_height - 1
    row_stride = mode.row_stride

    switch direction
      when 'up'
        for ofs in [0..row_stride-1]
          # Remember the contents of the first row because it is about to be
          # overwitten by the contents of the second row
          remember = character_set.data[ address+ ofs]
          for row in [0..last_row_index]
            character_set.data[ address+ row_stride*row+ ofs] = if row < last_row_index then character_set.data[ address+ row_stride*(row+1)+ ofs] else remember
      when 'down'
        for ofs in [0..row_stride-1]
          # Remember the contents of the last row
          remember = character_set.data[ address+ row_stride*last_row_index+ ofs]
          for row in [last_row_index..0]
            character_set.data[ address+ row_stride*row+ ofs] = if 0 < row then character_set.data[ address+ row_stride*(row-1)+ ofs] else remember
      when 'left'
        for row in [0..last_row_index]
          base = address+ row_stride* row
          # Grab the most significant pixel ready to feed in to the least
          # significant byte
          [ ignore, ousted ] = mode.rotate_left  character_set.data[ base+ 0]
          for ofs in [row_stride-1..0]
            [ rotated, ousted ] = mode.rotate_left  character_set.data[ base+ ofs], ousted
            character_set.data[ base+ ofs] = rotated
      when 'right'
        for row in [0..last_row_index]
          base = address+ row_stride* row
          # Grab the least significant pixel ready to feed in to the most
          # significant byte
          [ ignore, ousted ] = mode.rotate_right  character_set.data[ base+ row_stride-1]
          for ofs in [0..row_stride-1]
            [ rotated, ousted ] = mode.rotate_right  character_set.data[ base+ ofs], ousted
            character_set.data[ base+ ofs] = rotated
    render_everything()


class CharacterSet

  constructor: ->
    # Rather than have structures that reflect character and sprite geometries, the
    # backing data is kept as a single Array of byte ( each represented as a Number
    # between 0 and 255), 16384 entries long ( for 256 64-byte sprites), in much
    # the same format as the C64 itself uses.  This is because a single character
    # set or sprite sheet may contain both hi-res and multi-color elements with no
    # record of which is which, so this tool could not possibly export the data
    # unless it was already in the format expected by the C64.
    #
    @data = []
    @characters = [] # Array[0..255] of Character objects by character code
    # Build the grid for the character set / sprite sheet
    table = $('#charset')
    for row in [0..7]
      tr = $( elm 'tr', {})
      for column in [0..31]
        character_code = 32 * row + column
        character = new Character character_code
        @characters[ character_code] = character
        td = elm 'td', title:'$'+in_hex(character_code), character.canvas
        $(td).data 'code', character_code
        tr.append  td
      table.append  tr
    table.find('td').click @when_character_clicked

  fill_out_data: ->
    # Ensure that data[] is filled with 0s rather than undefined values
    last_byte = mode.entity_stride * 256 - 1
    @data[ address] ||= 0 for address in [0..last_byte]

  render: ->
    character.render() for character in @characters

  when_character_clicked: ( event) =>
    selected_character_code = $(event.currentTarget).data 'code'
    $('#selected_character_code').html '$'+in_hex(selected_character_code)
    # The editor should show the newly selected character
    editor.render()

  data_for_export: ->
    # If the user is editing a charset but switched to sprites mode and then
    # back then only 2K not 16K should be exported
    if mode.asset_type is 'charset' and 2048 < @data.length then @data.slice 0, 2048 else @data


class Editor

  constructor: ->
    @build()
    # When the page first loads, the color on the brush should be evident
    @choose_brush 1 # @brush remembers whether to paint with foreground or background pixels
    # When a color source is selected, the brush should be dipped in to that color
    $('#color_sources >div').each ( i, div ) ->
      $(div).click () ->
        # If the source clicked is already selected then choose the color from
        # the palette
        if editor.brush isnt i
          editor.choose_brush  i
        else
          dlg = $ '#palette_dialog'
          # Tell the palette which color source it's manipulating
          dlg.data 'pixel_value', $(div).data('pixel_value')
          dlg.fadeIn 'fast'

  build: ->
    # The number of rows and columns change with the mode:
    #  + 8x8 for hi-res charset
    #  + 4x8 for multi-color charset
    #  + 24x21 for hi-res sprite
    #  + 12x21 for multi-color sprite
    table = $('#editor')
    # Toggle the CSS class "hi-res" on the <table> so that CSS can widen the cells
    table.toggleClass 'hi-res', ( mode.color_mode is 'hi-res')
    # Remove any previously added <tr>s
    table.find('tr').remove()
    # Add the <tr>s for this mode
    last_row = mode.entity_height - 1
    for row in [0..last_row]
      tr = elm 'tr', {}
      last_column = mode.entity_width - 1
      for column in [0..last_column]
        td = elm 'td', {}
        $(td).data 'row', row
        $(td).data 'column', column
        $(tr).append  td
      table.append  tr
    table.find('td').mousedown(@when_button_pressed).mouseup @when_button_released
    # Background colors #1 and #2 should only be shown in multi-color mode
    switch mode.color_mode
      when 'hi-res' then $('.multi-color').fadeOut 'fast'
      when 'multi-color' then $('.multi-color').fadeIn 'fast'
    # In multi-color mode, #color_sources >div#3 relates to pixel_value:3 but
    # in hi-res mode, div#3 relates to pixel_value:1
    # Attach the pixel_value to each color source
    $('#color_sources >div').each ( i, div ) ->
      $(div).data 'pixel_value', if mode.color_mode is 'multi-color' or i < 3 then i else 1
    @render()

  choose_brush: ( pixel_value ) ->
    @brush = pixel_value
    # The chosen color source should indicate that it is selected
    $('#color_sources >div').each ( i, div ) ->
      div = $ div
      if div.data('pixel_value') is pixel_value
        div.addClass 'on_brush'
      else
        div.removeClass 'on_brush'

  # Applies the background brush to the pixel under the cursor
  blank: ( td ) ->
    [ row, column ] = ($(td).data k for k in ['row','column'])
    @paint row, column, 0

  coordinates_from: ( event) ->
    td = $(event.currentTarget)
    [ td.data('row'), td.data('column') ]

  when_button_pressed: ( event) =>
    # The location within the grid of the cell clicked is encoded in the id of
    # the element as "e03" for row 0, column 3
    [ row, column] = @coordinates_from  event
    # The brush should be the opposite of the pixel currently underneath the cursor
    if mode.color_mode is 'hi-res'
      @brush = 1 - selected_character().pixel_at( row, column)
    # If the pixel is cleared ( transparent, background color) then go in to
    # "set" mode for setting pixels until the mouse button is released
    $('#editor').find('td').on 'mousemove', @when_dragged
    @paint  row, column

  when_dragged: ( event) =>
    [ row, column] = @coordinates_from  event
    @paint  row, column
    # Prevent the drag being interpreted as something else by the browser
    false

  when_button_released: ( event) =>
    $('#editor').find('td').off 'mousemove'

  paint: ( row, column, brush=@brush) =>
    selected_character().set_pixel  row, column, brush
    @render()
    selected_character().render()
    tile_palette.render()
    tile_editor.render()
    world.render()

  render: () ->
    $('#editor').find('tr').each ( row, tr ) ->
      $(tr).children().each ( column, td ) ->
        $(td).css 'background-color', Color::for_pixel_value( selected_character().pixel_at  row, column ).hex
    $('#color_sources >div:visible').each ( pixel_value, div ) ->
      $(div).css 'background-color', Color::for_pixel_value( pixel_value).hex



class ColorPalette
  constructor: ->
    # Snippet to create <td> elements in palette_dialog
    color_td = ( color_id, color_as_hex ) ->
      cls = if color_id? then 'color' else null
      td = elm 'td', class:cls, style:'background-color:'+color_as_hex
      # Record the index within C64_COLORS so that the palette_dialog knows which
      # color source to configure
      $(td).data 'color_id', color_id if color_id?
      td

    # Add C64_COLORS to the palette_dialog
    $.each C64_COLORS, ( color_id, color ) ->
      td = color_td  color_id, color.hex
      $('#colors_by_id').append  elm('tr', td)
    $.each COLORS_BY_LUMA, ( i, color_ids ) ->
      luma = in_hex parseInt( 255 * i / (COLORS_BY_LUMA.length-1))
      luma_as_hex = '#'+ luma+ luma+ luma
      tds = []
      # Add a cell to show the luma
      tds.push  color_td(  null, luma_as_hex )
      # Add the color cell(s)
      for color_id in color_ids
        tds.push  color_td( color_id, Color::with_id(color_id).hex )
      $('#colors_by_luma').append  elm('tr', tds)

    # When a color is chosen from the palette then the color source should be
    # updated to show the selected color
    $('#palette_dialog td.color').click () ->
      color_td = $(this)
      dlg = color_td.closest '.dialog'
      pixel_value = dlg.data 'pixel_value'
      selected_color_id = color_td.data 'color_id'
      Color::choose  pixel_value, selected_color_id
      render_everything()
      dlg.fadeOut 'fast'


  when_button_pressed: ( event ) =>
    canvas = event.currentTarget
    $(canvas).data 'code', selected_character_code
    @render_canvas  canvas


# A Tile Design is a matrix of character codes that can be applied to the
# world map in one go.  In fact, the map is simply a matrix of tiles.
#
class TileDesign

  width: 4 # characters
  height: 4

  constructor: ( @design_id ) ->
    @canvas = elm 'canvas', width:8*TileDesign::width, height:8*TileDesign::height
    @context = @canvas.getContext '2d'
    $(@canvas).click @when_clicked

  when_clicked: =>
    tile_editor.selected_tile_design_id = @design_id
    tile_editor.render()
    $('#tile_palette_dialog').fadeOut 'fast'

  address_of: ( row, column ) ->
    base = TileDesign::width * TileDesign::height * @design_id
    base + TileDesign::width * row + column

  character_code_at: ( row, column ) ->
    tile_palette.data[ @address_of row, column ]

  paint: ( row, column, character_code ) ->
    tile_palette.data[ @address_of row, column ] = character_code

  render: ->
    for row in [0..TileDesign::height-1]
      for column in [0..TileDesign::width-1]
        character = character_set.characters[ @character_code_at  row, column ]
        @canvas.getContext('2d').drawImage  character.internal_canvas, 8*column, 8*row


class TilePalette

  constructor: ->
    @designs = []
    @data = new Array TileDesign::width*TileDesign::height*256 # Array of bytes
    # All designs should initially refer to character code 0
    for i in [0..@data.length-1]
      @data[ i] = 0
    # Make 16 rows each with 16 <canvas> elements, one for each tile design
    for row in [0..15]
      row_div = elm 'div', {}
      for column in [0..15]
        design_id = 16* row+ column
        pt = new TileDesign( design_id)
        @designs.push  pt
        row_div.appendChild  pt.canvas
      $('#tile_palette').append row_div

  render: ->
    pt.render() for pt in @designs

  data_for_export: ->
    @data


class TileEditor

  constructor: ->
    for row in [0..TileDesign::height-1]
      row_div = elm 'div', {}
      for column in [0..TileDesign::width-1]
        canvas = elm 'canvas', width:TileDesign::width*scale*2, height:TileDesign::height*scale*2
        $(canvas).data 'row_within_tile', row
        $(canvas).data 'column_within_tile', column
        $(canvas).click @when_cell_clicked
        row_div.appendChild  canvas
      $('#tile_editor').append row_div
      @selected_tile_design_id = 0
    @render()

  when_cell_clicked: ( event ) =>
    @paint event.currentTarget, selected_character_code

  blank: ( canvas ) ->
    @paint canvas, 0

  paint: ( canvas, character_code ) ->
    # Apply the currently selected character code to the currently selected
    # tile at the cell clicked
    row = $(canvas).data 'row_within_tile'
    column = $(canvas).data 'column_within_tile'
    design = tile_palette.designs[@selected_tile_design_id ]
    design.paint  row, column, character_code
    @render()
    tile_palette.render()
    world.render()

  render: ->
    design = tile_palette.designs[@selected_tile_design_id]
    $('#tile_editor canvas').each ( i, canvas ) ->
      row = $(canvas).data 'row_within_tile'
      column = $(canvas).data 'column_within_tile'
      character = character_set.characters[ design.character_code_at( row, column )]
      canvas.getContext('2d').drawImage  character.internal_canvas, 0, 0, canvas.width, canvas.height


class World

  constructor: ->

    @width = 32 # tiles
    @height = 8 # tiles
    @data = new Array @width* @height  # Array of bytes.  Begins with tile cell
    # in upper-left then proceeds right across the world.  Each cell refers to
    # a tile design
    for y in [0..@height-1]
      for x in [0..@width-1]
        @paint x, y, 0

    @view_width = 8
    @view_height = 5
    @view_x = 0
    @view_y = 0
    for row in [0..@view_height-1]
      row_div = elm 'div', {}
      for column in [0..@view_width-1]
        canvas = elm 'canvas', width:8*4*scale, height:8*4*scale
        $(canvas).click @when_cell_clicked
        $(canvas).data 'column_within_view', column
        $(canvas).data 'row_within_view', row
        row_div.appendChild  canvas
      $('#world').append  row_div
    @render()

  when_cell_clicked: ( event ) =>
    canvas = event.currentTarget
    @apply_design  canvas, tile_editor.selected_tile_design_id

  blank: ( canvas ) ->
    @apply_design  canvas, 0

  apply_design: ( canvas, tile_design_id ) ->
    x = @view_x+ $(canvas).data 'column_within_view'
    y = @view_y+ $(canvas).data 'row_within_view'
    @paint  x, y, tile_design_id
    @render()

  tile_design_id_at: ( x, y ) ->
    @data[ @width*y+ x]

  paint: ( x, y, tile_design_id ) ->
    @data[ @width*y+ x] = tile_design_id

  pan_view: ( direction ) ->
    switch direction
      when 'left' then if 0 < @view_x
        @view_x -= 1
      when 'right' then if @view_x < @width - @view_width
        @view_x += 1
      when 'up' then if 0 < @view_y
        @view_y -= 1
      when 'down' then if @view_y < @height - @view_height
        @view_y += 1
    @render()

  render: ->
    $('#world canvas').each ( i, canvas ) =>
      x = @view_x+ $(canvas).data 'column_within_view'
      y = @view_y+ $(canvas).data 'row_within_view'
      design_id = @data[ @width*y+ x ]
      design_canvas = tile_palette.designs[ design_id].canvas
      canvas.getContext('2d').drawImage  design_canvas, 0, 0, canvas.width, canvas.height
      $(canvas).data('wx', x).data 'wy', y

  choose_tile: ->
    tile_canvas = $ '#world canvas:hover'
    [ x, y ] = ( tile_canvas.data k for k in ['wx', 'wy'])
    tile_palette.designs[ @tile_design_id_at x, y ].when_clicked()
    tile_editor.render()

  data_for_export: ->
    @data


class Animation

  constructor: ->
    # Create the <canvas>, which depends upon the "scale" setting
    @canvas = elm 'canvas', width:24*scale, height:21*scale
    $('#animation_section').append @canvas
    # When the "Frames" field is changed..
    @frames_field = $ '#animation_section input'
    @frames_field.bind 'change keyup paste input', ( event) =>
      # Set the number of frames to play and reset the animation ( in case the
      # number of frames to play was reduced)
      parsed = parseInt $(event.currentTarget).val()
      @frames_to_play = if isNaN( parsed) then 0 else parsed
      @first_frame = selected_character_code
      @frame = 0
    fps = 5
    setInterval @animate, 1000/fps

  animate: =>
    character = character_set.characters[ @first_frame + @frame]
    if character
      @canvas.getContext('2d').drawImage  character.internal_canvas, 0, 0, @canvas.width, @canvas.height
      @frame += 1
      @frame = 0 if @frames_to_play <= @frame


$(document).ready () ->

  character_set = new CharacterSet()
  character_set.fill_out_data()
  character_set.render()
  editor = new Editor()
  color_palette = new ColorPalette()
  tile_palette = new TilePalette()
  tile_palette.render()
  tile_editor = new TileEditor()
  world = new World()
  animate = new Animation()

  # When multi-color mode is selected:
  #  + Background colors 1 and 2 should be revealed
  #  + Pixels in the editor should be double-wide but half as many
  $('#mode input').change () ->
    asset_mode = color_mode = null
    $('#mode input:checked').each ( i, input ) ->
      switch input.name
        when 'asset' then asset_mode = input.value
        when 'colors' then color_mode = input.value
    mode = MODE[ asset_mode][ color_mode]

    # The map should be shown only in character mode:
    method = if mode.asset_type is 'sprites' then 'fadeOut' else 'fadeIn'
    $('#world')[ method] 'fast'

    character_set.fill_out_data()
    for c in character_set.characters
      c.build()
    character_set.render()
    editor.build()

  $('#really_upload_button').click ->
    container = $(this).data 'container'
    container.data = Base64::decoded $('#upload_dialog textarea').val()
    render_everything()
    $('#upload_dialog').fadeOut 'fast'

  configure_import_and_export = ( import_button_id, export_button_id, container, filename ) ->
    # When the Import button related to "container" is clicked..
    $( import_button_id).click ->
      # Give "container" to #really_upload_button
      $('#really_upload_button').data 'container', container
      $('#upload_dialog').fadeIn 'fast'

    $( export_button_id).click ->
      command = "cat <<. | base64 -d > #{filename}\n"+ Base64::encoded( container.data_for_export() )+ "\n.\n"
      $('#download_dialog textarea').val  command
      $('#download_dialog').fadeIn 'fast'

  configure_import_and_export '#upload_button', '#download_button', character_set, 'charset.bin'
  configure_import_and_export '#import_tiles_button', '#export_tiles_button', tile_palette, 'tile_designs.bin'
  configure_import_and_export '#import_map_button', '#export_map_button', world, 'world_map.bin'

  close_dialog = ->
    $('.dialog').fadeOut 'fast'

  $('.close_button').click  close_dialog

  save_to_local_storage = ->
    save = ( data, name ) ->
      localStorage[ name] = JSON.stringify( data )
    save  character_set.data, 'data'
    save  Color::id_for, 'changeable_colors'
    save  tile_palette.data, 'tile_design_data'
    save  world.data, 'world_data'
    console.log 'Saved'

  load_from_local_storage = ->
    load = ( name ) ->
      JSON.parse localStorage[ name ]
    character_set.data = load 'data'
    Color::id_for = load 'changeable_colors'
    tile_palette.data = load 'tile_design_data'
    world.data = load 'world_data'
    render_everything()

  blank = ->
    # Work out whether the mouse is hovering over the character editor, the
    # tile editor or the world map editor
    on_character = $ '#editor td:hover'
    on_tile = $ '#tile_editor canvas:hover'
    on_world_map = $ '#world canvas:hover'
    editor.blank  on_character[0] if on_character.length != 0
    tile_editor.blank  on_tile[0] if on_tile.length != 0
    world.blank  on_world_map[0] if on_world_map.length != 0

  # Hotkeys
  K_ESCAPE = 27
  K_LEFT =   37
  K_UP =     38
  K_RIGHT =  39
  K_DOWN =   40
  K_DELETE = 46
  K_0      = 48
  K_1      = 49
  K_2      = 50
  K_3      = 51
  K_A =      65
  K_C =      67
  K_D =      68
  K_F =      70
  K_G =      71
  K_H =      72
  K_L =      76
  K_S =      83
  K_T =      84
  K_V =      86
  K_W =      87
  K_X =      88
  $('body').keyup ( event) ->
    switch event.which
      when K_H then $('#help_dialog').fadeToggle 'fast'
      when K_0 then editor.choose_brush 0
      when K_1 then editor.choose_brush 1
      when K_2 then editor.choose_brush 2 if mode.color_mode is 'multi-color'
      when K_3 then editor.choose_brush 3 if mode.color_mode is 'multi-color'
      when K_X then blank()
      when K_C then copy_from_index = selected_character_code
      when K_V then selected_character().copy_from  copy_from_index
      when K_T then $('#tile_palette_dialog').fadeToggle 'fast'
      when K_G then world.choose_tile()
      when K_W then world.pan_view 'up'
      when K_A then world.pan_view 'left'
      when K_S then world.pan_view 'down'
      when K_D then world.pan_view 'right'
      when K_UP then selected_character().slide 'up'
      when K_DOWN then selected_character().slide 'down'
      when K_LEFT then selected_character().slide 'left'
      when K_RIGHT then selected_character().slide 'right'
      when K_DELETE then selected_character().blank()
      when K_F then save_to_local_storage()
      when K_L then load_from_local_storage()
      when K_ESCAPE then close_dialog()
      else
        console.log 'Key released:', event.which

