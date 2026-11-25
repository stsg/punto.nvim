local alphabets = require("punto.layouts.alphabets")

-- Canonical physical grid: 47 printable keys in four rows.
-- Key ids are the unshifted US characters.
return {
  id = "en(qwerty)",
  name = "English (US QWERTY)",
  alphabet = alphabets.latin,
  rows = {
    { "`1234567890-=", "~!@#$%^&*()_+" },
    { "qwertyuiop[]\\", "QWERTYUIOP{}|" },
    { "asdfghjkl;'", 'ASDFGHJKL:"' },
    { "zxcvbnm,./", "ZXCVBNM<>?" },
  },
}
