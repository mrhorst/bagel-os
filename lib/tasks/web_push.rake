namespace :web_push do
  desc "Generate a VAPID key pair for Web Push (store in credentials or ENV — never commit the private key)"
  task generate_keys: :environment do
    keys = WebPush.generate_key

    puts <<~MSG
      Generated a VAPID key pair. Add it to credentials (bin/rails credentials:edit)
      or export it as environment variables. The private key is a secret.

      # config/credentials.yml.enc
      web_push:
        public_key: #{keys.public_key}
        private_key: #{keys.private_key}

      # or shell environment
      export VAPID_PUBLIC_KEY=#{keys.public_key}
      export VAPID_PRIVATE_KEY=#{keys.private_key}
    MSG
  end
end
