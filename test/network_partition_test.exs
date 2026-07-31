defmodule NetworkPartitionTest do
  use ExUnit.Case

  @retry_attempts 20
  @retry_sleep_ms 100

  setup do
    nodes = LocalCluster.start_nodes("cluster#{:erlang.unique_integer()}", 2)

    for n <- nodes do
      :erpc.call(n, Application, :ensure_all_started, [:test_app])
    end

    [nodes: nodes]
  end

  test "recovers as expected in case of network partition", %{nodes: [n1, n2] = nodes} do
    assert {:ok, _pid1} =
             Horde.DynamicSupervisor.start_child(
               {TestSup, n1},
               {IgnoreWorker, {:via, Horde.Registry, {TestReg, IgnoreWorker}}}
             )

    assert {:ok, _pid2} =
             Horde.DynamicSupervisor.start_child(
               {TestSup, n2},
               {IgnoreWorker, {:via, Horde.Registry, {TestReg, IgnoreWorker}}}
             )

    reg_members = for n <- nodes, do: {TestReg, n}
    sup_members = for n <- nodes, do: {TestSup, n}

    for n <- nodes do
      :ok = :erpc.call(n, Horde.Cluster, :set_members, [TestReg, reg_members])
      :ok = :erpc.call(n, Horde.Cluster, :set_members, [TestSup, sup_members])
    end

    partition_id = "partition-#{System.unique_integer([:positive])}"
    :ok = partition_with_retry([n1, n2], partition_id)

    Process.sleep(100)

    :ok = heal_with_retry([n1, n2])
    :ok = assert_nodes_connected([n1, n2])

    Process.sleep(100)

    assert [{_, pid, _, _}] = Horde.DynamicSupervisor.which_children({TestSup, n1})
    assert [{_, ^pid, _, _}] = Horde.DynamicSupervisor.which_children({TestSup, n2})

    assert true = :erpc.call(node(pid), Process, :alive?, [pid])
  end

  test "recovers as expected in case of node stopping", %{nodes: [n1, n2] = nodes} do
    assert {:ok, _pid1} =
             Horde.DynamicSupervisor.start_child(
               {TestSup, n1},
               {IgnoreWorker, {:via, Horde.Registry, {TestReg, IgnoreWorker}}}
             )

    assert {:ok, _pid2} =
             Horde.DynamicSupervisor.start_child(
               {TestSup, n2},
               {IgnoreWorker, {:via, Horde.Registry, {TestReg, IgnoreWorker}}}
             )

    require Logger
    Logger.info("stitching together cluster")

    reg_members = for n <- nodes, do: {TestReg, n}
    sup_members = for n <- nodes, do: {TestSup, n}

    for n <- nodes do
      :ok = :erpc.call(n, Horde.Cluster, :set_members, [TestReg, reg_members])
      :ok = :erpc.call(n, Horde.Cluster, :set_members, [TestSup, sup_members])
    end

    Process.sleep(100)

    Logger.info("stopping #{n2}")
    LocalCluster.stop_nodes([n2])

    Process.sleep(100)

    assert [{_, pid, _, _}] = Horde.DynamicSupervisor.which_children({TestSup, n1})

    assert true = :erpc.call(node(pid), Process, :alive?, [pid])
  end

  defp partition_with_retry(nodes, partition_id) do
    retry(fn ->
      try do
        Schism.partition(nodes, partition_id)
        :ok
      rescue
        MatchError -> {:error, :partition_not_ready}
      end
    end)
  end

  defp heal_with_retry(nodes) do
    retry(fn ->
      try do
        Schism.heal(nodes)

        if Enum.all?(nodes, fn node -> Node.ping(node) == :pong end) do
          :ok
        else
          {:error, :nodes_not_reachable}
        end
      rescue
        MatchError -> {:error, :heal_not_ready}
      end
    end)
  end

  defp assert_nodes_connected(nodes) do
    retry(fn ->
      manager = node()

      if Enum.all?(nodes, fn remote ->
           expected = MapSet.new([manager | nodes])

           case :erpc.call(remote, Node, :list, [[:visible, :this]]) do
             visible when is_list(visible) ->
               visible
               |> MapSet.new()
               |> MapSet.equal?(expected)

             _ ->
               false
           end
         end) do
        :ok
      else
        {:error, :cluster_not_fully_connected}
      end
    end)
  end

  defp retry(fun, attempts \\ @retry_attempts)

  defp retry(fun, attempts) when attempts > 0 do
    case fun.() do
      :ok ->
        :ok

      {:error, _reason} when attempts == 1 ->
        flunk("operation did not converge after #{@retry_attempts} attempts")

      {:error, _reason} ->
        Process.sleep(@retry_sleep_ms)
        retry(fun, attempts - 1)
    end
  end
end
