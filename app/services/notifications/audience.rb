module Notifications
  # Who should receive a push for a given module.
  #
  # Tasks and most records in Bagel OS are shared, not assigned to an
  # individual (CONTEXT.md), so "recipients" for a module notification is every
  # user who can open that module's screens (admins, plus holders of the module
  # permission) AND has at least one device subscribed to push. Users without a
  # subscription are filtered out in SQL so callers can iterate the result and
  # call `push_subscriptions.notify_all` without per-user guards.
  module Audience
    def self.for_module(module_name)
      module_name = module_name.to_s
      permitted = User.where(
        id: UserModulePermission.where(module_name: module_name).select(:user_id)
      )

      User
        .admin.or(permitted)
        .where(id: PushSubscription.select(:user_id))
        .distinct
    end
  end
end
