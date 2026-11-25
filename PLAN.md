<!-- markdownlint-disable MD013 MD036 MD060 -->

# punto.nvim — план реализации

> **TL;DR.** Небольшой плагин на Lua для Neovim ≥ 0.11 без внешних зависимостей.
> По хоткею конвертирует последнее слово (normal) или выделение (visual) между
> `en(qwerty)` и настраиваемой раскладкой (по умолчанию `ru(phonetic_winkeys)`)
> по физическим позициям клавиш. Направление определяется по алфавиту текста
> или задаётся явно. Одна операция — один шаг `undo`.

|               |                            |
| ------------- | -------------------------- |
| Версия плана  | 1.1 (решения подтверждены) |
| Дата          | 2026-11-25                 |
| Целевой релиз | v0.1.0                     |
| Neovim        | ≥ 0.11                     |
| Зависимости   | нет (только stdlib Neovim) |
| Статус        | v0.1.0 реализован, 43 теста |

---

## 1. Задача и сценарии

Пользователь набрал текст, не переключив раскладку, и получил бессмыслицу:
`ghbdtn` вместо `привет` (стандартная раскладка) или `priwet` вместо `привет`
(фонетическая). Плагин по хоткею переводит символы по позициям клавиш:
каждая буква заменяется на ту, которая находится на той же физической клавише
в другой раскладке.

Сценарии:

1. **Normal / последнее слово.** Курсор на слове или сразу после него →
   хоткей → слово исправлено, курсор остаётся в конце слова.
2. **Visual / выделение.** Выделен фрагмент (слово, часть строки, несколько
   строк) → хоткей → исправлен ровно выделенный текст.
3. **Обратное направление.** Текст на кириллице, набранный при английской
   раскладке (`руддщ`), превращается в `hello`.
4. **Явное направление.** `:PuntoSwitch to_en` / `:PuntoSwitch to_ru` —
   когда автоматика ошибается (смешанный текст, пунктуация).
5. **Повторное нажатие** возвращает исходный текст для всех символов, которые
   есть в таблице раскладки (отображение биективно).

Раскладка задаётся в настройках, по умолчанию — `ru(phonetic_winkeys)`.

---

## 2. Границы задачи

**Входит в v0.1.0:**

- normal: последнее слово (под курсором или ближайшее слева);
- visual: charwise, linewise, blockwise (blockwise — best effort, см. риски);
- направление `auto` + явные `to_ru` / `to_en`;
- built-in раскладки: `en(qwerty)`, `ru(winkeys)`, `ru(phonetic)`,
  `ru(phonetic_winkeys)`;
- пользовательские раскладки через `register_layout()`;
- команда `:PuntoSwitch [auto|to_ru|to_en]`, маппинги normal/visual;
- одношаговый `undo`, сохранение количества строк;
- `:checkhealth punto`, справка `:help punto`, README;
- тесты и CI.

**Не входит:**

- автоматическое переключение раскладки ОС и слежение за вводом;
- транслитерация по звучанию (это конвертация по позициям, а не перевод
  `shch` → `щ`);
- insert/terminal/command-line режимы;
- исправление уже набранного текста «на лету» через autocmd;
- поддержка всех языков мира «из коробки» (есть реестр раскладок);
- интеграция со spellchecker, LSP, деревом синтаксиса;
- `count` и `.`-repeat в MVP (отложены до v0.2, см. § 14).

---

## 3. Пользовательский опыт

### 3.1 Хоткей

По умолчанию — `<Leader>sw` в normal и visual. Значение настраивается:

```lua
keymap = "<Leader>sw"                       -- один и тот же для n и x
keymap = { normal = "<Leader>sw", visual = "<Leader>sw" }
keymap = false                              -- только :PuntoSwitch
```

Маппинги создаются в `setup()`:

```lua
vim.keymap.set("n", lhs_normal, "<Cmd>PuntoSwitch<CR>",
  { desc = "Punto: switch layout" })
vim.keymap.set("x", lhs_visual, ":<C-u>'<,'>PuntoSwitch<CR>",
  { desc = "Punto: switch layout" })
```

Почему для visual нужен `:<C-u>`: нажатие `:` завершает visual-режим и
выставляет marks `'<`/`'>`; `<C-u>` убирает автоматически подставленный
диапазон `'<,'>`, после чего он подставляется явно. Это надёжнее, чем `<Cmd>`,
который не выходит из visual-режима и может оставить marks от предыдущего
выделения.

Важно для lazy.nvim: не задавайте одновременно `keys` в спецификации плагина
и `keymap` в `opts` — получится два маппинга. Варианты:

```lua
-- A: плагин создаёт маппинг сам (eager)
{ "sts/punto.nvim",
  opts = { layout = "ru(phonetic_winkeys)", keymap = "<Leader>sw" } }

-- B: ленивая загрузка по клавише, маппинг создаёт lazy.nvim
{ "sts/punto.nvim",
  keys = { { "<Leader>sw", mode = { "n", "x" }, desc = "Punto: switch layout" } },
  opts = { layout = "ru(phonetic_winkeys)", keymap = false } }
```

### 3.2 Normal: последнее слово

Слово — непрерывная последовательность **букв** (из алфавитов обеих
раскладок) в текущей строке. Цифры, `_`, дефисы и пунктуация в слово не входят.

Правила выбора:

