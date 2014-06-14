
# PLAN:
# + Version 2:
#   + assemble multiple characters up to 4x4 in grid by painting with selected char for larger assemblies
# + Version 3:
#   + MuCo.  Use the same charset and simply switch between hi-res and MuCo mode.  allow selection of other colors
# + Version 4:
#   + re-work for sprites ( also edits a single 16K region and interprets as either hi-res or MuCo depending upon a switch).  This is so, because that's the C-64 sees it
# + indicate visually on the charset grid which character is selected


# + The character set should be shown in 8 rows, 32 glyphs wide
# + Character codes may be selected and the glyph is shown in the editor
# + The editor should be shown with 8x8 pixels for editing a single glyph
# + Clicking on a pixel within the editor should invert that pixel.  Holding
#   down will paint not by inverting but the inverted value of the click


C64_COLORS = [
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
]

scale = 3 # number of on-screen pixels to each C64 pixel

character_set = null
editor = null
macro = null

background_color = C64_COLORS[6]
foreground_color = C64_COLORS[14]


class Character

  constructor: ->
    @data = ( [0,0,0,0,0,0,0,0] for row in [0..7] )
    @canvas = elm 'canvas', width:8*scale, height:8*scale
    @context = @canvas.getContext '2d'
    @image_data = @context.createImageData  @canvas.width, @canvas.height

  pixel_at: ( row, column ) ->
    @data[ row][ column]

  set_pixel: ( row, column, color ) ->
    @data[ row][ column] = color

  render: =>
    for y in [0..@image_data.height - 1]
      # Work out the y ordinate within the character data that sources the
      # color for this ( on-screen) pixel
      sy = parseInt  y * 8 / @image_data.height
      for x in [0..@image_data.width - 1]
        sx = parseInt  x * 8 / @image_data.width
        color = if @data[sy][sx] is 0 then background_color else foreground_color
        r = parseInt  color.substr( 1, 2 ), 16
        g = parseInt  color.substr( 3, 2 ), 16
        b = parseInt  color.substr( 5, 2 ), 16
        # Work out the base index within image_data.data of the 4 bytes that
        # control RGBA for the pixel
        pb = 4 * ( @image_data.width * y + x )
        @image_data.data[pb+0] = r
        @image_data.data[pb+1] = g
        @image_data.data[pb+2] = b
        @image_data.data[pb+3] = 255 # A
    @context.putImageData  @image_data, 0, 0


class CharacterSet

  constructor: ->
    @characters = [] # Array[0..255] of Character objects by character code
    @selected_character_code = 0
    # build charset grid
    table = $('#charset')
    for row in [0..7]
      tr = $( elm 'tr', {})
      for column in [0..31]
        character_code = 32 * row + column
        character = new Character()
        @characters[ character_code] = character
        td = elm 'td', id:"c#{character_code}", title:@in_hex(character_code), character.canvas
        tr.append  td
      table.append  tr
    table.find('td').click @when_character_clicked
    @render()

  selected_character: ->
    @characters[ @selected_character_code ]

  render: ->
    character.render() for character in @characters

  when_character_clicked: ( event) =>
    @selected_character_code = event.currentTarget.id.substr 1 # the IDs are like "c45" for character code 45 ( decimal)
    $('#selected_character_code').html 'Code: '+ @in_hex(parseInt @selected_character_code)
    # The editor should show the newly selected character
    editor.render()

  import_from: ( encoded_text) ->
    data = Base64::decoded  encoded_text.replace(/[\r\n]/g, '')
    $.each @characters, ( code, character ) ->
      for row in [0..7]
        for column in [0..7]
          mask = 1 << (7 - column)
          character.data[ row][ column] = if 0 < (data[ 8*code + row ] & mask) then 1 else 0
      character.render()
    editor.render()

  export: ->
    data = []
    for character in @characters
      for row in character.data
        byte = 0
        for bit in [0..7]
          byte |= (1 << bit) if 1 == row[ 7 - bit ]
        data.push  byte
    "cat <<. | base64 -d > charset.bin\n"+ Base64::encoded( data )+ "\n.\n"

  in_hex: ( number ) ->
    hex = number.toString 16
    padding = if 1 < hex.length then '' else '0'
    '$'+ padding+ hex


class Editor

  constructor: ->
    @brush = 1 # @brush remembers whether to paint with foreground or background pixels
    table = $('#editor')
    for row in [0..7]
      tr = elm 'tr', {}
      for column in [0..7]
        cell = elm 'td', id: "e#{row}#{column}"
        $(tr).append  cell
      table.append  tr
    table.find('td').mousedown(@when_button_pressed).mouseup @when_button_released
    @render()

  coordinates_from: ( event) ->
    [ event.currentTarget.id[1], event.currentTarget.id[2] ]

  when_button_pressed: ( event) =>
    # The location within the grid of the cell clicked is encoded in the id of
    # the element as "e03" for row 0, column 3
    [ row, column] = @coordinates_from  event
    # The brush should be the opposite of the pixel currently underneath the cursor
    @brush = 1 - character_set.selected_character().pixel_at( row, column)
    # If the pixel is cleared ( transparent, background color) then go in to
    # "set" mode for setting pixels until the mouse button is released
    $('#editor').find('td').on 'mousemove', @when_dragged
    @paint  row, column

  when_dragged: ( event) =>
    [ row, column] = @coordinates_from  event
    @paint  row, column

  when_button_released: ( event) =>
    $('#editor').find('td').off 'mousemove'
    false  # FIXME: try to get around text selection cursor appearing.  maybe it's because the cursor is being dragged over the border, which is not part of the <td>

  paint: ( row, column) =>
    selected_character = character_set.selected_character()
    selected_character.set_pixel  row, column, @brush
    @render()
    selected_character.render()
    macro.render()

  render: () ->
    $('#editor').find('tr').each ( row, tr ) ->
      $(tr).children().each ( column, td ) ->
        $(td).css 'background-color', if character_set.selected_character().pixel_at( row, column) is 0 then background_color else foreground_color


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
        cell = elm 'td', canvas
        $(tr).append  cell
      table.append  tr
    table.find('canvas').click @when_button_pressed
    @render()

  when_button_pressed: =>
    canvas = event.currentTarget
    $(canvas).data 'code', character_set.selected_character_code
    @render_canvas  canvas

  render: ->
    @render_canvas canvas for canvas in @canvases

  render_canvas: ( canvas ) ->
    code = $(canvas).data 'code'
    character = character_set.characters[ code]
    canvas.getContext('2d').putImageData  character.image_data, 0, 0


$(document).ready () ->
  character_set = new CharacterSet()
  editor = new Editor()
  macro = new Macro()

  # Add the colors
  $('#colors tr').each ( i, tr ) ->
    # Record the row index of the tr: 0 for background, 1 for foreground, etc.
    # so that the click handler knows which color slot to change
    $(tr).data 'index', i
    # Go through all the colors and make a <td> for each
    for color in C64_COLORS
      td = elm 'td', style:'background-color:'+color
      # Record the index within C64_COLORS so that the click handler knows
      # which color to assign
      $(td).data 'index', C64_COLORS.indexOf(color)
      $(tr).append  td
      $(td).click ( event ) =>
        td = event.currentTarget
        tr = this
        color = C64_COLORS[ $(td).data 'index' ]
        switch $(tr).data 'index'
          when 0 then background_color = color
          when 1 then foreground_color = color
        character_set.render()
        editor.render()

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

