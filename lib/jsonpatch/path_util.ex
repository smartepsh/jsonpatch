defmodule Jsonpatch.PathUtil do
  @moduledoc false

  # ===== Internal documentation =====
  # Helper module for handling JSON paths.

  @doc """
  Uses a JSON patch path to get the last map that this path references.

  ## Examples

      iex> path = "/a/b/c/d"
      iex> target = %{"a" => %{"b" => %{"c" => %{"d" => 1}}}}
      iex> Jsonpatch.PathUtil.get_final_destination(target, path)
      {%{"d" => 1}, "d"}

      iex> # Invalid path
      iex> path = "/a/e/c/d"
      iex> target = %{"a" => %{"b" => %{"c" => %{"d" => 1}}}}
      iex> Jsonpatch.PathUtil.get_final_destination(target, path)
      {:error, :invalid_path, "e"}

      iex> path = "/a/b/1/d"
      iex> target = %{"a" => %{"b" => [true, %{"d" => 1}]}}
      iex> Jsonpatch.PathUtil.get_final_destination(target, path)
      {%{"d" => 1}, "d"}

      iex> # Invalid path
      iex> path = "/a/b/42/d"
      iex> target = %{"a" => %{"b" => [true, %{"d" => 1}]}}
      iex> Jsonpatch.PathUtil.get_final_destination(target, path)
      {:error, :invalid_index, "42"}
  """
  @spec get_final_destination(map, binary) ::
          {map, binary} | {list, binary} | Jsonpatch.error()
  def get_final_destination(target, path) when is_bitstring(path) do
    # The first element is always "" which is useless.
    [_ | fragments] = String.split(path, "/") |> Enum.map(&unescape/1)
    find_final_destination(target, fragments)
  end

  @doc """
  Updatest a map reference by a given JSON patch path with the new final destination.

  ## Examples

      iex> path = "/a/b/c/d"
      iex> target = %{"a" => %{"b" => %{"c" => %{"d" => 1}}}}
      iex> Jsonpatch.PathUtil.update_final_destination(target, %{"e" => 1}, path)
      %{"a" => %{"b" => %{"c" => %{"e" => 1}}}}
  """
  @spec update_final_destination(map, map | list, binary) :: map | Jsonpatch.error()
  def update_final_destination(target, new_destination, path) do
    # The first element is always "" which is useless.
    [_ | fragments] = String.split(path, "/") |> Enum.map(&unescape/1)
    do_update_final_destination(target, new_destination, fragments)
  end

  @doc """
  Unescape `~1` to  `/` and `~0` to `~`.
  """
  def unescape(fragment) when is_bitstring(fragment) do
    fragment
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  def unescape(fragment) do
    fragment
  end

  # ===== ===== PRIVATE ===== =====

  defp find_final_destination(%{} = target, [fragment | []]) do
    {target, fragment}
  end

  defp find_final_destination(target, [fragment | []]) when is_list(target) do
    {target, fragment}
  end

  defp find_final_destination(%{} = target, [fragment | tail]) do
    case Map.get(target, fragment) do
      nil -> {:error, :invalid_path, fragment}
      val -> find_final_destination(val, tail)
    end
  end

  defp find_final_destination(target, [fragment | tail]) when is_list(target) do
    {index, _} = Integer.parse(fragment)

    case Enum.fetch(target, index) do
      :error -> {:error, :invalid_index, fragment}
      {:ok, val} -> find_final_destination(val, tail)
    end
  end

  # " [final_dest | [_last_ele |[]]] " means: We want to stop, when there are only two elements left.
  defp do_update_final_destination(%{} = target, new_final_dest, [final_dest | [_last_ele | []]]) do
    Map.replace!(target, final_dest, new_final_dest)
  end

  defp do_update_final_destination(target, new_final_dest, [final_dest | [_last_ele | []]])
       when is_list(target) do
    {index, _} = Integer.parse(final_dest)

    List.replace_at(target, index, new_final_dest)
  end

  defp do_update_final_destination(_target, new_final_dest, [_fragment | []]) do
    new_final_dest
  end

  defp do_update_final_destination(%{} = target, new_final_dest, [fragment | tail]) do
    case Map.get(target, fragment) do
      nil ->
        {:error, :invalid_path, fragment}

      val ->
        case do_update_final_destination(val, new_final_dest, tail) do
          {:error, _, _} = error -> error
          updated_val -> %{target | fragment => updated_val}
        end
    end
  end

  defp do_update_final_destination(target, new_final_dest, [fragment | tail])
       when is_list(target) do
    {index, _} = Integer.parse(fragment)

    List.update_at(target, index, &do_update_final_destination(&1, new_final_dest, tail))
  end
end
