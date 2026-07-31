defmodule Horde.NodeListener do
  @moduledoc """
  A cluster membership manager.

  Horde.NodeListener monitors nodes in BEAM's distribution system and
  automatically adds and removes those marked as `visible` from the cluster it's
  managing
  """
  use Horde.NodeListenerBehaviour

  @spec make_members(atom()) :: [{atom(), node()}]
  @impl Horde.NodeListenerBehaviour
  def make_members(cluster),
    do: Enum.map(nodes(), fn node -> {cluster, node} end)

  defp nodes(), do: Node.list([:visible, :this])
end
