module AgentCli
  # bin/bagel follow-ups <action> — open issues raised by staff or by the
  # log book. Resolution/reopen go through the FollowUp model helpers so the
  # audit fields (resolved_by, resolved_at, resolved_via) stay consistent
  # with the web flow.
  class FollowUpsCommand < BaseCommand
    def self.actions
      {
        "list" => :list,
        "show" => :show,
        "create" => :create,
        "update" => :update,
        "resolve" => :resolve,
        "reopen" => :reopen,
        "note" => :note
      }
    end

    def usage
      <<~USAGE
        Usage: bin/bagel follow-ups <action> [options]

        Actions:
          list      [--status open|resolved|all] [--limit N]
          show      ID
          create    --title TITLE [--description TEXT] [--urgency LEVEL]
                    [--assign EMAIL] [--user EMAIL]
          update    ID [--title TITLE] [--description TEXT] [--urgency LEVEL]
                    [--assign EMAIL | --unassign]
          resolve   ID [--via KIND] [--note TEXT] [--user EMAIL]
          reopen    ID [--user EMAIL]
          note      ID --body TEXT [--user EMAIL]

        LEVEL is one of: #{FollowUp::URGENCIES.join(', ')}.
        KIND is one of: #{FollowUp::RESOLUTION_KINDS.join(', ')} (default: action_taken).
        --user attributes the action to an existing user by email.
      USAGE
    end

    def list(argv)
      options = { status: "open", limit: 100 }
      parse_options(argv, "Usage: bin/bagel follow-ups list [options]") do |opts|
        opts.on("--status STATUS", "open | resolved | all (default: open)") do |value|
          options[:status] = require_inclusion!(value, FollowUp::STATUSES + %w[all], "--status")
        end
        opts.on("--limit N", Integer, "Max rows to return (default: 100)") { |value| options[:limit] = value }
      end

      scope = FollowUp.includes(:opened_by, :assigned_to, :resolved_by)
      scope = scope.where(status: options[:status]) unless options[:status] == "all"
      scope = options[:status] == "open" ? scope.by_urgency : scope.recent_first

      follow_ups = scope.limit(options[:limit])
      { count: follow_ups.size, follow_ups: follow_ups.map { |f| Serializers.follow_up(f) } }
    end

    def show(argv)
      parse_options(argv, "Usage: bin/bagel follow-ups show ID")
      follow_up = FollowUp.find(require_id!(argv, "bin/bagel follow-ups show ID"))
      { follow_up: Serializers.follow_up(follow_up, include_details: true) }
    end

    def create(argv)
      attrs = {}
      user = nil
      parse_options(argv, "Usage: bin/bagel follow-ups create --title TITLE [options]") do |opts|
        opts.on("--title TITLE", "Follow-up title") { |value| attrs[:title] = value }
        opts.on("--description TEXT", "What was observed") { |value| attrs[:description] = value }
        opts.on("--urgency LEVEL", "normal | important | urgent") do |value|
          attrs[:urgency] = require_inclusion!(value, FollowUp::URGENCIES, "--urgency")
        end
        opts.on("--assign EMAIL", "Assign to a user by email") { |value| attrs[:assigned_to] = find_user!(value) }
        opts.on("--user EMAIL", "Who is opening this follow-up") { |value| user = find_user!(value) }
      end
      raise Error, "--title is required." if attrs[:title].blank?

      follow_up = FollowUp.create!(
        status: "open",
        urgency: "normal",
        opened_at: Time.current,
        opened_by: user,
        **attrs
      )
      { follow_up: Serializers.follow_up(follow_up, include_details: true) }
    end

    def update(argv)
      attrs = {}
      parse_options(argv, "Usage: bin/bagel follow-ups update ID [options]") do |opts|
        opts.on("--title TITLE", "New title") { |value| attrs[:title] = value }
        opts.on("--description TEXT", "New description") { |value| attrs[:description] = value }
        opts.on("--urgency LEVEL", "normal | important | urgent") do |value|
          attrs[:urgency] = require_inclusion!(value, FollowUp::URGENCIES, "--urgency")
        end
        opts.on("--assign EMAIL", "Assign to a user by email") { |value| attrs[:assigned_to] = find_user!(value) }
        opts.on("--unassign", "Clear the assignment") { attrs[:assigned_to] = nil }
      end
      follow_up = FollowUp.find(require_id!(argv, "bin/bagel follow-ups update ID [options]"))
      raise Error, "Nothing to update — pass at least one option." if attrs.empty?

      follow_up.update!(attrs)
      { follow_up: Serializers.follow_up(follow_up, include_details: true) }
    end

    def resolve(argv)
      options = { via: "action_taken" }
      parse_options(argv, "Usage: bin/bagel follow-ups resolve ID [options]") do |opts|
        opts.on("--via KIND", "How it was resolved (default: action_taken)") do |value|
          options[:via] = require_inclusion!(value, FollowUp::RESOLUTION_KINDS, "--via")
        end
        opts.on("--note TEXT", "Resolution note") { |value| options[:note] = value }
        opts.on("--user EMAIL", "Who resolved it") { |value| options[:user] = find_user!(value) }
      end
      follow_up = FollowUp.find(require_id!(argv, "bin/bagel follow-ups resolve ID [options]"))
      raise Error, "Follow-up ##{follow_up.id} is already resolved." if follow_up.resolved?

      follow_up.resolve!(user: options[:user], note: options[:note], via: options[:via])
      { follow_up: Serializers.follow_up(follow_up, include_details: true) }
    end

    def reopen(argv)
      options = {}
      parse_options(argv, "Usage: bin/bagel follow-ups reopen ID [--user EMAIL]") do |opts|
        opts.on("--user EMAIL", "Who reopened it") { |value| options[:user] = find_user!(value) }
      end
      follow_up = FollowUp.find(require_id!(argv, "bin/bagel follow-ups reopen ID"))
      raise Error, "Follow-up ##{follow_up.id} is already open." if follow_up.open?

      follow_up.reopen!(user: options[:user])
      { follow_up: Serializers.follow_up(follow_up, include_details: true) }
    end

    def note(argv)
      options = {}
      parse_options(argv, "Usage: bin/bagel follow-ups note ID --body TEXT [--user EMAIL]") do |opts|
        opts.on("--body TEXT", "Note body") { |value| options[:body] = value }
        opts.on("--user EMAIL", "Note author") { |value| options[:user] = find_user!(value) }
      end
      follow_up = FollowUp.find(require_id!(argv, "bin/bagel follow-ups note ID --body TEXT"))
      raise Error, "--body is required." if options[:body].blank?

      follow_up.notes.create!(body: options[:body], author: options[:user])
      { follow_up: Serializers.follow_up(follow_up.reload, include_details: true) }
    end
  end
end
