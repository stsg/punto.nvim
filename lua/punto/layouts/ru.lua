local alphabets = require("punto.layouts.alphabets")

return {
  id = "ru(winkeys)",
  name = "Russian (Winkeys)",
  alphabet = alphabets.cyrillic,
  rows = {
    { "ё1234567890-=", 'Ё!"№;%:?*()_+' },
    { "йцукенгшщзхъ\\", "ЙЦУКЕНГШЩЗХЪ/" },
    { "фывапролджэ", "ФЫВАПРОЛДЖЭ" },
    { "ячсмитьбю.", "ЯЧСМИТЬБЮ," },
  },
}
