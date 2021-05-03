require 'json'
require 'zlib'
require 'time'

list_filepath = Hash.new

puts "START\t#{Time.now}\t$ ruby #{__FILE__}"

Dir.glob('./result/*.json.gz').sort.each{|filepath|
  if /^\.\/result\/(\d+)_(.*?)\.json\.gz$/ =~ filepath
    pageid = $1
    method = $2
    if list_filepath.has_key?(pageid) == false
      list_filepath[pageid] = Hash.new
    end
    list_filepath[pageid][method] = filepath
  else
    raise "Error::Regexp:\t#{filepath}"
  end
}

list_filepath.each{|pageid, h1|
  outpath = "./result/#{pageid}_merge.json.gz"
  
  dic = Hash.new
  oldest = Hash.new

  h1.each{|method, filepath|
    raw = JSON.load(Zlib::GzipReader.open(filepath).read)
    raw.each{|doi, tmp|
      if dic.has_key?(doi) == false
        dic[doi] = Hash.new
        dic[doi]['oldest'] = Hash.new
      end

      dic[doi][method] = tmp.dup

      if oldest.has_key?(doi) == false
        oldest[doi] = Hash.new
      end

      if tmp.has_key?('meta') == true
        if tmp['meta'].has_key?('revision_timestamp') == true
          timestamp = Time.parse(tmp['meta']['revision_timestamp']).to_i
          if oldest[doi].has_key?(timestamp) == false
            oldest[doi][timestamp] = tmp['meta'].dup
            oldest[doi][timestamp]['method'] = Array.new
            oldest[doi][timestamp]['method'].push(method)
          else
            oldest[doi][timestamp]['method'].push(method)
          end
        end
      end

      dic[doi]['oldest'] = oldest[doi][oldest[doi].keys.min]
    }
  }

  Zlib::GzipWriter.open(outpath){|outfile|
    outfile.puts JSON.pretty_generate(dic)
    outfile.close
  }
  puts dic.to_json
}

puts "END\t#{Time.now}\t$ ruby #{__FILE__}"
