
# PLAN:
# + indicate visually on the charset grid which character is selected
# + tile editor for assembling 4x4 tiles and then map editor
# - Erase, mirror, flip, pan ( move)
# - In Sprite mode:
#   - Hi-res overlays


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

scale = 3 # number of on-screen pixels to each C64 pixel

character_set = null
editor = null
macro = null

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

# An Array of Color for ( in this order) background, foreground, background #1,
# background #2
chosen_color = ( C64_COLORS[i] for i in [ 6, 14, 2, 3 ])


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
        td = elm 'td', title:@in_hex(character_code), character.canvas
        $(td).data 'code', character_code
        tr.append  td
      table.append  tr
    table.find('td').click @when_character_clicked
    @render()

  render: ->
    character.render() for character in @characters

  when_character_clicked: ( event) =>
    selected_character_code = $(event.currentTarget).data 'code'
    $('#selected_character_code').html 'Code: '+ @in_hex(selected_character_code)
    # The editor should show the newly selected character
    editor.render()

  import_from: ( encoded_text) ->
    data = Base64::decoded  encoded_text
    character_set.render()
    editor.render()
    macro.render()

  export: ->
    # If the user is editing a charset but switched to sprites mode and then
    # back then only 2K not 16K should be exported
    to_export = if mode.asset_type is 'charset' and 2048 < data.length then data.slice 0, 2048 else data
    "cat <<. | base64 -d > charset.bin\n"+ Base64::encoded( to_export )+ "\n.\n"

  in_hex: ( number ) ->
    hex = number.toString 16
    padding = if 1 < hex.length then '' else '0'
    '$'+ padding+ hex


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

  # Add the colors
  $('#colors tr').each ( row_index, tr ) ->
    # Record the row index of the tr: 0 for background, 1 for foreground, etc.
    # so that the click handler knows which color slot to change
    $(tr).data 'index', row_index
    # Go through all the colors and make a <td> for each
    $.each C64_COLORS, ( i, color ) =>
      td = elm 'td', style:'background-color:'+color.hex
      # Record the index within C64_COLORS so that the click handler knows
      # which color to assign
      $(td).data 'index', i
      $(tr).append  td
      $(td).click ( event ) =>
        td = event.currentTarget
        tr = this  # cheekily taken from jQuery setting "this" for each loop of $('#colors tr').each
        chosen_color[ $(tr).data 'index'] = C64_COLORS[ $(td).data 'index']
        character_set.render()
        editor.render()
        macro.render()
  # When a color label is clicked, the brush should be dipped in to that color
  $('#colors span').each ( i, span) ->
    $(span).click () ->
      editor.brush = i
      $('#colors span').each ( i, span ) ->
        $(span).removeClass 'on_brush'
      $(span).addClass 'on_brush'

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
    $('#download_dialog').fadeOut 'fast'

