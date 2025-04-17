defmodule HackneyStub.Base do
  @fixtures_dir Path.join(__DIR__, "fixtures")

  defmacro __using__(fixture) do
    quote do
      @fixtures_dir unquote(@fixtures_dir)

      def post("https://us.posthog.com/decide?v=3", _headers, _body, _opts) do
        {:ok, 200, json_fixture!(unquote(fixture)), "decide"}
      end

      def post("https://us.posthog.com/capture", _headers, body, _opts) do
        IO.puts("Capture called with body: #{inspect(body)}")
        case Process.get(:capture_verification) do
          nil ->
            IO.puts("No verification set")
            :ok
          verification ->
            IO.puts("Running verification")
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
        Process.put(:capture_verification, verification)
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
