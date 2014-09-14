
# Constructs a new DOM element, optionally using a function to construct and
# attach child elements.
#
#   elm 'p', {}, 'text'
#   elm 'tr', () ->
#     elm 'td', class: row, () ->
#       'content'
#
window.elm = ( tag, attributes, builder = null) ->
  #console.log "el #{tag}, #{attributes}, #{builder}"
  # If no attributes were given then the builder is in the "attributes"
  # parameter.  "builder" could either be: 1) a string, 2) a DOM element, or 3)
  # a function that when invoked returns either an element, a string or a list
  # where each item is either an element or a string
  if builder is null and ( typeof attributes in ( typeof e for e in [Function,""]) or attributes.nodeType? or $.isArray(attributes) )
    builder = attributes
    attributes = {}
  # Construct the element
  el = document.createElement  tag
  # Add any attributes
  for name, value of attributes
    el.setAttribute  name, value
  # Helper:
  add = ( el, child) ->
    child = document.createTextNode  child if typeof child is typeof ""
    el.appendChild  child
  # Construct and attach any children
  if builder?
    children = if typeof builder is typeof Function then builder() else builder
    if $.isArray( children )
      #for child in children
      $.each children, ( i, child ) ->
        add  el, child
    else
      add  el, children
  el


class Base64

  ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='

  # Given an Array of integers (0..255), produces a String that is the Base64
  # encoded version of the string.  The character set specified in RFC 3548 is
  # A..Z, a..z, 0..9, + and / with = for padding
  encoded: ( data ) ->
    # Encoding is 24 bits at a time.  If fewer than 24 bits are available then
    # the block is padded with zero bits to 24 bits.
    # Each 24-bit block encodes to 4 characters
    # The input to a 24-bit block is first byte first, MSB first, so that bit 7
    # of the first byte corresponds to bit 5 of the first character

    # The encoded data begins with an empty string that is appened to
    encoded_data = ''

    # Must be declared before the closure below
    cursor = 0

    f = ( offset, mask, shift ) ->
      # The " || 0" below is the zero-padding for undefined values at the end of "data"
      masked = ( data[cursor+ offset] || 0 ) & mask
      if (shift < 0) then (masked << -shift) else (masked >> shift)

    terminator_countdown = 76 / 4  # Wrap at 76.  4 characters output per loop

    while cursor < data.length
      remains = data.length - cursor
      encoded_data += ALPHABET[c] for c in [
        f( 0, 0xfc, 2 ),
        f( 0, 0x03, -4 ) | f( 1, 0xf0, 4 ),
        if (1 < remains) then ( f(1, 0x0f, -2) | f(2, 0xc0, 6) ) else 64,
        if (2 < remains) then f(2, 0x3f, 0) else 64,
      ]
      # Insert a line terminator every 76 characters
      terminator_countdown -= 1
      if terminator_countdown is 0
        encoded_data += "\n"
        terminator_countdown = 76 / 4
      cursor += 3

    encoded_data


  decoded: ( text ) ->
    # Strip any line terminators
    text = text.replace /[\r\n]/g, ''

    data = []

    cursor = 0

    f = ( offset, mask, shift ) ->
      masked = ALPHABET.indexOf( text[ cursor+ offset]) & mask
      if (shift < 0) then (masked << -shift) else (masked >> shift)

    while cursor < text.length
      bytes = if '=' == text[cursor+2] then 1 else
                if '=' == text[cursor+3] then 2 else 3
      data.push  f(0,0x3f,-2) | f(1,0x30,4)
      if 1 < bytes
        data.push  f(1,0x0f,-4) | f(2,0x3c,2)
      if 2 < bytes
        data.push  f(2,0x03,-6) | f(3,0x3f,0)
      cursor += 4

    data


window.Base64 = Base64

