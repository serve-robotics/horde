if Code.ensure_loaded?(:partisan_peer_service) do
  defmodule Horde.ClusterTransport.Partisan do
    @moduledoc "Cluster transport using Partisan for peer communication."

    @behaviour Horde.ClusterTransport

    @impl true
    def members() do
      case :partisan_peer_service.members() do
        members when is_list(members) ->
          members
          |> Enum.map(& &1.name)
          |> Enum.reject(&(&1 == node()))

        _ ->
          []
      end
    rescue
      _ -> []
    end

    @impl true
    def process_alive?(pid) when node(pid) == node(), do: Process.alive?(pid)

    def process_alive?(pid) do
      n = node(pid)

      if peer?(n) do
        try do
          :partisan_rpc.call(n, Process, :alive?, [pid], 5_000)
        catch
          _, _ -> false
        end
      else
        false
      end
    end

    @impl true
    def call(node, mod, fun, args, timeout) do
      :partisan_rpc.call(node, mod, fun, args, timeout)
    end

    defp peer?(node) do
      case :partisan_peer_service.members() do
        members when is_list(members) -> Enum.any?(members, &(&1.name == node))
        _ -> false
      end
    rescue
      _ -> false
    end
  end
end
