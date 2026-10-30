# _plugins/cjk_linebreak.rb
Jekyll::Hooks.register [:posts, :pages], :pre_render do |doc|
  doc.content = doc.content.gsub(/([\p{Han}，。！？、；：“”‘’（）])[ \t]*\n[ \t]*([\p{Han}，。！？、；：“”‘’（）])/, '\1\2')
end
