module Merit
  require 'ambry'
  require 'ambry/active_model'

  class Badge
    extend Ambry::Model
    extend Ambry::ActiveModel

    field :id, :name, :level, :description, :custom_fields

    validates_presence_of :id, :name
    validates_uniqueness_of :id

    filters do
      def find_by_id(ids)
        ids = Array.wrap(ids)
        find { |b| ids.include? b[:id] }
      end

      def by_name(name)
        find { |b| b.name.to_s == name.to_s }
      end

      def by_level(level)
        find { |b| b.level.to_s == level.to_s }
      end
    end

    def _mongoid_sash_in(sashes)
      {:sash_id.in => sashes}
    end

    def _active_record_sash_in(sashes)
      {sash_id: sashes}
    end

    # Custom mojjo methods
    def earned_on(user)
      Merit::BadgesSash.where(sash_id: user.sash_id, badge_id: self.id).first.try(:created_at)
    end

    def image
      ActionController::Base.helpers.asset_path("assets/badges/#{self.name}.png")
    end

    def value
      self.custom_fields[:value]
    end

    def unit 
      self.custom_fields[:unit]
    end

    def category
      self.custom_fields[:category]
    end

    def sub_category
      self.custom_fields[:sub_category]
    end

    def ressource 
      self.custom_fields[:ressource]
    end

    def points
      self.custom_fields[:points]
    end

    def title
      "#{self.id}-#{self.name}#{self.level}"
    end

    def min_matches
      self.custom_fields[:min_matches] || 0
    end

    def progress(user)
      res = self.custom_fields[:rule].call(user) if self.custom_fields[:rule].class == Proc
    end

    def grantable?(user)
      raise "No rule found for badge #{self.title}" unless self.custom_fields[:rule].class == Proc
      self.value ? self.progress(user) >= value : self.progress(user) == true
    end

    def locale_name
      I18n.t "badges.#{self.name}.name", default: self.name
    end

    def locale_description
      I18n.t "badges.#{self.name}.desc", default: self.description, value: self.value
    end

    def level_count
      badge = BADGES.select {|b| b[:name] == self.name}.first
      if badge[:levels]
        badge[:levels].count
      else
        1
      end
    end

    def json(user = nil, show_progress = false)
    {
        id: self.id,
        name: self.locale_name,
        key: self.name,
        title: self.title,
        level: self.level || 1,
        level_count: self.level_count,
        points: self.points,
        value: self.value,
        unit: self.unit,
        image: self.image,
        category: self.category,
        sub_category: self.sub_category,
        description: self.locale_description,
        progress: user && show_progress && self.level == 1 ? self.progress(user) : nil,
        earned_on: user ? self.earned_on(user) : nil
    }
    end

    class << self
      def find_by_name_and_level(name, level)
        badges = Merit::Badge.by_name(name)
        badges = badges.by_level(level) unless level.nil?
        if (badge = badges.first).nil?
          str = "No badge '#{name}' found. Define it in initializers/merit.rb"
          fail ::Merit::BadgeNotFound, str
        end
        badge
      end

      # Defines Badge#meritable_models method, to get related
      # entries with certain badge. For instance, Badge.find(3).users
      # orm-specified
      def _define_related_entries_method(meritable_class_name)
        define_method(:"#{meritable_class_name.underscore.pluralize}") do
          sashes = BadgesSash.where(badge_id: id).pluck(:sash_id)
          meritable_class_name.constantize.where(send "_#{Merit.orm}_sash_in", sashes)
        end
      end

      # Custom mojjo methods
      def seek(name, level = nil)
        self.find_by_name_and_level(name, level)
      end

      def by_ressource(ressource)
        self.select { |b| b.ressource == ressource }
      end

      def category(category, sub_category = nil)
        self.select do |b|
          if b.category != category
            false
          elsif !sub_category.nil? && b.sub_category != sub_category
            false
          else
            true
          end
        end
      end
    end
  end
end
