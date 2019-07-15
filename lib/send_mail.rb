# encoding: utf-8

module Bloodhound
  class SendMail

    def initialize
      Pony.options = {
        charset: 'UTF-8',
        from: 'no-reply@bloodhound-tracker.net',
        subject: subject
      }
    end

    def send_messages
      users = User.where.not(email: nil)
                  .where(wants_mail: true)
                  .where("mail_last_sent < ?", 6.days.ago)
      users.find_each do |user|
        articles = user_articles(user)
        if articles.count > 0
          Pony.mail(
            to: user.email,
            body: construct_message(user, articles)
          )
        end
        user.mail_last_sent = Time.now
        user.save
      end
    end

    def subject
      "Bloodhound :: New articles used your specimen data"
    end

    def salutation(fullname = "")
      "Dear #{fullname},\n\n"\
      "The following articles were recently discovered by the Global Biodiversity Information Facility (GBIF) as having used the data from specimens you collected or identified.\n\n"
    end

    def format_article(article)
      "#{article[:citation]} https://doi.org/#{article[:doi]}"
    end

    def closing
      "\n\nWe hope you enjoy using Bloodhound, https://bloodhound-tracker.net.\n"\
      "Your support is greatly appreciated, https://bloodhound-tracker.net/donate."\
      "\n\n\nIf you wish to stop receiving these messages, login to your account and adjust the settings in your profile."
    end

    private

    def user_articles(user)
      Article.joins(article_occurrences: :user_occurrences)
             .where(mail_sent: false)
             .where(user_occurrences: { user_id: user.id, visible: true })
             .distinct
             .pluck_to_hash(:doi, :citation)
    end

    def construct_message(user, articles)
      body  = salutation(user.fullname)
      body += articles.map{|a| format_article(a) }.join("\n\n")
      body += closing
      body
    end

  end
end