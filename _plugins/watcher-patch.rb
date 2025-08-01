# frozen_string_literal: true

require "jekyll-watch"

module Jekyll
  module Watcher
    extend self

    # Giữ lại method gốc
    alias_method :original_listen_ignore_paths, :listen_ignore_paths

    # Override để thêm ignore pattern cho .TMP
    def listen_ignore_paths(options)
      original_listen_ignore_paths(options) + [%r!\.TMP\z!]
    end
  end
end
