defmodule AnomaExplorer.Indexer.StatsSupervisorTest do
  @moduledoc """
  Tests for the StatsSupervisor module.
  """
  use ExUnit.Case, async: false

  alias AnomaExplorer.Indexer.StatsSupervisor

  describe "child_spec/1" do
    test "returns a valid supervisor spec" do
      spec = StatsSupervisor.child_spec([])

      assert spec.id == StatsSupervisor
      assert spec.type == :supervisor
    end
  end

  describe "module structure" do
    test "defines start_link/1" do
      assert function_exported?(StatsSupervisor, :start_link, 1)
    end

    test "implements Supervisor behaviour" do
      behaviours = StatsSupervisor.__info__(:attributes)[:behaviour] || []
      assert Supervisor in behaviours
    end
  end
end
