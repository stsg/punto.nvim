local T = {
  passed = 0,
  failed = 0,
  failures = {},
}

---@param name string
---@param fn function
function T.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    T.passed = T.passed + 1
    return
  end
  T.failed = T.failed + 1
  T.failures[#T.failures + 1] = { name = name, err = tostring(err) }
  io.stderr:write(("FAIL: %s\n  %s\n"):format(name, tostring(err):gsub("\n", "\n  ")))
end

---@param expected any
---@param actual any
---@param msg string|nil
function T.eq(expected, actual, msg)
  if not vim.deep_equal(expected, actual) then
    error(
      ("%s\n  expected: %s\n  actual:   %s"):format(
        msg or "values differ",
        vim.inspect(expected),
        vim.inspect(actual)
      ),
      2
    )
  end
end

---@param condition any
---@param msg string|nil
function T.ok(condition, msg)
  if not condition then
    error(msg or "expected a truthy value", 2)
  end
end

---@param fn function
---@param pattern string|nil
---@return string error message
function T.raises(fn, pattern)
  local ok, err = pcall(fn)
  if ok then
    error("expected an error, but the function succeeded", 2)
  end
  err = tostring(err)
  if pattern and not err:match(pattern) then
    error(("error %q does not match %q"):format(err, pattern), 2)
  end
  return err
end

_G.T = T

require("tests.spec.layouts_spec")
require("tests.spec.convert_spec")
require("tests.spec.word_spec")
require("tests.spec.selection_spec")
require("tests.spec.command_spec")

print(("punto: %d passed, %d failed"):format(T.passed, T.failed))
if T.failed > 0 then
  vim.cmd("cquit 1")
end
