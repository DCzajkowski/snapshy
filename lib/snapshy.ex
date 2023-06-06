defmodule Snapshy do
  @moduledoc """
  Snapshy is a simple snapshot testing library for ExUnit.

  ## What is snapshot testing?
  Snapshot tests work a little bit different compared to regular
  unit or integration tests. The only difference is that in snapshot
  tests you don't write any assertions. You only tell the library
  test this function call for me and I don't want to write any assertions
  for it. When that happens, Snapshy takes a result of a function call
  and stores it in a file (this is what is called a "snapshot").
  When this happens, a capital `S` is displayed in your test suite.
  Next time you run a test, an assertion will be made
  against that file. If it fails, you can either fix your code or override
  the snapshot with current result.

  ## When is snapshot testing useful?
  Snapshot testing is very useful if you have some type of pure function or
  command, that is tested in many different scenarios. In most cases,
  these tests are written if you are working on a compiler, code beautifier
  etc. where a result of the function/command is long and doesn't have any
  particular meaning, but you want the result to be preserved when you are
  refactoring your code or adding a new feature. In these cases, more important
  is what input you are testing, not what output you got. As long as it is the
  same as it used to be, you are good to go.

  ## How to get started?
  Getting started with Snapshy is very easy.

  Add the `use Snapshy` statement in the test suite that will be designated for
  your snapshot tests. Note, it is not required for it to have only snapshot
  tests.

      defmodule ExampleTest do
        use Snapshy
        use ExUnit.Case

        # ...
      end

  To mark a test as a snapshot, use the `Snapshy.test_snapshot` macro.

      test_snapshot "returns the hello message" do
        "Hello, World!"
      end

  In this case, the snapshot would be stored in
  `/test/__snapshots__/path/to/example_test/returns_the_hello_message.snap`.
  This file should be commited the same as your assertion would be.

  ## Overriding existing snapshots
  Sometimes the change you make in the output is desired. In these cases
  you can run the test with `SNAPSHY_OVERRIDE` set to true. Make sure to review
  all changes in your version control history, as all failing snapshots will be
  overridden.

  ```
  $ SNAPSHY_OVERRIDE=true mix test
  ```
  """

  defmacro __using__(opts) do
    snapshot_location = opts[:snapshot_location] || "test/__snapshots__/"
    quote do
      @snapshot_location unquote(snapshot_location)
      import Snapshy, only: [match_snapshot: 1, test_snapshot: 2, test_snapshot: 3]
    end
  end

  @doc """
  It creates a `Snapshy.match_snapshot` assertion with correct parameters.
  """
  defmacro match_snapshot(value) do
    quote do
      Snapshy.match(unquote(value), unquote(Macro.escape(__CALLER__)), @snapshot_location)
    end
  end

  @doc """
  It creates a regular test, which invokes `Snapshy.match_snapshot` with
  correct parameters.

  ## Example

      test_snapshot "returns the hello message" do
        "Hello, World!"
      end

  In this example, the "Hello, World!" string will be written to the file and
  saved for future assertions.
  """
  defmacro test_snapshot(name, do: expr) do
    quote do
      test unquote(name) do
        match_snapshot(unquote(expr))
      end
    end
  end

  @doc """
  Same as `Snashy.test_snapshot/2` but excepts a context.
  """
  defmacro test_snapshot(name, context, do: expr) do
    quote do
      test unquote(name), unquote(context) do
        match_snapshot(unquote(expr))
      end
    end
  end

  @doc """
  This function is not really supposed to be used manually, but can be used
  in rare cases when you want to have more control on the caller information.
  """
  def match(actual_value, %Macro.Env{function: function, file: file}, snapshot_location) do
    file = get_file(file, function, snapshot_location)

    case snapshot_exists?(file) do
      {true, snapshot_value} ->
        case assert(file, snapshot_value, actual_value) do
          :should_override -> save_snapshot(file, actual_value)
          :ok -> :ok
        end

      {false, _} ->
        save_snapshot(file, actual_value)
    end
  end

  #############################################################################
  #  Assertions                                                               #
  #############################################################################

  defp assert(file, snapshot_value, actual_value) do
    unless snapshot_value == actual_value do
      if override?() do
        :should_override
      else
        raise_error(file, snapshot_value, actual_value)
      end
    else
      :ok
    end
  end

  defp raise_error(file, left, right) do
    file = snapshot_directory(file)

    raise ExUnit.AssertionError,
      left: left,
      right: right,
      message: "Received value does not match stored snapshot. (#{file})",
      expr: "Snapshot == Received"
  end

  #############################################################################
  #  User interaction                                                         #
  #############################################################################

  defp override? do
    System.get_env("SNAPSHY_OVERRIDE") == "true"
  end

  defp colorize(_, string, enabled: false) do
    string
  end

  defp colorize(escape, string, _) do
    [escape, string, :reset]
    |> IO.ANSI.format_fragment(true)
    |> IO.iodata_to_binary()
  end

  defp print_created_message do
    IO.write(colorize(:yellow, "S", Application.get_env(:ex_unit, :colors)))
  end

  #############################################################################
  #  Serialization                                                            #
  #############################################################################

  defp serialize(value) do
    value
    |> Inspect.Algebra.to_doc(inspect_options())
    |> Inspect.Algebra.group()
    |> Inspect.Algebra.format(80)
    |> Enum.join()
  end

  defp deserialize(value) do
    {term, []} = Code.eval_string(value, [], __ENV__)

    term
  end

  defp inspect_options do
    opts = default_inspect_options()
      |> Keyword.merge(Application.get_env(:snapshy, :serialize_inspect_options, []))

    struct(Inspect.Opts, opts)
  end

  defp default_inspect_options do
    [
      limit: :infinity,
      printable_limit: :infinity,
      pretty: true,
      structs: false
    ]
  end

  #############################################################################
  #  Filename calculation                                                     #
  #############################################################################

  defp get_file(file, function, snapshot_location) do
    directory = snapshot_directory(file)
    filename = get_key(function) <> ".snap"

    [snapshot_location, directory, filename]
    |> Path.join()
  end

  defp get_key({function_name, _}) do
    function_name
    |> Atom.to_string()
    |> String.replace(" ", "_")
    |> Macro.underscore()
  end

  defp snapshot_directory(file) do
    path = Path.split(file)
    path = Enum.drop(path, Enum.find_index(path, fn p -> p === "test" end) + 1)
    filename = List.last(path) |> String.replace(".exs", "")
    (Enum.drop(path, -1) ++ [filename]) |> Path.join()
  end

  #############################################################################
  #  File manipulation                                                        #
  #############################################################################

  defp snapshot_exists?(file) do
    if File.exists?(file) do
      {true, get_snapshot(file)}
    else
      create_empty_snapshot(file)

      {false, nil}
    end
  end

  defp get_snapshot(file) do
    File.read!(file) |> deserialize()
  end

  defp create_empty_snapshot(file) do
    File.mkdir_p(Path.dirname(file))

    save_snapshot(file, nil, silent: true)
  end

  defp save_snapshot(file, value, opts \\ [silent: false])

  defp save_snapshot(file, value, silent: false) do
    save_snapshot(file, value, silent: true)

    print_created_message()
  end

  defp save_snapshot(file, value, silent: true) do
    File.write!(file, serialize(value))
  end
end
