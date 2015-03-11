# EventMachine::EmailServer::Maildir

This adds Maildir-based email storage to EventMachine::EmailServer.

## Installation

Add this line to your application's Gemfile:

    gem 'eventmachine-email_server-maildir'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eventmachine-email_server-maildir

## Usage


    require 'eventmachine'
    require 'eventmachine/email_server'
    require 'eventmachine/email_server/maildir'
    include EventMachine::EmailServer
    
    userstore = MemoryUserStore.new
    # add a user
    #  first argument is the user's id for the maildir => :user
    #  second argument is the user's login name
    #  third argument is the user's password
    #  forth argument is the email address that delivers mail to this user
    userstore << User.new("clee", "chris", "password", "chris@example.org")
    # :user will be replaced with the user's name
    # e.g, /var/spool/maildir/clee
    emailstore = MaildirEmailStore.new("/var/spool/maildir/:user")
    
    EM.run {
      pop3 = EventMachine::start_server "0.0.0.0", 2110, POP3Server, "example.org", userstore, emailstore
      smtp = EventMachine::start_server "0.0.0.0", 2025, SMTPServer, "example.org", userstore, emailstore
     }

## Contributing

1. Fork it ( https://github.com/[my-github-username]/eventmachine-email_server-maildir/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
