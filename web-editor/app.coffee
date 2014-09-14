
# PLAN:
# + indicate visually on the charset grid which character is selected
# + tile editor for assembling 4x4 tiles and then map editor
#   - be able to select (changeable) color when painting characters on tiles
# - mirror, flip
# - In Sprite mode:
#   - Hi-res overlays
# - Reduce clutter: Remove Upload, Download and hires/muco mode selection UI since don't need it all the time
# - Show equivalent grays for colors
# - save and restore ( as JSON) the "state" ( which colors are selected, etc.)
# - bit limited, but remember changeable color for each entity and apply that color when painting on the macro
#   - localStorage["a"] = JSON.stringify( object )
#   - object = JSON.parse(localStorage["a"])

# + The character set should be shown in 8 rows, 32 glyphs wide
# + Character codes may be selected and the glyph is shown in the editor
# + The editor should be shown with 8x8 pixels for editing a single glyph
# + Clicking on a pixel within the editor should invert that pixel.  Holding
#   down will paint not by inverting but the inverted value of the click


class Color

  # @param  hex  Example: '#68372B'
  constructor: ( @hex ) ->
    @r = parseInt @hex.substr( 1, 2 ), 16
    @g = parseInt @hex.substr( 3, 2 ), 16
    @b = parseInt @hex.substr( 5, 2 ), 16

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
macro = null

in_hex = ( number ) ->
  hex = number.toString 16
  padding = if 1 < hex.length then '' else '0'
  padding+ hex

render_everything = () ->
  character_set.render()
  editor.render()
  macro.render()

# Rather than have structures that reflect character and sprite geometries, the
# backing data is kept as a single Array of byte ( each represented as a Number
# between 0 and 255), 16384 entries long ( for 256 64-byte sprites), in much
# the same format as the C64 itself uses.  This is because a single character
# set or sprite sheet may contain both hi-res and multi-color elements with no
# record of which is which, so this tool could not possibly export the data
# unless it was already in the format expected by the C64.
#
data = []
fill_out_data = ->
  # Ensure that data[] is filled with 0s rather than undefined values
  last_byte = mode.entity_stride * 256 - 1
  data[ address] ||= 0 for address in [0..last_byte]

selected_character_code = 0
selected_character = ->
  character_set.characters[ selected_character_code ]

copy_from_index = 0

# An Array of Color for ( in this order) background/transparent, changeable,
# shared #1, shared #2
chosen_color = ( C64_COLORS[i] for i in [ 0, 9, 8, 10 ])


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
    @context = @canvas.getContext '2d'
    @image_data = @context.createImageData  @canvas.width, @canvas.height

  pixel_at: ( row, column ) ->
    [ address, shift, mask ] = @directions_to  row, column
    ( data[address] & mask ) >> shift & mode.mask()

  # @param  color  0..3
  set_pixel: ( row, column, color ) ->
    [ address, shift, mask ] = @directions_to  row, column
    data[address] = data[address] & ~mask | color << shift

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
        color = chosen_color[ @pixel_at  sy, sx ]
        # Work out the base index within image_data.data of the 4 bytes that
        # control RGBA for the pixel
        pb = 4 * ( @image_data.width * y + x )
        @image_data.data[pb+0] = color.r
        @image_data.data[pb+1] = color.g
        @image_data.data[pb+2] = color.b
        @image_data.data[pb+3] = 255 # A
    @context.putImageData  @image_data, 0, 0

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
        data[ to_base+ mode.row_stride*row+ ofs] = data[ from_base+ mode.row_stride*row+ ofs]
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
          remember = data[ address+ ofs]
          for row in [0..last_row_index]
            data[ address+ row_stride*row+ ofs] = if row < last_row_index then data[ address+ row_stride*(row+1)+ ofs] else remember
      when 'down'
        for ofs in [0..row_stride-1]
          # Remember the contents of the last row
          remember = data[ address+ row_stride*last_row_index+ ofs]
          for row in [last_row_index..0]
            data[ address+ row_stride*row+ ofs] = if 0 < row then data[ address+ row_stride*(row-1)+ ofs] else remember
      when 'left'
        for row in [0..last_row_index]
          base = address+ row_stride* row
          # Grab the most significant pixel ready to feed in to the least
          # significant byte
          [ ignore, ousted ] = mode.rotate_left  data[ base+ 0]
          for ofs in [row_stride-1..0]
            [ rotated, ousted ] = mode.rotate_left  data[ base+ ofs], ousted
            data[ base+ ofs] = rotated
      when 'right'
        for row in [0..last_row_index]
          base = address+ row_stride* row
          # Grab the least significant pixel ready to feed in to the most
          # significant byte
          [ ignore, ousted ] = mode.rotate_right  data[ base+ row_stride-1]
          for ofs in [0..row_stride-1]
            [ rotated, ousted ] = mode.rotate_right  data[ base+ ofs], ousted
            data[ base+ ofs] = rotated
    render_everything()


