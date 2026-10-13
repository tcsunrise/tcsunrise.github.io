#!/usr/bin/env ruby
#
# Show tags with display names from _data/tag_names.yml,
# while front matter and URLs keep using the original (English) tags.

module TagDisplayName
  def self.lookup(site, tag)
    names = site.data['tag_names'] || {}
    names[tag.to_s] || tag
  end

  # Liquid filter: {{ tag | tag_name }}
  module Filter
    def tag_name(tag)
      TagDisplayName.lookup(@context.registers[:site], tag)
    end

    # Liquid filter: {{ post.tags | tag_names }}
    def tag_names(tags)
      Array(tags).map { |tag| tag_name(tag) }
    end
  end

  # page.title of tag archive pages (heading, breadcrumb, <title>)
  module ArchiveTitle
    def title
      raw = @obj.title
      @obj.type == 'tag' ? TagDisplayName.lookup(@obj.site, raw) : raw
    end
  end
end

Liquid::Template.register_filter(TagDisplayName::Filter)

Jekyll::Hooks.register :site, :post_read do
  if defined?(Jekyll::Archives::PageDrop) && !(Jekyll::Archives::PageDrop < TagDisplayName::ArchiveTitle)
    Jekyll::Archives::PageDrop.prepend(TagDisplayName::ArchiveTitle)
  end
end
