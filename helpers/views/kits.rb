def updated_at_stamp(t)
  return 'Unknown' unless t
  Time.at(t).strftime("%d/%m/%Y at %H:%M:%S")
end

def shrink_svg(svg)
  md = svg.match('width="(.*)px" height="(.*)px" ')

  if md
    width = md[1]
    height = md[2]

    svg = "#{md.pre_match} width=\"#{width.to_f / 2}px\" height=\"#{height.to_f / 2}px\" #{md.post_match}"
  end


  svg
end
