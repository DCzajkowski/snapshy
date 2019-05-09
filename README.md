# Snapshy

Snapshy is an Elixir package for running snapshot tests in ExUnit. More extensive documentation is coming soon.

## Installation

Add `snapshy` to your list of dependencies in `mix.exs` and run `mix deps.get`:

```elixir
def deps do
  [
    # ...
    {:snapshy, "~> 0.1.0"}
  ]
end
```

## Overview

The way this works:

1. Add Snapshy to the test

```diff
 defmodule TokenizerTest do
+  use Snapshy
   use ExUnit.Case

   # ...
 end
```

2. Replace `test` with `test_snapshot`

```diff
-  test "correctly tokenizes booleans" do
+  test_snapshot "correctly tokenizes booleans" do
     # ...
   end
```

3. Replace an assertion with simple function call

```diff
-    assert(
-      tokens("true false") == [
-        boolean: "true",
-        boolean: "false"
-      ]
-    )
+    tokens("true false")
```

The first time a snapshot will be created in `test/__snapshots__/path/to/test_file/function_name.stub`. The second time, an assertion will be made against the snapshot. If you make changes and you want to update snapshots, run `SNAPSHY_OVERRIDE=true mix test` instead of `mix test`. Verify in git every change is correct.

Alternatively, you can use a macro call instead of the `test_snapshot` macro like so:
```elixir
test "correctly tokenizes booleans" do
  match_snapshot tokens("true false")
end
```
**Careful!** There can only be one `match_snapshot` call per test macro call.
