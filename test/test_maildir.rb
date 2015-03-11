# coding: utf-8

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'helper'
require 'eventmachine'
require 'eventmachine/email_server'
require 'net/pop'
require 'net/smtp'
require 'fileutils'
include EventMachine::EmailServer

class EmailTemplate < Struct.new(:from, :to, :msg); end

class TestEmailServer < Minitest::Test
  def setup
    @test_vector = Proc.new { |test_name|
      puts "***** #{test_name} *****"
      (test_name.to_s =~ /maildir/)
    }
    @spam_email = EmailTemplate.new("friend@example.org", "chris@example.org", "From: friend@example.org
To: chris@example.org
Subject: What to do when you're not doing.

Could I interest you in some cialis?
")
    @ham_email = EmailTemplate.new("friend@example.org", "chris@example.org", "From: friend@example.org
To: chris@example.org
Subject: Good show

Have you seen the latest Peppa Pig?
")
    @default_email = EmailTemplate.new("friend@example.org", "chris@example.org", "From: friend@example.org
To: chris@example.org
Subject: Can't remember last night

Looks like we had fun!
")
    @pool = EM::Pool.new
    SMTPServer.reset
    remove_scraps
    create_test_maildir
  end

  def remove_scraps
    FileUtils.remove_dir("test/users", true)
  end

  def teardown
    remove_scraps
  end
  
  def create_test_maildir
    FileUtils.mkdir_p("test/users/chris")
  end

  def setup_user(userstore)
    userstore << User.new("chris", "chris", "chris", "chris@example.org")
  end

  def start_servers(userstore, emailstore)
    pop3 = EventMachine::start_server "0.0.0.0", 2110, POP3Server, "example.org", userstore, emailstore
    smtp = EventMachine::start_server "0.0.0.0", 2025, SMTPServer, "example.org", userstore, emailstore
  end


  def send_email(email=@default_email, &callback)
    smtp_dispatcher = EventMachine::ThreadedResource.new do
      smtp = Net::SMTP.new('localhost', 2025)
    end

    @pool.add smtp_dispatcher

    @pool.perform do |dispatcher|
      completion = dispatcher.dispatch do |smtp|
        ret = nil
        smtp.start do |s|
          begin
            ret = s.send_message email.msg, email.from, email.to
          rescue => e
            ret = "451"
          end
          begin
            smtp.quit
          rescue => e
          end
        end
        if ret.respond_to? :status
          ret = ret.status
        end
        ret
      end

      completion.callback do |result|
        callback.call(result)
      end

      completion
    end
  end

  def pop_email(&callback)

    pop3_dispatcher = EventMachine::ThreadedResource.new do
    end

    @pool.add pop3_dispatcher

    @pool.perform do |dispatcher|
      completion = dispatcher.dispatch do |pop|
        pop = Net::POP3.APOP(true).new('localhost',2110)
        pop.start("chris","chris")
        answers = Array.new
        answers << pop.mails.empty?
        if not pop.mails.empty?
          pop.each_mail do |m|
            answers << m.mail
            m.delete
          end
        end
        pop.finish
        answers
      end

      completion.callback do |answers|
        callback.call(answers)
      end

      completion
    end
  end

  def run_test(userstore, emailstore)
    EM.run {
      start_servers(userstore, emailstore)
      EM::Timer.new(10) do
        fail "Test timed out"
        EM.stop
      end
      EM::Timer.new(0.1) do
        pop_email do |answers|
          assert_equal(true, answers[0])
          send_email do |result|
            assert_equal("250", result)
            pop_email do |answers|
              assert_equal(false, answers[0])
              assert_equal(@default_email.msg.gsub(/[\r\n]+/,"\n"), answers[1].gsub(/[\r\n]+/,"\n"))
              pop_email do |answers|
                assert_equal(true, answers[0])
                EM.stop
              end
            end
          end
        end
      end
    }
  end

  def test_maildir_store
    return unless @test_vector.call(__method__)
    userstore = MemoryUserStore.new
    emailstore = MaildirEmailStore.new("test/users/:user")
    setup_user(userstore)
    run_test(userstore, emailstore)
  end
end