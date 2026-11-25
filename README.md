# punto.nvim

Плагин для Neovim: исправляет текст, набранный не в той раскладке.

`ghbdtn` → `привет` · `руддщ` → `hello` · `priwet` → `привет`

Конвертация идёт по физическим позициям клавиш между `en(qwerty)` и
настраиваемой раскладкой (по умолчанию `ru(phonetic_winkeys)`).

## Требования

- Neovim ≥ 0.11
- внешних зависимостей нет

## Установка

lazy.nvim:

```lua
{
  "sts/punto.nvim",
  opts = {
    layout = "ru(phonetic_winkeys)",
  },
}
```

После `setup()` создаются маппинги `<Leader>sw` для normal и visual и
команда `:PuntoSwitch`.

Ленивая загрузка по клавише:

```lua
{
  "sts/punto.nvim",
  keys = {
    { "<Leader>sw", mode = { "n", "x" }, desc = "Punto: switch layout" },
  },
  opts = { layout = "ru(phonetic_winkeys)", keymap = false },
}
```

Не задавайте одновременно `keys` в спецификации плагина и `keymap` в
`opts` — получится два маппинга.

Вручную:

```lua
vim.opt.runtimepath:append("/path/to/punto.nvim")
require("punto").setup()
vim.cmd("helptags doc")
```

## Использование

- **normal** — последнее слово: под курсором или ближайшее слева. Пунктуация
  и цифры вне слова не трогаются.
- **visual** — ровно выделенный текст (charwise, linewise, blockwise).
- Повторное нажатие возвращает исходный текст.
- `:PuntoSwitch` — то же самое из командной строки.
- `:PuntoSwitch to_ru` / `:PuntoSwitch to_en` — принудительное направление.
- `:'<,'>PuntoSwitch` — конвертировать диапазон.
- `:checkhealth punto` — диагностика.

Направление `auto` выбирается по письменности: латиница → в настроенную
раскладку, кириллица → в латиницу. Смешанный текст автоматически не
конвертируется — укажите направление явно.

Имена направлений исторические: `to_ru` означает «в настроенную `layout`»,
`to_en` — «в `latin_layout`».

## Настройка

```lua
require("punto").setup({
  layout = "ru(phonetic_winkeys)", -- рабочая раскладка
  latin_layout = "en(qwerty)",
  direction = "auto",              -- "auto" | "to_ru" | "to_en"
  keymap = "<Leader>sw",           -- string | false | { normal=..., visual=... }
  normal_scope = "word",           -- "word" | "token"
  notify = true,
  ignore_buftypes = { "terminal", "prompt" },
  ignore_filetypes = {},
})
```

| Опция | По умолчанию | Описание |
| --- | --- | --- |
| `layout` | `"ru(phonetic_winkeys)"` | раскладка, в которую/из которой конвертируем |
| `latin_layout` | `"en(qwerty)"` | вторая сторона пары |
| `direction` | `"auto"` | `auto`, `to_ru`, `to_en` |
| `keymap` | `"<Leader>sw"` | маппинг(и) или `false` |
| `normal_scope` | `"word"` | `word` — только буквы, `token` — не-пробельный токен |
| `notify` | `true` | уведомления о no-op и ошибках |
| `ignore_buftypes` | `{ "terminal", "prompt" }` | буферы, которые не трогаем |
| `ignore_filetypes` | `{}` | filetypes, которые не трогаем |

`normal_scope = "token"` включает пунктуацию, примыкающую к слову:
`ghbdtn?` → `привет,`. Это opt-in, потому что token-режим может захватить
кавычки и скобки.

## Встроенные раскладки

- `en(qwerty)`
- `ru(winkeys)`
- `ru(phonetic)`
- `ru(phonetic_winkeys)` — по умолчанию

Алиасы: `en`, `us` → `en(qwerty)`; `ru` → `ru(winkeys)`.

### Важно про `ru(phonetic_winkeys)`

Это вариант «ЯВЕРТ» из xkb: буква `в` находится на `W`, а `ж` — на `V`.
Поэтому `priwet` → `привет`, а `privet` → `прижет`. Это не ошибка таблицы:
так раскладка определена в xkb. Если вы используете другую «фонетическую»
раскладку (MS Russian Mnemonic, «ЯЖЕРТ» и т. п.), добавьте её через
`register_layout()`.

Источник таблиц — [xkeyboard-config/symbols/ru](https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config/-/blob/master/symbols/ru).

Пунктуация конвертируется по клавишам, а не по символам: например, в
`ru(winkeys)` en `?` (Shift+`/`) → ru `,`, а ru `?` (Shift+7) → en `&`.

### Своя раскладка

```lua
require("punto").register_layout({
  id = "ru(custom)",
  name = "My Russian layout",
  alphabet = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
          .. "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ",
  rows = {
    -- четыре ряда; длины 13, 13, 11, 10; { plain, shift }
    { "ю1234567890-ь", "Ю!@ёЁъЪ&*()_Ь" }, -- ` 1 2 3 4 5 6 7 8 9 0 - =
    { "явертыуиопшщэ", "ЯВЕРТЫУИОПШЩЭ" }, -- q w e r t y u i o p [ ] \
    { "асдфгчйкл;'", 'АСДФГЧЙКЛ:"' },    -- a s d f g h j k l ; '
    { "зхцжбнм,./", "ЗХЦЖБНМ<>?" },      -- z x c v b n m , . /
  },
})
```

Зарегистрируйте раскладку до `setup()` (или вызовите `setup()` повторно).

## API

```lua
local punto = require("punto")

punto.setup(opts)
punto.switch({ direction = "to_ru" })     -- true, если буфер изменился
punto.convert("ghbdtn", { direction = "to_ru" }) -- "привет", true
punto.register_layout(spec)
punto.layouts.get("ru(winkeys)")
punto.layouts.list()
```

## Ограничения

- normal конвертирует только буквы; пунктуация — через visual или
  `normal_scope = "token"`;
- visual конвертирует и пунктуацию (позиционная семантика);
- смешанный текст (`привет world`) в `auto` не конвертируется;
- NFD/комбинированные символы не нормализуются;
- blockwise с табами и `virtualedit` — best effort: конвертируются целые
  символы, а не отдельные экранные ячейки;
- `count` и `.`-repeat пока не поддерживаются.

## Разработка

```bash
make test
```

Тесты запускаются в headless Neovim без внешних зависимостей.

## English summary

punto.nvim fixes text typed in the wrong keyboard layout by converting
characters at the same physical key positions. Press `<Leader>sw` in Normal
mode to fix the last word, or in Visual mode to fix the selection. The
layout is configurable and defaults to `ru(phonetic_winkeys)`; direction is
detected from the script or can be set explicitly with `:PuntoSwitch to_ru`
or `:PuntoSwitch to_en`. Requires Neovim 0.11+, no dependencies.

## Лицензия

MIT.
