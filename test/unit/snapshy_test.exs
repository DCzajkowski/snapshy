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

  test "saved file can be evaluated for opaque structs when serialize structs option is false (default)",
       %{test: test_name} do
    snap_filename = snap_file_for_test(test_name)

    assert File.exists?(snap_filename) == false

    original_serialized_inspect_options =
      Application.get_env(:snapshy, :serialize_inspect_options, [])

    opaque_struct = %Struct{key: Version.parse!("1.2.3")}

    match_snapshot(opaque_struct)

    assert {:ok, serialized_value} = File.read(snap_filename)

    assert {^opaque_struct, []} = Code.eval_string(serialized_value, [], __ENV__)

    assert File.rm(snap_filename)

    Application.put_env(:snapshy, :serialize_inspect_options, original_serialized_inspect_options)
  end

  defp snap_file_for_test(test_name) do
    [
      "test/__snapshots__/unit/snapshy_test/",
      Atom.to_string(test_name) |> String.replace(" ", "_"),
      ".snap"
    ]
    |> Enum.join()
  end

  describe "test_snapshot" do
    setup do
      [key: :value]
    end

    test_snapshot "it accepts a context", context do
      context[:key]
    end
  end
end

defmodule SnapshyDirectoryTest do
  use Snapshy, snapshot_location: "test/some_env/__snapshots__"
  use ExUnit.Case

  test "saves snapshot in specified directory" do
    match_snapshot(%Struct{})
  end
end
