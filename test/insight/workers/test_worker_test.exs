defmodule Insight.Workers.TestWorkerTest do
  use Insight.DataCase, async: true
  use Oban.Testing, repo: Insight.Repo

  alias Insight.Workers.TestWorker

  test "worker enqueues and processes jobs correctly" do
    # Register this process to receive the message from the worker
    Process.register(self(), :test_worker_process)

    # Enqueue a job
    assert {:ok, _job} = %{"id" => 123} |> TestWorker.new() |> Oban.insert()

    # Assert job was enqueued
    assert_enqueued(worker: TestWorker, args: %{"id" => 123})

    # Execute the job inline
    assert :ok = perform_job(TestWorker, %{"id" => 123})

    # Assert the worker sent the correct message
    assert_receive {:processed, 123}
  end
end
