defmodule SnapshyTest do
  use Snapshy
  use ExUnit.Case

  doctest Snapshy

  test_snapshot "a returns a double of a given number" do
    ["abcd", "efgh", "hello"]
  end
end
