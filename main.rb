require 'rubytorrent'
require 'timeout'
require 'geoip'
require 'rubygems'
require "graphviz"

def dump_metainfoinfo(mii)
  if mii.single?
    <<EOS
       length: #{mii.length / 1024}kb
     filename: #{mii.name}
EOS
  else
    mii.files.map do |f|
      <<EOS
   - filename: #{File.join(mii.name, f.path)}
       length: #{f.length}
EOS
    end.join + "\n"
  end
end

mi = RubyTorrent::MetaInfo.from_location("http://torrents.thepiratebay.org/5434382/Alice_In_Wonderland_2010_TS_XViD_-_IMAGiNE%5BExtraTorrent%5D.5434382.TPB.torrent")
puts dump_metainfoinfo(mi.info).chomp
torrent_name = mi.info.name
puts torrent_name

hosts = []
mi.trackers.each do |track|
  puts "#{track}:"
  begin
    timeout(8) do # só tem 8 segundos para carregar
      tc = RubyTorrent::TrackerConnection.new(track, mi.info.sha1, mi.info.total_length, 9999, "rubytorrent.dumppeer") # complete abuse, i know
      begin
        tc.force_refresh
        puts "<no peers>" if tc.peers.length == 0
        tc.peers.each do |p|
          puts "#{p.ip}:#{p.port}"
          hosts << p.ip
        end
      rescue RubyTorrent::TrackerError => e
        puts "error connecting to tracker: #{e.message}"
      end
    end
  rescue Exception=>error
    puts "Lerdo: #{error}\n\n"
  end
end

puts "Fazendo gráfico..."
g = GraphViz::new( "G", :type => "digraph")
g.node[:color]    = "#ddaa66"
g.node[:style]    = "filled"
g.node[:penwidth] = "1"
g.node[:fontname] = "Trebuchet MS"
g.node[:fontsize] = "8"
g.node[:fillcolor]= "#ffeecc"
g.node[:margin]   = "0.0"
g[:overlap] = false


torrent_node = g.add_node(torrent_name)
hosts.uniq.each do |ip|
  geoip =  GeoIP.new('GeoIP.dat').country(ip)
  pais = geoip[5] if geoip[5]
  host_node = g.add_node(ip)
  if pais_node = g.get_node(pais)
    g.add_edge(host_node, pais_node)
  else
    pais_node = g.add_node(pais, :fillcolor=>"#ffffcc")
    g.add_edge(pais_node, torrent_node)
    g.add_edge(host_node, pais_node)
  end
end


if g
  puts "\nSalvando..."
  g.output( :png => "result-circo.png", :use=>:circo)
  puts "Salvo!"
end


