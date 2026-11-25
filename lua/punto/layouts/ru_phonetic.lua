local alphabets = require("punto.layouts.alphabets")

return {
  id = "ru(phonetic)",
  name = "Russian (phonetic)",
  alphabet = alphabets.cyrillic,
  rows = {
    { "ю1234567890-ч", "Ю!@ёЁъЪ&*()_Ч" },
    { "явертыуиопшщэ", "ЯВЕРТЫУИОПШЩЭ" },
    { "асдфгхйкл;'", 'АСДФГХЙКЛ:"' },
    { "зьцжбнм,./", "ЗЬЦЖБНМ<>?" },
  },
}
