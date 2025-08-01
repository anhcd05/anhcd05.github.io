#!/usr/bin/env ruby
# frozen_string_literal: true

require "jekyll"
require "pathname"
require "open3"

Jekyll::Hooks.register :posts, :post_init do |post|
  # 1. Tính đường dẫn tương đối từ repo root
  repo_root = Pathname.new(Dir.pwd)
  rel_path  = Pathname
                  .new(post.path)
                  .relative_path_from(repo_root)
                  .to_s
                  .tr("\\", "/")  # đảm bảo dùng slash

  # 2. Đếm commit qua Open3.capture2 (trả về [stdout, status])
  commit_num, _status = Open3.capture2(
    "git", "rev-list", "--count", "HEAD", rel_path
  )

  if commit_num.to_i > 1
    # 3. Lấy last modified date cũng qua capture2
    lastmod, _status2 = Open3.capture2(
      "git", "log", "-1", "--pretty=%ad", "--date=iso", rel_path
    )
    post.data["last_modified_at"] = lastmod.strip
  end
end
