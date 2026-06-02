namespace :admin do
  desc "Create an admin user, promoting them to owner when no owner exists"
  task create: :environment do
    email = ENV.fetch("EMAIL", nil).to_s.strip.downcase
    name = ENV.fetch("NAME", nil).to_s.strip.presence
    password = ENV.fetch("PASSWORD", nil).to_s

    abort "Usage: bin/rails admin:create EMAIL=owner@example.com PASSWORD='long-password' [NAME='Owner Name']" if email.blank?
    abort "PASSWORD must be at least 8 characters." if password.length < 8

    user = User.find_or_initialize_by(email_address: email)
    creating = user.new_record?
    first_owner = !User.where(owner: true).exists?

    user.name = name if name.present?
    user.password = password
    user.password_confirmation = password
    user.role = :admin
    user.owner = true if first_owner
    user.save!

    action = creating ? "Created" : "Updated"
    ownership = user.owner? ? "owner admin" : "admin"
    puts "#{action} #{ownership}: #{user.email_address}"
  end
end
