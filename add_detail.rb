require 'json'
require 'zlib'

dic_field = Hash.new
dic_crossref_metadata = Hash.new

filepath_field = './baselist/dic/doi+issn+field.jsonl.gz'
filepath_crossref_metadata = './baselist/dic/doi+crossref_metadata.jsonl.gz'

def gen_dic(filepath, hash)
  Zlib::GzipReader.open(filepath){|file|
    while line = file.gets
      line.chomp!
      tmp = JSON.load(line)
      doi = tmp['doi']
      hash[doi] = tmp.dup
    end
    file.close
  }
end

puts "START\t#{Time.now}\t$ ruby #{__FILE__}"


dic_bot = Hash.new
filepath_bot = './baselist/dic/list_bot.jsonl.gz'

Zlib::GzipReader.open(filepath_bot){|file|
  while line = file.gets
    line.chomp!
    tmp = JSON.load(line)
    editor_name = tmp['editor_name']
    dic_bot[editor_name] = true
  end
  file.close
}

gen_dic(filepath_field, dic_field)
gen_dic(filepath_crossref_metadata, dic_crossref_metadata)

Dir.glob('./result/*_merge.json.gz').sort.each{|filepath|
  outpath = filepath.dup
  outpath.sub!('_merge.json.gz', '_final.jsonl.gz')

  Zlib::GzipWriter.open(outpath){|outfile|  
    raw = JSON.load(Zlib::GzipReader.open(filepath).read)
    raw.each{|doi, h1|
      tmp = Hash.new
      tmp['doi'] = doi

      editor_name = h1['oldest']['editor_name']
      tmp['editor_name'] = editor_name

      if h1['oldest']['editor_name']['anonymous'] == true
        tmp['editor_type'] = 'IP'
      elsif dic_bot.has_key?(editor_name) == true
        tmp['editor_type'] = 'Bot'
      else
        tmp['editor_type'] = 'User'
      end

      tmp['issn'] = dic_field[doi]['issn']
      tmp['page_id'] = h1['oldest']['page_id']
      tmp['page_title'] = h1['oldest']['page_title']
      ['paper_author', 'paper_container_title', 'paper_issue', 'paper_page', 'paper_published_year', 'paper_publisher', 'paper_title', 'paper_type', 'paper_volume'].each{|k|
        tmp[k] = dic_crossref_metadata[doi][k]
      }
      tmp['research_field'] = dic_field[doi]['research_field']

      ['revision_comment', 'revision_id', 'revision_timestamp'].each{|k|
        tmp[k] = h1['oldest'][k]
      }
      outfile.puts tmp.to_json
      puts tmp.to_json
    }
    outfile.close
  }
}

puts "END\t#{Time.now}\t$ ruby #{__FILE__}"

# "editor_name": "Quebecois1983",
# "editor_anonymous": false,
