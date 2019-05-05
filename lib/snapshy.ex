defmodule Snapshy do
  defmacro __using__(_options) do
    quote do
      import Snapshy, only: [match_snapshot: 1, test_snapshot: 2]
    end
  end

  defmacro match_snapshot(value) do
    quote do
      Snapshy.match(unquote(value), unquote(Macro.escape(__CALLER__)))
    end
  end

  defmacro test_snapshot(name, do: expr) do
    quote do
      test unquote(name) do
        match_snapshot(unquote(expr))
      end
    end
  end

  def match(actual_value, %Macro.Env{function: function, file: file}) do
    file = get_file(file, function)

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
    |> Inspect.Algebra.to_doc(%Inspect.Opts{
      limit: :infinity,
      printable_limit: :infinity,
      binaries: :as_binaries,
      pretty: true
    })
    |> Inspect.Algebra.group()
    |> Inspect.Algebra.format(80)
    |> Enum.join()
  end

  defp deserialize(value) do
    {term, []} = Code.eval_string(value, [], __ENV__)

    term
  end

  #############################################################################
  #  Filename calculation                                                     #
  #############################################################################

  defp get_file(file, function) do
    directory = snapshot_directory(file)
    filename = get_key(function) <> ".snap"

    ["test/", "__snapshots__/", directory, filename]
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
