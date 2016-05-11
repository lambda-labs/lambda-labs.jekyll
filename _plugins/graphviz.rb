require 'ostruct'
require 'open3'
require 'fastimage'

class GraphvizOptions
  def initalize
  end

  def parse(str)
    binding.eval("opts(#{str})")
  end

  def opts(name, opts = {})
    OpenStruct.new(opts.merge(name: name))
  end
end

class GraphvizTag < Liquid::Block
  attr_reader :args

  @@paths = {
    "output_directory" => "/graphviz"
  }

  def initialize(tag_name, args_str, tokens)
    super
    # Ovo je uzasno, al jebiga, mrzi me da parsiram rucno.
    args_str = args_str || ""
    @args = GraphvizOptions.new.parse(args_str)
    args.opts = args.opts || {}
  end

  def render_graph(graph)
    opts = args.opts.to_a.lazy
      .map { |(k, v)| [k.to_s.strip, v.to_s.strip] }
      .reject { |(k, v)| %w(o O V v ? T).include?(k) }
      .map { |(k, v)| "-#{k}#{v}" }
      .to_a

    args.as = args.as || File.extname(args.name)[1..-1]
    opts << "-T#{args.as}"
    opts.concat style_as_opts

    out_path = File.join(@@paths['src_dir'], args.name)
    opts << "-o#{out_path}"

    cmd = "dot #{opts.join(' ')}"
    out, err, status = Open3.capture3(cmd, stdin_data: graph)
    raise "graphviz error: #{err}" unless status.success?

    out_path
  end

  def render(context)
    site = context.registers[:site]
    GraphvizTag::init_paths(site)
    graph = super
    out_path = render_graph(graph)
    src = File.join(@@paths["output_directory"], args.name)

    width, height = FastImage.size(out_path)
    site.static_files << Jekyll::StaticFile.new(site, site.source, @@paths["output_directory"], args.name)
    <<-MARKUP.strip
      <figure class="#{args.fw ? "fullwidth" : ""} graphviz"><amp-img layout="fixed" width="#{width}" height="#{height}" src="#{context["site"]["baseurl"]}#{src}"></amp-img></figure>
    MARKUP
  end

  def style
    {
      graph: {
        bgcolor: "#fffff8",
        fontcolor: "#111111",
        fontname: "Helvetica",
        fontsize: "11"
      },
      node: {
        color: "#111111",
        fillcolor: "#ffffff",
        style: "filled",
        fontname: "Helvetica",
        fontsize: "11"
      },
      edge: {
        color: "#111111",
        fontname: "Helvetica",
        fontsize: "11"
      }
    }
  end

private

  def type_to_opt(type)
    {
      graph: "-G",
      node: "-N",
      edge: "-E"
    }[type]
  end

  def style_as_opts
    style.map do |type, styles|
      styles.to_a.map do |(key, value)|
        "#{type_to_opt(type)}#{key}=#{value}"
      end
    end
  end

  def self.init_paths(site)
    return if @@paths["inited"]
    @@paths["src_dir"] = File.join(site.config["source"], @@paths["output_directory"])
    @@paths["dst_dir"] = File.join(site.config["destination"], @@paths["output_directory"])
    FileUtils.mkdir_p(@@paths["src_dir"]) unless File.exists?(@@paths["src_dir"])
  end
end

Liquid::Template.register_tag('graphviz', GraphvizTag)