1. Курсор на букве → берётся слово под курсором.
2. Курсор на пробеле/пунктуации → ищется ближайшая буква слева, от неё
   слово раскрывается влево и вправо. Так `ghbdtn |` (курсор на пробеле)
   и `ghbdtn,|` (курсор на запятой) исправляют `ghbdtn`.
3. Слова слева нет → no-op с уведомлением.
4. Слово, начинающееся правее курсора, не трогается: «последнее слово»
   означает уже набранное.

Примеры:

| Строка         | Позиция курсора          | Что конвертируется       |
| -------------- | ------------------------ | ------------------------ |
| `ghbdtn`       | на `n`                   | `ghbdtn`                 |
| `ghbdtn`       | на пробеле               | `ghbdtn`                 |
| `ghbdtn, test` | на запятой               | `ghbdtn`                 |
| `test ghbdtn`  | на пробеле между словами | `test` (ближайшее слева) |
| `123`          | где угодно               | ничего                   |

Пунктуация и цифры вне слова остаются как есть: это осознанное ограничение
режима normal. Если нужен токен целиком (`ghbdtn?` → `привет,`), включается
`normal_scope = "token"` — тогда границей считается пробел, а не буква
(см. § 4). Это opt-in, потому что token-режим может захватить кавычки,
скобки и бэктики, если они примыкают к слову.

### 3.3 Visual: выделение

- Конвертируется ровно выделенный текст, включая пунктуацию, цифры и пробелы
  внутри выделения (по позициям клавиш).
- Поддерживаются charwise и linewise. Blockwise обрабатывается тем же кодом,
  но с оговорками про `virtualedit`/табы (см. § 13).
- Количество строк не меняется: перевод строки не имеет отображения и остаётся
  как есть.
- Одна операция записи в буфер → один шаг `undo`.
- Курсор после операции — на последнем символе последнего изменённого
  фрагмента.
- `:'<,'>PuntoSwitch` работает и без маппинга, если набрать команду вручную.

### 3.4 Уведомления

Успех — молча (как в Punto Switcher). No-op и ошибки — через `vim.notify`
с `title = "punto"`, если `notify = true`:

| Ситуация               | Уровень | Текст (английский, см. § 14)                        |
| ---------------------- | ------- | --------------------------------------------------- |
| нечего конвертировать  | WARN    | `punto: nothing to convert`                         |
| смешанный текст в auto | WARN    | `punto: mixed script; use :PuntoSwitch to_ru/to_en` |
| буфер не modifiable    | WARN    | `punto: buffer is not modifiable`                   |
| неизвестная раскладка  | ERROR   | `punto: unknown layout 'x(y)'`                      |
| ошибка выполнения      | ERROR   | `punto: <error>`                                    |

Неизвестная раскладка в `setup()` — это ошибка конфигурации: `error()` сразу,
чтобы пользователь увидел её при старте, а не при первом нажатии.

### 3.5 Команды и публичный API

| Интерфейс            | Назначение                                       |
| -------------------- | ------------------------------------------------ |
| `:PuntoSwitch`       | последнее слово (normal) или визуальный диапазон |
| `:PuntoSwitch to_ru` | принудительно в настроенную раскладку            |
| `:PuntoSwitch to_en` | принудительно в латиницу                         |
| `:'<,'>PuntoSwitch`  | конвертировать диапазон                          |
| `:checkhealth punto` | диагностика                                      |

```lua
local punto = require("punto")

punto.setup(opts)                    -- конфигурация, маппинги, команда
punto.switch(opts)                   -- выполнить конвертацию (см. ниже)
punto.convert(text, opts)            -- "текст -> текст", возвращает text, changed
punto.register_layout(spec)          -- добавить раскладку
punto.layouts.get(id)                -- получить собранную раскладку
punto.layouts.list()                 -- список id
```

`switch` принимает `{ direction?, mode?, range? }`; `mode` — `"normal"`,
`"visual"`, `"lines"` (последние два — для внутренних вызовов и тестов).
Возвращает `true`, если буфер изменился.

Команда регистрируется в `setup()`; без вызова `setup()` доступен только
Lua API. В lazy.nvim для `cmd = { "PuntoSwitch" }` обязательно передайте
`opts` — тогда lazy.nvim вызовет `setup()` перед выполнением команды.

---

## 4. Конфигурация

```lua
---@class PuntoConfig
local defaults = {
  --- Рабочая раскладка: в неё конвертируется латиница и из неё — кириллица.
  layout = "ru(phonetic_winkeys)",

  --- Вторая сторона пары.
  latin_layout = "en(qwerty)",

  --- "auto" | "to_ru" | "to_en"
  direction = "auto",

  --- string | false | { normal?: string|false, visual?: string|false }
  keymap = "<Leader>sw",

  --- "word" — только буквы; "token" — весь не-пробельный токен.
  normal_scope = "word",

  --- Показывать уведомления о no-op и ошибках.
  notify = true,

  --- Буферы, которые не трогаем.
  ignore_buftypes = { "terminal", "prompt" },
  ignore_filetypes = {},
}
```

