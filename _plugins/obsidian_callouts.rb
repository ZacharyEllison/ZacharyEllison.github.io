require "cgi"

module ObsidianCallouts
  CALLOUT_TYPES = {
    "abstract" => { label: "Abstract", icon: "A" },
    "bug" => { label: "Bug", icon: "!" },
    "danger" => { label: "Danger", icon: "!" },
    "example" => { label: "Example", icon: "E" },
    "failure" => { label: "Failure", icon: "X" },
    "info" => { label: "Info", icon: "i" },
    "note" => { label: "Note", icon: "i" },
    "question" => { label: "Question", icon: "?" },
    "quote" => { label: "Quote", icon: '"' },
    "success" => { label: "Success", icon: "+" },
    "tip" => { label: "Tip", icon: "+" },
    "todo" => { label: "Todo", icon: "*" },
    "warning" => { label: "Warning", icon: "!" },
  }.freeze

  CALLOUT_ALIASES = {
    "attention" => "warning",
    "caution" => "warning",
    "check" => "success",
    "cite" => "quote",
    "done" => "success",
    "error" => "danger",
    "fail" => "failure",
    "faq" => "question",
    "help" => "question",
    "hint" => "tip",
    "important" => "tip",
    "missing" => "failure",
    "summary" => "abstract",
    "tldr" => "abstract",
  }.freeze

  CALLOUT_START = /^ {0,3}>[ \t]*\[!([A-Za-z-]+)\]([+-])?\s*(.*)$/.freeze
  BLOCKQUOTE_LINE = /^ {0,3}>/.freeze

  module_function

  def process(text)
    lines = text.lines
    output = []
    index = 0

    while index < lines.length
      rendered, consumed = render_callout(lines, index)

      if rendered
        output << rendered
        index += consumed
      else
        output << lines[index]
        index += 1
      end
    end

    output.join
  end

  def render_callout(lines, start_index)
    match = lines[start_index].match(CALLOUT_START)
    return [nil, 0] unless match

    block_lines, consumed = consume_block(lines, start_index)
    stripped = strip_blockquote_level(block_lines)
    first_line = stripped.first&.sub(/\r?\n\z/, "") || ""
    marker = first_line.match(/^\[!([A-Za-z-]+)\]([+-])?\s*(.*)$/)
    return [nil, 0] unless marker

    raw_type = marker[1].downcase
    canonical_type = CALLOUT_ALIASES.fetch(raw_type, raw_type)
    config = CALLOUT_TYPES[canonical_type] || CALLOUT_TYPES["note"]
    fold_state = marker[2]
    title = marker[3].strip
    title = config[:label] if title.empty?
    title = CGI.escapeHTML(title)

    body = stripped[1..] || []
    body_content = process(body.join)
    open_attribute = fold_state == "+" ? " open" : ""
    wrapper_tag = fold_state ? "details" : "div"
    title_tag = fold_state ? "summary" : "div"

    parts = []
    parts << "<#{wrapper_tag} class=\"callout\" data-callout=\"#{canonical_type}\" markdown=\"1\"#{open_attribute}>"
    parts << "<#{title_tag} class=\"callout-title\" markdown=\"span\">"
    parts << "<span class=\"callout-icon\" aria-hidden=\"true\">#{config[:icon]}</span>"
    parts << "<span class=\"callout-title-text\">#{title}</span>"
    parts << "<span class=\"callout-fold\" aria-hidden=\"true\"></span>" if fold_state
    parts << "</#{title_tag}>"

    unless body_content.strip.empty?
      parts << "<div class=\"callout-content\" markdown=\"1\">"
      parts << body_content.rstrip
      parts << "</div>"
    end

    parts << "</#{wrapper_tag}>"
    parts << ""

    [parts.join("\n"), consumed]
  end

  def consume_block(lines, start_index)
    block_lines = []
    index = start_index

    while index < lines.length
      line = lines[index]

      break unless line.match?(BLOCKQUOTE_LINE)

      block_lines << line
      index += 1
    end

    [block_lines, block_lines.length]
  end
  def strip_blockquote_level(lines)
    lines.map do |line|
      next line if line.strip.empty?

      line.sub(/^ {0,3}>[ \t]?/, "")
    end
  end
end

if defined?(Jekyll)
  Jekyll::Hooks.register [:pages, :documents], :pre_render do |document|
    next unless document.respond_to?(:content) && document.content

    document.content = ObsidianCallouts.process(document.content)
  end
end
