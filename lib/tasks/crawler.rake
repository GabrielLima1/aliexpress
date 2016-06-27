namespace :crawler do
  desc "Runs Crawler.rb"
  task run: :environment do
    orders = @crawler.wordpress.get_orders
    @crawler.run orders.first(3)
    binding.pry
  end

  desc "Runs every 10 minutes"
  task tenminutes: :environment do
    @crawler = Crawler.where(schedule: 'ten_minutes',enabled: true).last
    unless @crawler.nil?
      Rake::Task['crawler:run'].execute
    end
  end

  desc "Runs every hour"
  task hourly: :environment do
    @crawler = Crawler.where(schedule: 'hourly',enabled: true).last
    unless @crawler.nil?
      Rake::Task['crawler:run'].execute
    end
  end

  desc "Runs every day"
  task daily: :environment do
    @crawler = Crawler.where(schedule: 'daily',enabled: true).last
    unless @crawler.nil?
      Rake::Task['crawler:run'].execute
    end
  end
end
