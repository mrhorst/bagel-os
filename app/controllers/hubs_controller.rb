# Group hub pages — entry points used by the mobile bottom tab bar.
# Each hub renders cards for the modules underneath it. On desktop these are
# still reachable URLs but the sidebar gives direct access; the hub is mostly
# a mobile affordance to keep the bottom bar to 5 tabs.
class HubsController < ApplicationController
  def shift;  end
  def stock;  end
  def buying; end
  def more;   end
end
