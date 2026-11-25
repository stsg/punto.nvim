local alphabets = require("punto.layouts.alphabets")

return {
  id = "ru(phonetic_winkeys)",
  name = "Russian (phonetic, Winkeys)",
  alphabet = alphabets.cyrillic,
  rows = {
    { "ю1234567890-ь", "Ю!@ёЁъЪ&*()_Ь" },
    { "явертыуиопшщэ", "ЯВЕРТЫУИОПШЩЭ" },
    { "асдфгчйкл;'", 'АСДФГЧЙКЛ:"' },
    { "зхцжбнм,./", "ЗХЦЖБНМ<>?" },
  },
}
