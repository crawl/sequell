module Henzell
  module Server
    class MorgueBinarySearch
      def self.search(path, game)
        require 'httplist'
        self.new(path, game).search
      end

      attr_reader :path, :game

      def initialize(path, game)
        @path = path
        @game = game
      end

      def player_name
        @game['name']
      end

      def user_url
        @user_url ||= path + "/" + player_name + "/"
      end

      def time
        @time ||= morgue_time(@game)
      end

      def short_time
        @short_time ||= self.time.sub(/\d{2}$/, '')
      end

      def full_morgue_name
        @full_morgue_name ||= "morgue-#{self.player_name}-#{time}.txt"
      end

      def short_morgue_name
        @short_morgue_name ||= "morgue-#{self.player_name}-#{short_time}.txt"
      end

      def morgues
        @morgues ||=
          HttpList::find_files(user_url, /morgue-#{player_name}.*?[.]txt/,
                               DateTime.strptime(time, MORGUE_DATEFORMAT))
      end

      def search
        morgue = morgues.find { |m| m == self.full_morgue_name } ||
                 morgues.find { |m| m == self.short_morgue_name } ||
                 binary_search(morgues, self.full_morgue_name)
        morgue.url if morgue
      end

    private
      def binary_search(morgues, name)
        size = morgues.size
        if size == 1
          return what < morgues[0] ? morgues[0] : nil
        end
        s = 0
        e = size
        while e - s > 1
          pivot = (s + e) / 2
          if morgues[pivot] == what
            return morgues[pivot]
          elsif morgues[pivot] < what
            s = pivot
          else
            e = pivot
          end
        end
        e < size ? morgues[e] : nil
      end
    end
  end
end
