require "eventmachine/email_server/maildir/version"
require 'eventmachine/email_server/base'
require 'maildir'

module EventMachine
  module EmailServer
    class MaildirEmailStore < AbstractEmailStore
      def initialize(maildir_path = "/home/:user/Maildir")
        @maildir_path = maildir_path
        @user_maildirs = Hash.new
      end
      
      def get_maildir(id)
        if @user_maildirs[id].nil?
          user_maildir_path = @maildir_path.gsub(/:user/, id)
          puts user_maildir_path
          @user_maildirs[id] = ::Maildir.new(user_maildir_path)
        end
        @user_maildirs[id]
      end
        
      
      def emails_by_userid(id)
        maildir = get_maildir(id)
        messages = @user_maildirs[id].list(:new)
        # convert into EventMachine::EmailServer::Email, place each message as the subject?
        m = Array.new
        counter = -1
        messages = @user_maildirs[id].list(:new).map do |message|
          # :id,:from,:to,:subject,:body,:uid,:marked
          counter += 1
          EventMachine::EmailServer::Email.new(counter, nil, nil, message.key, message.data, id, 'false')
        end
        messages
      end
      
      def save_email(email)
        maildir = get_maildir(email.uid)
        message = maildir.add(email.body)
        message
      end
      
      def <<(email)
        save_email(email)
      end
      
      def delete_email(email)
        key = email.subject
        maildir = get_maildir(email.uid)
        message = maildir.get(key)
        message.destroy
      end
      
      def -(email)
        delete_email(email)
      end

      def delete_id(id)
        raise "Unsupported in #{self.class}"
      end
      
      def delete_user(uid)
        maildir = get_maildir(email.uid)
        @user_maildirs[id].list(:new).map do |message|
          message.destroy
        end
      end
      
      def count
        raise "Unimplemented in #{self.class}"
      end
      
    end
  end
end
