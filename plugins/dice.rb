class Dice
  require 'time-lord'
  include Cinch::Plugin

  cooldown
  self.help = "Roll a random assortment of dice with .dicebag, you can also use .roll (dice count)d(sides) to roll specific dice (e.g. '.roll 4d6 3d20')"

  class Score < Struct.new(:nick, :score, :time)
    def to_yaml
      { :nick => nick,
        :score => score,
        :time => time } 
    end
  end

  match /dicebag/, method: :roll_bag 
  match /roll (.*)/, method: :roll

  def initialize(*args)
    super
    @storage = Storage.new('yaml/dice.yml')
  end

  def roll_bag(m) 
    nick = m.user.nick.downcase
    dice = [rand(30), rand(25), rand(20)].map { |d| d.floor } 
    bag = "#{dice[0]}d6 #{dice[1]}d10 #{dice[2]}d20" 
    result = roll_dice(bag) 
    
    total = dice.inject(:+)
    if total < 10 && total > 0
      size = 'tiny'
    elsif total < 20 && total > 10 
      size = 'small'
    elsif total < 30 && total > 20
      size = 'medium'
    elsif total < 50 && total > 30
      size = 'large'
    elsif total < 60 && total > 50
      size = 'hefty' 
    else
      size = 'huge'
    end

    m.reply "#{m.user.nick} rolls a #{size} bag of dice totalling #{result[:total]}."

    channel = m.channel.name

    unless @storage.data.key?(channel)
      @storage.data[channel] = Hash.new 
    end

    unless @storage.data[channel].key?(nick) 
      @storage.data[channel][nick] = { :score => result[:total], :time => Time.now } 
    end   

    if @storage.data[channel][nick][:score] < result[:total]
      old = @storage.data[channel][nick]
      @storage.data[channel][nick] = { :score => result[:total], :time => Time.now }

      m.reply "This is a new high score, their old score was #{old[:score]}, #{old[:time].ago_in_words}."
    end 

    # Keep an eye on this and only do it on changes if it becomes a perf issue. 
    synchronize(:dice_save) do 
      @storage.save
    end
  end

  def roll(m, bag) 
    result = roll_dice(bag) 
    response = "#{result[:rolls].join(', ')} totalling #{result[:total]}"
    m.reply "#{m.user.nick} rolls #{response}" unless response.nil?
  end

  private 

  def roll_dice(dice)
    rolls = []
    total = 0 
    dice = dice.split(' ')
    dice.each do |die| 
      if die.match(/\d+d\d+/)
        count = die.match(/(\d+)d\d+/)[1].to_i rescue 0
        sides = die.match(/\d+d(\d+)/)[1].to_i rescue 0 
      elsif die.match(/d\d+/) 
        count = 1
        sides = die.match(/d(\d+)/)[1].to_i rescue 0
      end
      unless count.nil? || sides.nil? 
        roll = roll_dice_type(sides, count)
        unless roll.nil?
          rolls << roll[:text]
          total += roll[:total] 
        end
      end
    end
    return { :rolls => rolls, :total => total }
  end

  def roll_dice_type(sides, count) 
    unless sides < 1 || count < 1 
      rolls = []
      count.times { rolls << rand(sides) + 1 } 
      return {:total => rolls.inject(:+), 
              :text => "#{count}d#{sides}" }  
    end 
  end
end
