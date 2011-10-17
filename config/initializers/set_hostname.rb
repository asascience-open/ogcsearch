HOSTNAME="#{ActionMailer::Base.default_url_options[:host]}:#{ActionMailer::Base.default_url_options[:port].to_s}" rescue nil
