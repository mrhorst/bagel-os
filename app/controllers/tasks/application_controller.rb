module Tasks
  class ApplicationController < ::ApplicationController
    require_module_access :tasks
  end
end
