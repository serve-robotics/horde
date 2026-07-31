defmodule Horde.ClusterTransport.Erlang do
  @moduledoc "Cluster transport using standard Erlang distribution."

  @behaviour Horde.ClusterTransport

  @impl true
  def members(), do: Node.list()

  @impl true
  def process_alive?(pid) when node(pid) == node(), do: Process.alive?(pid)

  def process_alive?(pid) do
    n = node(pid)

    Node.list() |> Enum.member?(n) &&
      :erpc.call(n, Process, :alive?, [pid])
  catch
    :error, {:erpc, :noconnection} -> false
    type, reason -> :erlang.raise(type, reason, __STACKTRACE__)
  end

  @impl true
  def call(node, mod, fun, args, timeout) do
    :erpc.call(node, mod, fun, args, timeout)
  end
end