class CharacterSet

  constructor: ->
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
    @render()

  render: ->
    character.render() for character in @characters

  when_character_clicked: ( event) =>
    selected_character_code = $(event.currentTarget).data 'code'
    $('#selected_character_code').html '$'+in_hex(selected_character_code)
    # The editor should show the newly selected character
    editor.render()

  import_from: ( encoded_text) ->
    data = Base64::decoded  encoded_text
    render_everything()

  export: ->
    # If the user is editing a charset but switched to sprites mode and then
    # back then only 2K not 16K should be exported
    to_export = if mode.asset_type is 'charset' and 2048 < data.length then data.slice 0, 2048 else data
    "cat <<. | base64 -d > charset.bin\n"+ Base64::encoded( to_export )+ "\n.\n"


class Editor

  constructor: ->
    @build()
    @brush = 1 # @brush remembers whether to paint with foreground or background pixels

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
    @render()

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

  paint: ( row, column) =>
    selected_character().set_pixel  row, column, @brush
    @render()
    selected_character().render()
    macro.render()

  render: () ->
    $('#editor').find('tr').each ( row, tr ) ->
      $(tr).children().each ( column, td ) ->
        $(td).css 'background-color', chosen_color[ selected_character().pixel_at  row, column ].hex


class Macro

  constructor: ->
    @canvases = []
    table = $('#macro')
    for row in [0..7]
      tr = elm 'tr', {}
      for column in [0..7]
        canvas = elm 'canvas', width:8*scale, height:8*scale
        $(canvas).data 'code', 0
        @canvases.push  canvas
        td = elm 'td', canvas
        $(tr).append  td
      table.append  tr
    table.find('canvas').click @when_button_pressed
    @render()

  when_button_pressed: ( event ) =>
    canvas = event.currentTarget
    $(canvas).data 'code', selected_character_code
    @render_canvas  canvas

  render: ->
    @render_canvas canvas for canvas in @canvases

  render_canvas: ( canvas ) ->
    code = $(canvas).data 'code'
    character = character_set.characters[ code]
    canvas.getContext('2d').putImageData  character.image_data, 0, 0


class Animation

  constructor: ->
    # Create the <canvas>, which depends upon the "scale" setting
    @canvas = elm 'canvas', width:8*scale, height:8*scale
    $('#animation_section').append @canvas
    # When the "Frames" field is changed..
    @frames_field = $ '#animation_section input'
    @frames_field.bind 'change keyup paste input', ( event) =>
      # Set the number of frames to play and reset the animation ( in case the
      # number of frames to play was reduced)
      parsed = parseInt $(event.currentTarget).val()
      @frames_to_play = if isNaN( parsed) then 0 else parsed
      @frame = 0
    fps = 5
    setInterval @animate, 1000/fps

  animate: =>
    character = character_set.characters[ selected_character_code + @frame]
    if character
      @canvas.getContext('2d').putImageData( character.image_data, 0, 0)
      @frame += 1
      @frame = 0 if @frames_to_play <= @frame


