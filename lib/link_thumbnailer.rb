require 'link_thumbnailer/engine' if defined? Rails
require 'link_thumbnailer/config'
require 'link_thumbnailer/object'
require 'link_thumbnailer/fetcher'
require 'link_thumbnailer/doc_parser'
require 'link_thumbnailer/doc'
require 'link_thumbnailer/img_url_filter'
require 'link_thumbnailer/img_parser'
require 'link_thumbnailer/img_comparator'
require 'link_thumbnailer/web_image'
require 'link_thumbnailer/opengraph'
require 'link_thumbnailer/version'

module LinkThumbnailer

  module Rails
    autoload :Routes, 'link_thumbnailer/rails/routes'
  end

  class << self

    attr_accessor :configuration, :object, :fetcher, :doc_parser,
                  :img_url_filters, :img_parser

    def config
      self.configuration ||= Configuration.new(
        :mandatory_attributes => %w(url title images),
        :strict               => true,
        :redirect_limit       => 3,
        :blacklist_urls       => [
          %r{^http://ad\.doubleclick\.net/},
          %r{^http://b\.scorecardresearch\.com/},
          %r{^http://pixel\.quantserve\.com/},
          %r{^http://s7\.addthis\.com/}
        ],
        :rmagick_attributes   => %w(source_url mime_type colums rows filesize number_colors),
        :limit                => 10,
        :top                  => 5
      )
    end

    def configure
      yield config
    end

    def generate(url, options = {})
      set_options(options)
      instantiate_classes

      doc = self.doc_parser.parse(self.fetcher.fetch(url), url)

      self.object[:url] = doc.source_url
      opengraph(doc) || custom(doc)
    end

    private

    def set_options(options)
      LinkThumbnailer.configure {|config|
        config.mandatory_attributes = options[:mandatory_attributes]  if options[:mandatory_attributes]
        config.strict               = options[:strict]                if options[:strict]
        config.redirect_limit       = options[:redirect_limit].to_i   if options[:redirect_limit]
        config.blacklist_urls       = options[:blacklist_urls]        if options[:blacklist_urls]
        config.rmagick_attributes   = options[:rmagick_attributes]    if options[:rmagick_attributes]
        config.limit                = options[:limit].to_i            if options[:limit]
        config.top                  = options[:top].to_i              if options[:top]
      }
    end

    def instantiate_classes
      self.object           = LinkThumbnailer::Object.new
      self.fetcher          = LinkThumbnailer::Fetcher.new
      self.doc_parser       = LinkThumbnailer::DocParser.new
      self.img_url_filters  = [LinkThumbnailer::ImgUrlFilter.new]
      self.img_parser       = LinkThumbnailer::ImgParser.new(self.fetcher, self.img_url_filters)
    end

    def opengraph(doc)
      self.object = LinkThumbnailer::Opengraph.parse(self.object, doc)
      return self.object if self.object.valid?
      nil
    end

    def custom(doc)
      self.object[:title] = doc.title
      self.object[:description] = doc.description
      self.object[:images] = self.img_parser.parse(doc.img_abs_urls.dup)
      return self.object if self.object.valid?
      nil
    end

  end

end
