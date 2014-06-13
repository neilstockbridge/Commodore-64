
# Commodore 64 character set editor

This is a very simple C64 character set editor.

  + Runs completely within the browser.  Any web server capable of serving static files can host the editor

  + Binary images of character sets may be uploaded once represented in Base64.  This is the only method of saving your work

  + The character set as edited within the browser may be downloaded as Base64 for local storage.  It's easy to convert the Base64 to a `.bin` file for incorporation in to your projects.  In fact, it is expected that the `.bin` is the authoritative source and Base64 is only used as a clipboard-safe transport

  + Uses the &lt;canvas&gt; element, so won't work with Internet Explorer.  Works with Firefox and Chrome though

