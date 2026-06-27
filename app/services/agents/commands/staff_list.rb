module Agents
  module Commands
    # The people a task completion can be attributed to. An agent reads this to
    # resolve "complete as Maria" into the right user for tasks:complete.
    class StaffList < Command
      command "staff:list"
      summary "Users a task completion can be attributed to"

      def call
        users = User.order(:name, :email_address)

        {
          count: users.size,
          staff: users.map { |user| staff_json(user) }
        }
      end

      private

      def staff_json(user)
        {
          id: user.id,
          name: user.name.presence,
          email: user.email_address,
          role: user.role
        }
      end
    end
  end
end
