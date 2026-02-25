defmodule Insight.Workers.TestWorker do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => id}}) do
    send(:test_worker_process, {:processed, id})
    :ok
  end
end