$(document).ready () ->

  fill_out_data()

  character_set = new CharacterSet()
  editor = new Editor()
  macro = new Macro()
  animate = new Animation()

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
      tds.push  color_td( color_id, C64_COLORS[ color_id].hex )
    $('#colors_by_luma').append  elm('tr', tds)

  # For when the color to which a color_source refers has been changed and the
  # UI should show the newly associated color
  update_color_source = ( source_index ) ->
    $($('#color_sources >div')[ source_index]).css 'background-color', chosen_color[ source_index].hex

  # When a color is chosen from the palette then the color source should be
  # updated to show the selected color
  $('#palette_dialog td.color').click () ->
    # "this" is a <td>
    dlg = $(this).closest '.dialog'
    color_source_index = dlg.data 'color_source'
    chosen_color[ color_source_index] = C64_COLORS[ $(this).data 'color_id']
    update_color_source  color_source_index
    render_everything()
    dlg.fadeOut 'fast'

  select_color_source = ( index, div ) ->
    editor.brush = index
    source_divs = $('#color_sources >div')
    source_divs.removeClass 'on_brush'
    $(source_divs[ index]).addClass 'on_brush'

  # When the page first loads, the color on the brush should be evident
  select_color_source  editor.brush

  # When a color source is selected, the brush should be dipped in to that color
  $('#color_sources >div').each ( i, div ) ->
    update_color_source  i
    $(div).click () ->
      # If the source clicked is already selected then choose the color from
      # the palette
      if editor.brush isnt i
        select_color_source  i
      else
        dlg = $ '#palette_dialog'
        # Tell the palette which color source it's manipulating
        dlg.data 'color_source', i
        dlg.fadeIn 'fast'

  # When multi-color mode is selected:
  #  + Background colors 1 and 2 should be revealed
  #  + Pixels in the editor should be double-wide but half as many
  $('#mode input').change () ->
    asset_mode = color_mode = null
    $('#mode input:checked').each ( i, input ) ->
      switch input.name
        when 'asset' then asset_mode = input.value
        when 'colors' then color_mode = input.value
    # Background colors #1 and #2 should only be shown in multi-color mode
    switch color_mode
      when 'hi-res' then $('.multi-color').fadeOut 'fast'
      when 'multi-color' then $('.multi-color').fadeIn 'fast'
    mode = MODE[ asset_mode][ color_mode]

    fill_out_data()
    character_set.render()
    editor.build()
    macro.render()

  $('#upload_button').click () ->
    $('#upload_dialog').fadeIn 'fast'

  $('#really_upload_button').click () ->
    character_set.import_from $('#upload_dialog textarea').val()
    $('#upload_dialog').fadeOut 'fast'

  $('#download_button').click () ->
    $('#download_dialog textarea').val  character_set.export()
    $('#download_dialog').fadeIn 'fast'

  $('#close_button').click () ->
    $('.dialog').fadeOut 'fast'

  # Hotkeys
  K_LEFT =   37
  K_UP =     38
  K_RIGHT =  39
  K_DOWN =   40
  K_DELETE = 46
  K_0      = 48
  K_1      = 49
  K_2      = 50
  K_3      = 51
  K_C =      67
  K_H =      72
  K_V =      86
  $('body').keyup ( event) ->
    switch event.which
      when K_H then $('#help_dialog').fadeToggle 'fast'
      when K_0 then select_color_source 0
      when K_1 then select_color_source 1
      when K_2 then select_color_source 2
      when K_3 then select_color_source 3
      when K_C then copy_from_index = selected_character_code
      when K_V then selected_character().copy_from  copy_from_index
      when K_UP then selected_character().slide 'up'
      when K_DOWN then selected_character().slide 'down'
      when K_LEFT then selected_character().slide 'left'
      when K_RIGHT then selected_character().slide 'right'
      when K_DELETE then selected_character().blank()
      else
        console.log 'Key released:', event.which

