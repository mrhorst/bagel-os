module AgentCliTestHelper
  # Run the CLI with captured streams. Returns [exit_status, parsed_stdout,
  # parsed_stderr] (parsed values are nil when the stream was empty).
  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Agents::Cli.run(argv, out: out, err: err)
    [ status, JSON.parse(out.string.presence || "null"), JSON.parse(err.string.presence || "null") ]
  end

  # Authenticate the CLI as `user` by minting a real session token and exposing
  # it via the env var the CredentialStore reads — no credentials file touched.
  def authenticate_agent!(user)
    session = Session.create!(user: user, user_agent: "test-cli", ip_address: "127.0.0.1")
    ENV["BAGEL_AGENT_TOKEN"] = Agents::Authentication.token_for(session)
    session
  end

  def deauthenticate_agent!
    ENV.delete("BAGEL_AGENT_TOKEN")
  end
end