| Опция              | Тип                | По умолчанию               | Комментарий                   |
| ------------------ | ------------------ | -------------------------- | ----------------------------- |
| `layout`           | string             | `"ru(phonetic_winkeys)"`   | id из реестра или алиас       |
| `latin_layout`     | string             | `"en(qwerty)"`             | вторая сторона                |
| `direction`        | enum               | `"auto"`                   | см. § 7.1                     |
| `keymap`           | string/table/false | `"<Leader>sw"`             | создаётся в `setup()`         |
| `normal_scope`     | enum               | `"word"`                   | `"word"` или `"token"`        |
| `notify`           | boolean            | `true`                     | влияет только на no-op/ошибки |
| `ignore_buftypes`  | string[]           | `{ "terminal", "prompt" }` | замена, не слияние            |
| `ignore_filetypes` | string[]           | `{}`                       | например, `"TelescopePrompt"` |

Правила нормализации и проверки:

- `layout` и `latin_layout` обязаны резолвиться в реестре и различаться;
  иначе `error("punto: ...")` с перечнем доступных id;
- списки `ignore_*` заменяют значения по умолчанию целиком (не
  `tbl_deep_extend`, чтобы не получить сюрпризов при слиянии массивов);
- неизвестные ключи в `opts` → WARN (опечатка не должна молча игнорироваться);
- повторный `setup()` идемпотентен: старые маппинги удаляются (запоминаем
  созданные `lhs`), команда пересоздаётся;
- `switch()` без предварительного `setup()` использует значения по умолчанию
  (ленивая инициализация конфига, без создания маппингов).

```lua
-- пример ручной настройки
require("punto").setup({
  layout = "ru(winkeys)",
  direction = "auto",
  keymap = { normal = "<Leader>sw", visual = "<Leader>sw" },
})
```

---

## 5. Архитектура

```
punto.nvim/
├── lua/punto/
│   ├── init.lua                 -- setup, switch, команда, маппинги
│   ├── config.lua               -- defaults, merge, validate, ensure
│   ├── util.lua                 -- UTF-8 chars, char_spans, byte/char helpers, notify
│   ├── convert.lua              -- convert(), detect_direction()
│   ├── word.lua                 -- сегмент последнего слова
│   ├── selection.lua            -- сегменты visual и запись в буфер
│   ├── health.lua               -- :checkhealth punto
│   └── layouts/
│       ├── init.lua             -- реестр, парсинг id, build, cache, register
│       ├── alphabets.lua        -- общие строки алфавитов
│       ├── qwerty.lua           -- id "en(qwerty)"
│       ├── ru.lua               -- id "ru(winkeys)"
│       ├── ru_phonetic.lua      -- id "ru(phonetic)"
│       └── ru_phonetic_winkeys.lua
├── tests/
│   ├── minimal_init.lua
│   ├── run.lua                  -- мини-раннер без зависимостей
│   ├── helpers.lua
│   └── spec/
│       ├── layouts_spec.lua
│       ├── convert_spec.lua
│       ├── word_spec.lua
│       ├── selection_spec.lua
│       └── command_spec.lua
├── doc/punto.txt                -- :help punto
├── .github/workflows/ci.yml
├── Makefile
├── stylua.toml
├── .gitignore
├── LICENSE                      -- MIT
├── README.md                    -- русский, с кратким English summary
├── CHANGELOG.md
└── PLAN.md
```

| Модуль             | Ответственность                                    | Зависимости         |
| ------------------ | -------------------------------------------------- | ------------------- |
| `init.lua`         | публичный API, порядок действий, команда, маппинги | все                 |
| `config.lua`       | дефолты, валидация, ленивая инициализация          | `layouts`           |
| `layouts/init.lua` | реестр, парсинг `ru(...)`, сборка карт, кеш        | spec-файлы          |
| `convert.lua`      | посимвольная конвертация, детект направления       | `util`              |
| `word.lua`         | чистая логика диапазона слова в строке             | `util`, `layouts`   |
| `selection.lua`    | `getregionpos`, сегменты, запись, курсор           | `util`              |
| `util.lua`         | UTF-8, байтовые границы, notify                    | —                   |
| `health.lua`       | диагностика                                        | `config`, `layouts` |

Поток вызова:

```
keymap / :PuntoSwitch
      │
      ▼
 punto.switch(opts)
      │ 1. выбрать режим и получить сегменты (word | visual | lines)
      │ 2. определить направление (auto) по тексту сегментов
      │ 3. convert() каждый сегмент
      │ 4. если ничего не изменилось — notify и выход
      │ 5. selection.apply() — ОДНА запись в буфер
      │ 6. поставить курсор, вернуть changed
      ▼
   буфер
```

Границы: `layouts` и `convert` не знают про буфер и не вызывают `vim.api.*`
(кроме `util.chars`, который может быть на чистом Lua); `word` работает со
строкой и не пишет в буфер; `selection` — единственный модуль, который
изменяет буфер.

---

## 6. Модель раскладок

### 6.1 Формат

