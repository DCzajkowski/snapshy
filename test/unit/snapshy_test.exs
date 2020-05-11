defmodule Struct do
  defstruct key: "value"
end

defmodule SnapshyTest do
  use Snapshy
  use ExUnit.Case

  doctest Snapshy

  test "it saves a file for long keyword lists" do
    match_snapshot(Enum.map(1..100, fn x -> {:hello, x} end))
  end

  test "it saves a file for long binaries" do
    match_snapshot(Enum.join(1..10000, ","))
  end

  test "it saves a file for custom structs with default data" do
    match_snapshot(%Struct{})
  end

  test "it saves a file for custom structs" do
    match_snapshot(%Struct{key: "different_value"})
  end

  describe "test_snapshot" do
    setup do
      [key: :value]
    end

    test_snapshot "it accepts a context", context do
      context
    end
  end
end
