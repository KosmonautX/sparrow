defmodule H2WorkerTest do
  use ExUnit.Case
  use Quixir
  import Mock
  import ExUnit.CaptureLog
  require Logger
  alias Sparrow.H2Worker.Config, as: Config
  alias Sparrow.H2ClientAdapter.Chatterbox, as: H2Adapter
  alias Sparrow.H2Worker.Request, as: OuterRequest
  alias Sparrow.H2Worker.State, as: State

  @repeats 10

  defp pid(string) when is_binary(string) do
    :erlang.list_to_pid('<#{string}>')
  end

  defp child_spec(opts) do
    args = opts[:args]
    name = opts[:name]

    id = :rand.uniform(100_000)

    %{
      :id => id,
      :start => {Sparrow.H2Worker, :start_link, [name, args]}
    }
  end

  test "server timeouts request" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: args, name: name)
        {:ok, pid} = start_supervised(spec)

        request = OuterRequest.new(headers, body, path, request_timeout)
        assert {:error, :request_timeout} == GenServer.call(pid, {:send_request, request})
      end
    end
  end

  test "server receives request and returns answer" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        get_reponse: fn _, _ ->
          {:ok, {headers, body}}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, pid} = start_supervised(spec)

        :erlang.send_after(150, pid, {'END_STREAM', stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)
        assert {:ok, {headers, body}} == GenServer.call(pid, {:send_request, request})
      end
    end
  end

  test "server receives request and returns answer posts gets error and errorcode" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            code: int(min: 0, max: 1000),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:error, code}
        end,
        get_reponse: fn _, _ ->
          {{:ok, {headers, body}}}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, pid} = start_supervised(spec)

        :erlang.send_after(150, pid, {'END_STREAM', stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)
        assert {:error, code} == GenServer.call(pid, {:send_request, request})
      end
    end
  end

  test "server receives request and expexts answer but get response returns not_ready" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        get_reponse: fn _, _ ->
          {:error, :not_ready}
        end,
        close: fn _ -> :ok end do
        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, pid} = start_supervised(spec)

        :erlang.send_after(150, pid, {'END_STREAM', stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)
        assert {:error, :not_ready} == GenServer.call(pid, {:send_request, request})
      end
    end
  end

  test "server receives request as cast but does not return answer" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 100
      request_timeout = 300
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end do
        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: config, name: name)
        {:ok, pid} = start_supervised(spec)

        :erlang.send_after(150, pid, {'END_STREAM', stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)
        GenServer.cast(pid, {:send_request, request})
        state = :sys.get_state(pid)
        inner_request = Map.get(state.requests, stream_id)
        assert headers == inner_request.headers
        assert body == inner_request.body
        assert path == inner_request.path
      end
    end
  end

  test "END_STREAM received but request but cannot be found it in state" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ping_interval = 200

      config =
        Config.new(
          domain,
          port,
          tls_options,
          ping_interval
        )

      state = State.new(connection_ref, config)

      assert {:noreply, state} == Sparrow.H2Worker.handle_info({'END_STREAM', stream_id}, state)
    end
  end

  test "unexpected message received but request but cannot be found it in state" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            random_message: string(min: 10, max: 20, chars: ?a..?z)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ping_interval = 200

      config =
        Config.new(
          domain,
          port,
          tls_options,
          ping_interval
        )

      state = State.new(connection_ref, config)

      assert {:noreply, state} == Sparrow.H2Worker.handle_info(random_message, state)
    end
  end

  test "server cancel timeout on older request" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            body: string(min: 3, max: 15, chars: :ascii),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 1_000
      request_timeout = 200
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end,
        get_reponse: fn _, _ ->
          {:ok, {headers, body}}
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: args, name: name)
        {:ok, pid} = start_supervised(spec)

        :erlang.send_after(150, pid, {'END_STREAM', stream_id})
        :erlang.send_after(300, pid, {'END_STREAM', stream_id})
        request = OuterRequest.new(headers, body, path, request_timeout)
        assert {:ok, {headers, body}} == GenServer.call(pid, {:send_request, request})
        assert {:ok, {headers, body}} == GenServer.call(pid, {:send_request, request})
        assert {:error, :request_timeout} == GenServer.call(pid, {:send_request, request})
      end
    end
  end

  test "server correctly starting with succesfull connection and scheduales and runs pinging" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            name: atom(min: 5, max: 20),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ponger = pid("0.456.654")
      ping_interval = 100

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        ping: fn _ ->
          send(self(), {:PONG, ponger})
          :ok
        end,
        close: fn _ -> :ok end do
        args =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        spec = child_spec(args: args, name: name)
        {:ok, pid} = start_supervised(spec)
        :erlang.trace(pid, true, [:receive])

        :timer.sleep(ping_interval * 2)
        assert called H2Adapter.ping(connection_ref)

        assert_receive {:trace, ^pid, :receive, {:PONG, _}}
      end
    end
  end

  test "request is added to state" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            body: string(min: 3, max: 15, chars: :ascii),
            headersA: list(of: string(), min: 2, max: 2, chars: :ascii),
            headersB: list(of: string(), min: 2, max: 2, chars: :ascii),
            port: int(min: 0, max: 65535),
            path: string(min: 3, max: 15, chars: :ascii),
            stream_id: int(min: 1, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ping_interval = 100
      request_timeout = 1_000
      headers = List.zip([headersA, headersB])

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end,
        post: fn _, _, _, _, _ ->
          {:ok, stream_id}
        end do
        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        outer_request = OuterRequest.new(headers, body, path, request_timeout)

        {:noreply, newstate} =
          Sparrow.H2Worker.handle_call(
            {:send_request, outer_request},
            {self(), make_ref()},
            Sparrow.H2Worker.State.new(
              connection_ref,
              config
            )
          )

        assert connection_ref == newstate.connection_ref
        assert config == newstate.config
        assert 1 == Enum.count(newstate.requests)
        assert [stream_id] == Map.keys(newstate.requests)
      end
    end
  end

  test "inits, succesfull connection" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      connection_ref = pid("0.45.54")
      ping_interval = 123

      with_mock H2Adapter,
        open: fn _, _, _ -> {:ok, connection_ref} end do
        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        assert {:ok, Sparrow.H2Worker.State.new(connection_ref, config)} ==
                 Sparrow.H2Worker.init(config)
      end
    end
  end

  test "inits, unsuccesfull connection" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65535),
            reason: atom(min: 2, max: 5),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      ping_interval = 123

      with_mock H2Adapter,
        open: fn _, _, _ -> {:error, reason} end do
        args =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        assert {:stop, reason} == Sparrow.H2Worker.init(args)
      end
    end
  end

  test "terminate closes connection" do
    ptest [
            domain: string(min: 3, max: 10, chars: ?a..?z),
            port: int(min: 0, max: 65535),
            tls_options: list(of: atom(), min: 0, max: 3)
          ],
          repeat_for: @repeats do
      with_mock H2Adapter,
        close: fn _ -> :ok end do
        connection_ref = pid("0.45.54")
        reason = "test reason"
        ping_interval = 123

        config =
          Config.new(
            domain,
            port,
            tls_options,
            ping_interval
          )

        state = Sparrow.H2Worker.State.new(connection_ref, config)
        assert :ok == Sparrow.H2Worker.terminate(reason, state)
        assert called H2Adapter.close(connection_ref)
      end
    end
  end
end
