defmodule SubscribeToStreamBench do
  use Benchfella

  alias EventStore.{EventFactory, ProcessHelper, StorageInitializer}
  alias TestEventStore, as: EventStore

  @await_timeout_ms 100_000

  before_each_bench(_) do
    StorageInitializer.reset_storage!()

    {:ok, pid} = TestEventStore.start_link()

    context = [events: EventFactory.create_events(100), pid: pid]

    {:ok, context}
  end

  after_each_bench(context) do
    pid = Keyword.fetch!(context, :pid)

    ProcessHelper.shutdown(pid)
  end

  bench "subscribe to stream, 1 subscription" do
    subscribe_to_stream(bench_context, 1)
  end

  bench "subscribe to stream, 10 subscriptions" do
    subscribe_to_stream(bench_context, 10)
  end

  bench "subscribe to stream, 20 subscriptions" do
    subscribe_to_stream(bench_context, 20)
  end

  bench "subscribe to stream, 50 subscriptions" do
    subscribe_to_stream(bench_context, 50)
  end

  defp subscribe_to_stream(context, concurrency) do
    events = Keyword.fetch!(context, :events)
    stream_uuid = UUID.uuid4()

    tasks =
      Enum.map(1..concurrency, fn index ->
        Task.async(fn ->
          {:ok, _subscription} =
            EventStore.subscribe_to_stream(stream_uuid, "subscription-#{index}", self())

          receive do
            {:events, _events} ->
              :ok = EventStore.unsubscribe_from_stream(stream_uuid, "subscription-#{index}")
          end
        end)
      end)

    append_task =
      Task.async(fn ->
        :ok = EventStore.append_to_stream(stream_uuid, 0, events)
      end)

    Enum.each([append_task | tasks], &Task.await(&1, @await_timeout_ms))
  end
end