Раскладка — таблица из четырёх физических рядов. Ряды соответствуют US
QWERTY; порядок клавиш фиксирован (включая `\` в конце второго ряда):

```lua
---@class PuntoLayoutSpec
---@field id string                 -- "ru(phonetic_winkeys)"
---@field name string               -- человекочитаемое имя
---@field alphabet string           -- буквы, строчные и прописные
---@field rows { [1]: string, [2]: string }[]  -- 4 ряда: {plain, shift}

return {
  id = "ru(phonetic_winkeys)",
  name = "Russian (phonetic, Winkeys)",
  alphabet = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
          .. "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ",
  rows = {
    { "ю1234567890-ь", "Ю!@ёЁъЪ&*()_Ь" }, -- ` + 1..0 - =
    { "явертыуиопшщэ", "ЯВЕРТЫУИОПШЩЭ" }, -- q..] + backslash
    { "асдфгчйкл;'",  'АСДФГЧЙКЛ:"'    }, -- a..'
    { "зхцжбнм,./",    "ЗХЦЖБНМ<>?"    }, -- z../
  },
}
```

Канонический **key id** — символ US-раскладки на этой клавише без Shift:
`` ` ``, `1`…`0`, `-`, `=`, `q`…`p`, `[`, `]`, `\`, `a`…`l`, `;`, `'`,
`z`…`m`, `,`, `.`, `/`. Всего 47 клавиш, 94 символа (plain + shift).

Собранная раскладка:

```lua
---@class PuntoLayout
---@field id string
---@field keys table<string, { plain: string, shift: string }>
---@field reverse table<string, { key: string, shift: boolean }>
---@field alphabet_set table<string, true>

local layout = {
  id = spec.id,
  keys = {
    ["q"] = { plain = "я", shift = "Я" },
    ["\\"] = { plain = "э", shift = "Э" },
    -- ...
  },
  reverse = {
    ["я"] = { key = "q", shift = false },
    ["Я"] = { key = "q", shift = true },
    -- ...
  },
  alphabet_set = { ["а"] = true, ... },
}
```

Сборка: для каждого ряда берём эталон `QWERTY_ROWS[r]`, режем на символы
(UTF-8) и проверяем, что длины `plain`, `shift` и эталона совпадают. Затем
заполняем `keys` и `reverse`.

### 6.2 Валидация

Для встроенных раскладок (тест и `build`, ошибка при нарушении):

- 4 ряда; длины 13, 13, 11, 10;
- 94 уникальных символа (в `ru(winkeys)` `?` встречается только на Shift+7,
  `,` — только на Shift+`.` и т. д.);
- каждый символ `alphabet` присутствует в `keys` (на любом уровне);
- `id` соответствует `lang(variant)`, `name` непустой.

Для `register_layout()`: те же проверки, но ошибка с указанием раскладки и
конфликтующего символа. Дубликаты символов запрещены (обратное отображение
неоднозначно); если понадобятся — отдельный режим `allow_duplicates` в
будущем.

### 6.3 Реестр и имена

- `layouts.get("ru(phonetic_winkeys)")` — парсинг `^(%w+)%(([%w_%-]+)%)$`,
  поиск в реестре, сборка при первом обращении, кеш.
- Алиасы: `"ru"` → `"ru(winkeys)"`, `"en"`/`"us"` → `"en(qwerty)"`.
- Неизвестный id → `nil` + список доступных в тексте ошибки.
- `register_layout(spec)` собирает и валидирует сразу, кладёт в реестр,
  сбрасывает кеш; вызывать до `setup()` (или повторно вызвать `setup()`).
- `layouts.list()` возвращает отсортированные id.

### 6.4 Источник данных и важное предупреждение

Таблицы сняты с xkb-раскладок `xkb-data` (`/usr/share/X11/xkb/symbols/ru`)
и сверены с `xkbcli compile-keymap`:

```bash
xkbcli compile-keymap --layout 'ru,us' --variant 'phonetic_winkeys,'
```

Актуальный upstream: <https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config/-/blob/master/symbols/ru>.

**`ru(phonetic_winkeys)` — это вариант «ЯВЕРТ», а не «ЯЖЕРТ»/MS Phonetic.**
В нём `в` сидит на `W`, а `ж` — на `V`:

- `priwet` → `привет`;
- `privet` → `прижет` (не «привет»!).

Это не ошибка таблицы: именно так раскладка определена в xkb. Если
пользователь работает в другой «фонетической» раскладке (MS Russian
Mnemonic, «ЯЖЕРТ» и т. п.), он добавляет свою таблицу через
`register_layout()` — механизм для этого есть с v0.1.0.

Другие заметные следствия позиционного отображения:

- `ru(winkeys)`: en `?` (Shift+`/`) → ru `,`; обратно ru `,` → en `?`.
  При этом ru `?` живёт на Shift+7 и при `to_en` даёт en `&` — пунктуация
  отображается по клавишам, а не по символам. `#` → `№` (Shift+3);
- `ru(phonetic_winkeys)`: `#` ↔ `ё` (Shift+3), потому что `ё` в этой
  раскладке живёт на Shift+3.

---

## 7. Алгоритм конвертации

### 7.1 Направление

- `to_ru` — из `latin_layout` в `layout`;
- `to_en` — из `layout` в `latin_layout`;
- `auto` — по алфавитам:
  - есть только латинские буквы → `to_ru`;
  - есть только кириллические → `to_en`;
  - букв нет или присутствуют обе письменности → `nil` (no-op + подсказка
    выбрать направление явно).

Строгая проверка «только одна письменность» выбрана намеренно: иначе
смешанный фрагмент (`привет world`) молча конвертировался бы наполовину.
Явный `to_ru`/`to_en` конвертирует всё, что есть в таблице, а незнакомые
символы оставляет как есть.

```lua
function M.detect_direction(text, ru, en)
  local ru_n, en_n = 0, 0
  for _, ch in ipairs(chars(text)) do
    if ru.alphabet_set[ch] then ru_n = ru_n + 1
    elseif en.alphabet_set[ch] then en_n = en_n + 1 end
  end
  if ru_n > 0 and en_n == 0 then return "to_en" end
  if en_n > 0 and ru_n == 0 then return "to_ru" end
  return nil
end
```

### 7.2 Посимвольное отображение

```lua
---@return string text, boolean changed
function M.convert(text, from, to)
  local out, changed = {}, false
  for _, ch in ipairs(chars(text)) do
    local hit = from.reverse[ch]
    local repl = ch
    if hit then
      local target = to.keys[hit.key]
      if target then
        repl = hit.shift and target.shift or target.plain
      end
    end
    changed = changed or repl ~= ch
    out[#out + 1] = repl
  end
  return table.concat(out), changed
end
```

Свойства:

- регистр сохраняется автоматически: в таблицах есть и строчные, и прописные;
- символы, которых нет в исходной раскладке (латиница при `to_ru`, знаки
  препинания вне таблицы, эмодзи), остаются без изменений;
- отображение биективно для встроенных пар, поэтому повторное нажатие
  возвращает исходный текст;
- сложность O(n), на больших выделениях работает линейно;
- переводы строк не отображаются и не меняются.

Почему не `vim.fn.tr()`: он работает побайтово и на кириллице даёт мусор
(проверено: `tr("ghbdtn", ascii, cyrillic)` → `ёжбгтм`). Посимвольный цикл
ещё и позволяет точно понять, изменился ли текст.

### 7.3 Примеры

| Пара                                  | Ввод      | Результат |
| ------------------------------------- | --------- | --------- |
| `en(qwerty)` → `ru(winkeys)`          | `ghbdtn`  | `привет`  |
| `en(qwerty)` → `ru(winkeys)`          | `Ghbdtn?` | `Привет,` |
| `ru(winkeys)` → `en(qwerty)`          | `руддщ`   | `hello`   |
| `en(qwerty)` → `ru(phonetic)`         | `privet`  | `прижет`  |
| `en(qwerty)` → `ru(phonetic_winkeys)` | `priwet`  | `привет`  |
| `en(qwerty)` → `ru(phonetic_winkeys)` | `#`       | `ё`       |

---

## 8. Диапазоны и замена текста

### 8.1 Последнее слово (normal)

Вход: строка, 0-based байтовая колонка курсора, предикат «является ли
символ словом». Выход: `{ lnum, start_col, end_col, text }`, где `end_col`
исключающий, 0-based.

```lua
local spans = char_spans(line)          -- {ch, start, stop}, 0-based байты
local i = index_of(spans, cursor_col)   -- индекс символа под курсором, -1 если нет
if i < 1 then return nil end

-- если под курсором не буква (пунктуация, пробел) — ищем ближайшую букву слева
if not is_word(spans[i].ch) then
  i = i - 1
  while i >= 1 and not is_word(spans[i].ch) do i = i - 1 end
end
if i < 1 then return nil end

local l, r = i, i
while l > 1 and is_word(spans[l - 1].ch) do l = l - 1 end
while r < #spans and is_word(spans[r + 1].ch) do r = r + 1 end
return { start_col = spans[l].start, end_col = spans[r].stop }
```

`is_word`:

- `normal_scope = "word"` — символ входит в `alphabet_set` любой из двух
  раскладок (буквы, включая `ё` и верхний регистр);
- `normal_scope = "token"` — символ не является пробелом (`%s`).

Курсор может стоять на последнем байте многобайтового символа — индекс
символа ищется по интервалу `[start, stop)`, а не по точному равенству.

Крайние случаи: пустая строка → `nil`; курсор на цифре/пунктуации, слева
нет букв → `nil`; слово не может тянуться через перевод строки.

### 8.2 Visual-выделение

Используем marks и `getregionpos`:

```lua
local p1, p2 = vim.fn.getpos("'<"), vim.fn.getpos("'>")
local mode = vim.fn.visualmode()          -- "v" | "V" | "\22"
local ranges = vim.fn.getregionpos(p1, p2, { type = mode })
```

`getregionpos` возвращает по паре позиций на каждую строку:
`{ { buf, lnum1, col1, off1 }, { buf, lnum2, col2, off2 } }`. Для каждой
пары:

- `start_col = col1 - 1` (0-based);
- `end_col` — исключающий 0-based байт после последнего символа:

```lua
local function end_exclusive(line, col_1based)
  if col_1based < 1 then return 0 end
  if col_1based > #line then return #line end
  local char_idx = vim.fn.charidx(line, col_1based - 1)
  if char_idx < 0 then return #line end
  return vim.fn.byteidx(line, char_idx + 1)
end
```

- `text = line:sub(col1, end_col)` — в Lua `sub` 1-based и включает последний
  байт, а `end_col` как 0-based exclusive как раз равен 1-based индексу
  последнего байта;
- пустые строки (`col1 == 0` или `line == ""`) пропускаются;
- для linewise `getregionpos` сам нормализует конец строки до её длины;
- multi-byte символы не разрезаются: `charidx` находит символ, содержащий
  байт, `byteidx` возвращает границу после него.

`off` в позициях нужен для блочного выделения с табами/широкими символами;
в v0.1.0 мы конвертируем целые символы, покрывающие диапазон, и не пытаемся
резать таб по экранным ячейкам. Это documented limitation.

### 8.3 Запись в буфер

Все сегменты применяются одной записью (гарантирует один `undo` и
сохранение количества строк):

```lua
local first = segments[1].lnum
local last  = segments[#segments].lnum
local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)

for _, seg in ipairs(segments) do
  local i = seg.lnum - first + 1
  lines[i] = lines[i]:sub(1, seg.start_col)
          .. seg.new_text
          .. lines[i]:sub(seg.end_col + 1)
end

vim.api.nvim_buf_set_lines(buf, first - 1, last, false, lines)
```

Инварианты:

- сегменты отсортированы по `lnum`, не пересекаются, по одному на строку;
- `#lines == last - first + 1` — проверяется assert'ом;
- если ни один `new_text` не отличается от исходного, запись не выполняется;
- запись выполняется только после проверки `modifiable`/`binary`/buftype.

Курсор после записи:

```lua
local seg = segments[#segments]
local line = vim.fn.getline(seg.lnum)
local col = math.min(seg.start_col + #seg.new_text - 1, #line - 1)
col = vim.fn.byteidx(line, vim.fn.charidx(line, col))
vim.api.nvim_win_set_cursor(0, { seg.lnum, math.max(col, 0) })
```

`math.min(..., #line - 1)` и `charidx` не дают встать внутрь UTF-8 символа
или за конец строки.

### 8.4 Undo, marks, view

- Один вызов `nvim_buf_set_lines` → один шаг `undo`. Проверяется тестом:
  буфер загружается из файла (чтение файла не создаёт undo-историю), затем
  плагин меняет текст, `u` возвращает содержимое файла.
- Marks `'[`/`']` не выставляем вручную; при необходимости добавляем в v0.2.
- `winsaveview`/`winrestview` не используем: количество строк не меняется,
  курсор ставим явно. Если появится дёрганье viewport на больших
  выделениях — добавить сохранение view.

---

## 9. Ошибки и крайние случаи

| Ситуация                                | Поведение                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------- |
| Неизвестная раскладка в `setup()`       | `error()` с перечнем доступных id                                                      |
| Неизвестная раскладка в `switch()`      | ERROR-notify, без изменения буфера                                                     |
| Неверный аргумент `:PuntoSwitch`        | ERROR-notify: ожидается `auto`, `to_ru` или `to_en`                                    |
| `not modifiable`, `binary`              | WARN-notify, выход                                                                     |
| buftype/filetype в ignore-списке        | тихий выход                                                                            |
| Нет букв / смешанный текст при `auto`   | WARN-notify, выход                                                                     |
| Нет слова под курсором и слева          | WARN-notify, выход                                                                     |
| Пустое выделение / пустые строки        | пропуск строк; если всё пусто — no-op                                                  |
| Пунктуация в normal                     | не трогается (кроме `normal_scope = "token"`)                                          |
| Пунктуация в visual                     | конвертируется по позициям клавиш                                                      |
| NFD/комбинирующие символы               | не нормализуем; такие символы не находятся в карте и остаются, слово может разорваться |
| `virtualedit`/табы в blockwise          | целые символы, точность до ячейки не гарантируется                                     |
| Буфер изменился между чтением и записью | не рассматриваем: всё синхронно в одном вызове                                         |
| Очень большое выделение                 | O(n), без лимитов; при желании — предупреждение в v0.2                                 |
| Ошибка в колбэке                        | `pcall` в маппинге/команде, ERROR-notify                                               |

---

## 10. Тестирование

### 10.1 Раннер

Без внешних зависимостей: `tests/run.lua` с `test(name, fn)`, `eq`, `ok`,
`raises`. Запуск:

```bash
nvim --headless -u tests/minimal_init.lua -i NONE -n -l tests/run.lua
```

`tests/minimal_init.lua`:

```lua
local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
```

При падении — `vim.cmd("cquit 1")`.

`Makefile`:

```make
NVIM ?= nvim
test:
 $(NVIM) --headless -u tests/minimal_init.lua -i NONE -n -l tests/run.lua
```

### 10.2 Unit-тесты

**layouts**

- длины рядов и 94 уникальных символа для всех встроенных раскладок;
- алфавит покрыт таблицей;
- известные пары: `ghbdtn`/`привет` для `ru(winkeys)`, `priwet`/`привет`
  для `ru(phonetic_winkeys)`, `privet`/`прижет` для обоих фонетических;
- `ru(phonetic_winkeys)` и `ru(phonetic)` различаются только `h/x/=`;
- `get("ru")` → `ru(winkeys)`, `get("en")` → `en(qwerty)`;
- неизвестный id → `nil`;
- `register_layout` с дубликатом символа → ошибка.

**convert**

- прямое и обратное направление, регистр;
- пунктуация по клавишам: en `?` → ru `,`, ru `?` → en `&` (winkeys),
  `#` → `ё` (phonetic_winkeys);
- символы вне карты остаются;
- round-trip для всех 94 символов обеих раскладок;
- `changed = false` для текста без конвертируемых символов;
- `detect_direction`: латиница → `to_ru`, кириллица → `to_en`,
  пусто/смешанно → `nil`.

**word**

- таблица кейсов из § 3.2;
- курсор на первом/последнем байте многобайтового символа;
- `normal_scope = "token"` для `ghbdtn?`;
- пустая строка, строка из цифр, курсор в начале строки.

### 10.3 Интеграционные тесты

- normal: буфер, курсор, `:PuntoSwitch`, проверка строки и курсора;
- visual charwise: marks через `setpos`, `visualmode` через `normal! v` +
  `Esc`, команда `'<,'>PuntoSwitch`, проверка точного фрагмента;
- visual linewise: весь диапазон строк, количество строк не изменилось;
- blockwise на ASCII: по одному сегменту на строку;
- пустая строка внутри выделения;
- `undo` после конвертации (буфер из файла) — один шаг;
- no-op не создаёт запись и не ломает undo;
- `binary`/`nomodifiable` — буфер не изменён, notify;
- неизвестная раскладка в `setup` — ошибка;
- повторный `setup()` не плодит маппинги;
- `:PuntoSwitch to_en` на кириллице.

### 10.4 CI

```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        nvim: ["v0.11.4", "stable", "nightly"]
    steps:
      - uses: actions/checkout@v4
      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.nvim }}
      - run: make test
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: JohnnyMorganz/stylua-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          version: latest
          args: --check .
```

`nightly` не блокирует merge (пометка `continue-on-error` или отдельный
workflow) — API Neovim меняется.

Пример приведён для GitHub Actions. Если репозиторий живёт на Gitea/Forgejo,
синтаксис workflow совместим; меняются только ссылки на actions/registry.

Ручной чек-лист перед релизом:

- [ ] хоткей работает в normal и visual;
- [ ] `u` отменяет одной командой;
- [ ] курсор не уезжает и не встаёт внутрь буквы;
- [ ] `:checkhealth punto` зелёный;
- [ ] `:help punto` открывается;
- [ ] проверено на `ru(winkeys)` и `ru(phonetic_winkeys)`;
- [ ] проверено в пустом буфере, на пустой строке, в конце файла;
- [ ] нет ошибок в `:messages` после серии нажатий.

---

## 11. Документация и поставка

**README.md** (русский, вверху короткий English summary):

1. Что делает, GIF/asciinema с `ghbdtn` → `привет`.
2. Требования: Neovim ≥ 0.11.
3. Установка: lazy.nvim, `packadd`, ручной `runtimepath`.
4. Настройка: дефолты и 2–3 примера.
5. Команды, маппинги, направления.
6. Встроенные раскладки + предупреждение про ЯВЕРТ/ЯЖЕРТ; как добавить свою.
7. Ограничения: пунктуация, смешанный текст, NFD, blockwise.
8. Разработка: `make test`, стиль, CI.
9. Лицензия MIT.

**doc/punto.txt** — теги `*punto*`, `*punto-setup*`, `*punto-config*`,
`*:PuntoSwitch*`, `*punto-layouts*`, `*punto-api*`, `*punto-health*`.
Секции: установка, настройка, команды, раскладки, API, troubleshooting.
`doc/tags` не коммитим; в README — `:helptags doc` (lazy.nvim делает сам).

**health.lua**: проверяет версию Neovim, наличие `getregionpos`, резолв
`layout`/`latin_layout`, количество клавиш, наличие команды и маппингов,
выводит текущее направление. Формат — `vim.health.*`.

**Релиз**: `CHANGELOG.md` (Keep a Changelog), тег `v0.1.0`, GitHub/Gitea
Release. Без LuaRocks и без автогенерации тегов.

---

## 12. Этапы работ

Оценки — в идеальных часах для одного разработчика, без учёта ревью.

| Этап                         | Работы                                                                                    | Результат / DoD                                             | Оценка      |
| ---------------------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ----------- |
| **M0. Каркас**               | репозиторий, LICENSE, `.gitignore`, `stylua.toml`, `Makefile`, пустой раннер, CI-skeleton | `make test` запускается, CI зелёный на пустом наборе        | 0.5–1 ч     |
| **M1. Раскладки**            | 4 spec-файла, `build`, `reverse`, реестр, алиасы, `register_layout`, unit-тесты           | 4 раскладки собираются, валидация и известные пары зелёные  | 2–3 ч       |
| **M2. Конвертация**          | `convert`, `detect_direction`, `util.chars/char_spans`, тесты                             | round-trip 94 символов, примеры из § 7.3                    | 1–2 ч       |
| **M3. Normal + config**      | `config`, `word`, ленивая инициализация, валидация, тесты слова                           | `switch({ mode = "normal" })` работает на всех кейсах § 3.2 | 2–3 ч       |
| **M4. Visual + apply**       | `selection` (getregionpos, сегменты, apply, курсор), тесты                                | charwise/linewise/blockwise, один undo, курсор корректен    | 3–4 ч       |
| **M5. Обвязка**              | `init.setup/switch`, команда с range, маппинги, notify, health                            | хоткей и `:PuntoSwitch` работают вручную, health зелёный    | 1–2 ч       |
| **M6. Документация и релиз** | README, `doc/punto.txt`, CI-матрица, ручной чек-лист, тег                                 | v0.1.0 опубликован, все проверки зелёные                    | 3–4 ч       |
|                              |                                                                                           | **Итого**                                                   | **13–19 ч** |

Порядок M1→M2→M3→M4 можно менять; M5 зависит от M3/M4, M6 — от всех.

Критерии готовности v0.1.0:

- [ ] дефолтный `setup()` работает без аргументов;
- [ ] `priwet` + хоткей → `привет` при `ru(phonetic_winkeys)`;
- [ ] `ghbdtn` + хоткей → `привет` при `ru(winkeys)`;
- [ ] visual конвертирует ровно выделение, включая несколько строк;
- [ ] `u` отменяет одной командой;
- [ ] no-op и ошибки не ломают буфер;
- [ ] тесты на 0.11/0.12/nightly;
- [ ] README + `:help punto` + health;
- [ ] нет runtime-зависимостей.

---

## 13. Риски и меры

| Риск                                                    | Проявление                                     | Мера                                                                        |
| ------------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------------- |
| Таблицы не совпадают с реальной раскладкой пользователя | неверные буквы, «плагин сломан»                | сверка с `xkbcli`, тесты, `register_layout`, предупреждение про ЯВЕРТ/ЯЖЕРТ |
| Пунктуация при normal остаётся                          | `привет?` вместо `привет,`                     | документировано; `normal_scope = "token"`; visual для точного фрагмента     |
| Blockwise + табы/`virtualedit`                          | символ на границе блока конвертируется целиком | best effort, тест на ASCII, ограничение в README                            |
| Undo несколькими шагами                                 | `u` отменяет не всё                            | одна запись `set_lines`, тест с буфером из файла                            |
| Конфликт хоткея                                         | перетирание чужого маппинга                    | дефолт `<Leader>sw`, настройка, `keymap = false`, `desc` для which-key      |
| `getregionpos` отсутствует в 0.10                       | visual не работает                             | минимум 0.11, проверка в health; при необходимости fallback в v0.2          |
| Смешанный текст                                         | половина фрагмента конвертирована              | auto отказывается, явное направление                                        |
| NFD/комбинированные символы                             | слово рвётся, буква не найдена                 | документировано; нормализация — вне scope                                   |
| Ошибка в колбэке ломает ввод                            | сообщение в буфере                             | `pcall` + notify, без throw из маппинга                                     |

---

## 14. Принятые решения

Решения подтверждены 2026-11-25:

1. Пара раскладок фиксирована: `latin_layout` ↔ `layout`; системная
   раскладка ОС не определяется.
2. `auto` конвертирует только однородный по письменности текст; смешанный —
   no-op с подсказкой.
3. Normal конвертирует только буквы слова; пунктуация — через visual или
   `normal_scope = "token"`.
4. Visual конвертирует все символы, включая пунктуацию (позиционная
   семантика).
5. Одна запись в буфер → один undo; курсор в конце фрагмента.
6. Никаких внешних зависимостей; минимум Neovim 0.11.
7. Сообщения и код — на английском, README — на русском (с English summary).
8. Встроенные раскладки — четыре перечисленные; остальные через
   `register_layout`.
9. Хоткей по умолчанию `<Leader>sw` — принят.
10. `normal_scope = "word"` — принят.
11. Отдельная опция «конвертировать только буквы» для visual в v0.1.0
    не нужна.
12. Минимум Neovim 0.11 — достаточно; fallback для 0.10 не делаем.

**Отложено до v0.2:** `count`, `.`-repeat, выставление marks `'[`/`']`,
предупреждение о больших выделениях.

---

## Приложение A. Данные раскладок

Физическая сетка и порядок клавиш:

```lua
-- 47 клавиш: TLDE + AE01..AE12, AD01..AD12 + BKSL, AC01..AC11, AB01..AB10
local QWERTY_ROWS = {
  "`1234567890-=",   -- 13
  "qwertyuiop[]\\",  -- 13 (последняя — backslash)
  "asdfghjkl;'",     -- 11
  "zxcvbnm,./",      -- 10
}
```

`en(qwerty)`:

```lua
rows = {
  { "`1234567890-=",  "~!@#$%^&*()_+" },
  { "qwertyuiop[]\\", "QWERTYUIOP{}|" },
  { "asdfghjkl;'",    'ASDFGHJKL:"'   },
  { "zxcvbnm,./",     "ZXCVBNM<>?"    },
}
```

`ru(winkeys)`:

```lua
rows = {
  { "ё1234567890-=",  'Ё!"№;%:?*()_+' },
  { "йцукенгшщзхъ\\", "ЙЦУКЕНГШЩЗХЪ/" },
  { "фывапролджэ",    "ФЫВАПРОЛДЖЭ"   },
  { "ячсмитьбю.",     "ЯЧСМИТЬБЮ,"    },
}
```

`ru(phonetic)`:

```lua
rows = {
  { "ю1234567890-ч",  "Ю!@ёЁъЪ&*()_Ч" },
  { "явертыуиопшщэ",  "ЯВЕРТЫУИОПШЩЭ" },
  { "асдфгхйкл;'",    'АСДФГХЙКЛ:"'   },
  { "зьцжбнм,./",      "ЗЬЦЖБНМ<>?"    },
}
```

`ru(phonetic_winkeys)`:

```lua
rows = {
  { "ю1234567890-ь",  "Ю!@ёЁъЪ&*()_Ь" },
  { "явертыуиопшщэ",  "ЯВЕРТЫУИОПШЩЭ" },
  { "асдфгчйкл;'",    'АСДФГЧЙКЛ:"'   },
  { "зхцжбнм,./",      "ЗХЦЖБНМ<>?"    },
}
```

Общий алфавит русских раскладок:

```lua
alphabet = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
        .. "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
```

Проверка таблиц (Linux):

```bash
# symbols[1] для каждой клавиши — группа ru
xkbcli compile-keymap --layout 'ru,us' --variant 'phonetic_winkeys,' \
  | grep -A3 'key <AD01>'
```

Данные сверены с `/usr/share/X11/xkb/symbols/ru`; upstream —
<https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config/-/blob/master/symbols/ru>.
При расхождении с системной раскладкой пользователь добавляет свою таблицу
через `register_layout()`.
