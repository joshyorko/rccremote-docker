As of February 21, 2026, this is a solid command flow:

  # 1) One-time toolchain
  brew update
  brew install mise openssl@3 libyaml gmp rust pkgconf git

  # 2) Enable mise in bash (restart shell after this)
  echo 'eval "$(mise activate bash)"' >> ~/.bashrc
  source ~/.bashrc
  mise doctor

  # 3) Install Ruby (project-friendly version manager approach)
  mise use -g ruby@3.4
  ruby -v

  # 4) Install Rails + Kamal
  gem update --system
  gem install rails -v 8.1.2
  gem install kamal
  rails -v
  kamal version

  Then create your app:

  rails _8.1.2_ new rails-rccremote --database=sqlite3 --css=tailwind
  cd rails-rccremote
  bin/rails generate authentication
  bin/rails db:create db:migrate
  bin/rails server

  Then Kamal + Let’s Encrypt setup:

  bin/kamal init

  In config/deploy.yml, set at least:

  proxy:
    ssl: true
  Then:

  export KAMAL_REGISTRY_PASSWORD='your-token'
  cat > .kamal/secrets <<'EOF'
  KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD
  RAILS_MASTER_KEY=$(cat config/master.key)
  EOF

  bin/kamal setup
  bin/kamal deploy

  Important: auto Let’s Encrypt in Kamal requires a host configured and reachable; keep ports 80 and 443 open, and DNS pointed to your server.

  If you want, next I can give you a ready-to-paste config/deploy.yml for single-server rails-rccremote.

  Sources:

  - https://guides.rubyonrails.org/install_ruby_on_rails.html
  - https://guides.rubyonrails.org/getting_started.html
  - https://guides.rubyonrails.org/security.html
  - https://kamal-deploy.org/docs/installation/
  - https://kamal-deploy.org/docs/configuration/proxy/
  - https://formulae.brew.sh/formula/mise
  - https://rubygems.org/gems/rails/versions/8.1.2