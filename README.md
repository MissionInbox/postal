![GitHub Header](https://github.com/postalserver/.github/assets/4765/7a63c35d-2f47-412f-a6b3-aebc92a55310)

**Postal** is a complete and fully featured mail server for use by websites & web servers. Think Sendgrid, Mailgun or Postmark but open source and ready for you to run on your own servers. 

## Getting Started With the Development

### 1. Clone the project
```
git clone https://github.com/missioninbox/postal
cd postal
git checkout dev
```

### 2. Install rvm and ruby
```
curl -sSL https://get.rvm.io | bash -s stable
rvm install "ruby-3.2.2"
```

### 3. Install local mysql-server
```
sudo apt install mysql-server
sudo mysql_secure_installation
sudo mysql
mysql> ALTER USER 'myuser'@'%' IDENTIFIED BY 'StrongPass123!';
mysql> create database postal;
```

### 4. Configure project console and check for validity
```
source ~/.rvm/scripts/rvm
which ruby
which gem
ruby -v
gem -v
```

If that works, make sure RVM loads by default when you open a shell. Usually you add this line to ~/.bashrc or ~/.zshrc:

```
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
```

### 5. Install project dependencies
```
gem install bundler
bundle install
```

If you face mysql gem installation issue, run the following.
```
sudo apt update

# 2) MySQL client headers (for mysql2)
sudo apt install -y build-essential pkg-config
sudo apt install -y default-libmysqlclient-dev

# Optional but often needed by other gems:
sudo apt install -y libssl-dev zlib1g-dev
```

Run `bundle install` again.

### 6. Install foreman
```
gem install foreman
```

### 7. Create postal configuration
```
mkdir config/postal
cp config/examples/development.yml config/postal/postal.yml
./bin/postal initialize
```

Update config/postal/postal.yml with your DB credential.

### 8. Run the dev script
```
./bin/dev
```

If you are having issues binding local 25 port to this project (with Access Denied error), update the port to 2525 on the `postal.yml` file with the following.
```
smtp_server:
  default_port: 2525
  max_connections: 1000
  connection_threads: 20
```

Use `./bin/postal --help` to see how to create the user using `postal` cli.


* [Documentation](https://docs.postalserver.io)
* [Installation Instructions](https://docs.postalserver.io/getting-started)
* [FAQs](https://docs.postalserver.io/welcome/faqs) & [Features](https://docs.postalserver.io/welcome/feature-list)
* [Discussions](https://github.com/postalserver/postal/discussions) - ask for help or request a feature
* [Join us on Discord](https://discord.postalserver.io)
