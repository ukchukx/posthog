defmodule HackneyStub.State do
  use GenServer

  def start_link(_opts) do
    name = {:via, Registry, {:hackney_stub_registry, self()}}
    GenServer.start_link(__MODULE__, %{verification: nil}, name: name)
  end

  def init(state) do
    {:ok, state}
  end

  def set_verification(verification) do
    name = {:via, Registry, {:hackney_stub_registry, self()}}
    GenServer.cast(name, {:set_verification, verification})
  end

  def get_verification() do
    name = {:via, Registry, {:hackney_stub_registry, self()}}
    GenServer.call(name, :get_verification)
  end

  def handle_cast({:set_verification, verification}, state) do
    {:noreply, %{state | verification: verification}}
  end

  def handle_call(:get_verification, _from, state) do
    {:reply, state.verification, state}
  end
end

defmodule HackneyStub.Base do
  @fixtures_dir Path.join(__DIR__, "fixtures")

  defmacro __using__(fixture) do
    quote do
      @fixtures_dir unquote(@fixtures_dir)

      def post("https://us.posthog.com/decide?v=4", _headers, _body, _opts) do
        {:ok, 200, json_fixture!(unquote(fixture)), "decide"}
      end

      def post("https://us.posthog.com/capture", _headers, body, _opts) do
        case HackneyStub.State.get_verification() do
          nil ->
            :ok

          verification ->
            decoded = Jason.decode!(body)
            verification.(decoded)
        end

        {:ok, 200, [], "capture"}
      end

      def body("decide") do
        {:ok, json_fixture!(unquote(fixture))}
      end

      def body("capture") do
        {:ok, "{}"}
      end

      defp json_fixture!(fixture) do
        @fixtures_dir
        |> Path.join(fixture)
        |> File.read!()
      end

      def verify_capture(verification) do
        HackneyStub.State.set_verification(verification)
      end
    end
  end
end

defmodule HackneyStub do
  use HackneyStub.Base, "decide.json"
end

defmodule HackneyStubV3 do
  use HackneyStub.Base, "decide-v3.json"
end
