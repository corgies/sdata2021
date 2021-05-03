# coding: utf-8
require 'json'
require 'zlib'
require 'cgi'
require 'sanitize'
require 'nokogiri'

@list_input_parscit = Hash.new(0)

# PATH to ParsCit (https://github.com/knmnyn/ParsCit) :: need to be changed depending on your environment
@path_parscit = '/Users/corgies/ParsCit/bin/citeExtract.pl'
# @path_parscit = '/Users/jiro/tools_paper2/ParsCit/bin/citeExtract.pl'

def extract_template(raw)
  hash = Hash.new
  hash['original_text'] = raw.dup
  hash['wikitext_title'] = nil

  str = raw.dup
  str.scrub!('')
  str.gsub!("\n", '')
  str.gsub!(/<ref[^>]*>/i, '')
  str.gsub!(/<\/ref>/i, '')
  str.gsub!(/^\s+/, '')
  str.gsub!(/\s+$/, '')

  if str.include?('=') == true && str.include?('{') == true
    str.split('|').each{|item|
      key = item.split('=')[0]
      val = item.split('=')[1]

      if key.nil? == false
        key.gsub!(/^\s+/, '')
        key.gsub!(/\s+$/, '')
        key = key.downcase
      end

      if val.nil? == false
        val.gsub!(/^\s+/, '')
        val.gsub!(/\s+$/, '')
        val.gsub!('}}', '')
      end

      if key == 'title'
        hash['wikitext_title'] = val
      end
    }
  else
    if str.nil? == false
      str = CGI.unescape(str)
      str.scrub!('')
      str = Sanitize.clean(str)
      str.gsub!("'", '')
      str.gsub!('[', '')
      str.gsub!(']', '')
      str.gsub!(/^\s+/, '')
      str.gsub!(/\s+$/, '')
      if str.length != 0
        hash['input_parscit'] = str
        @list_input_parscit[str] += 1
      end
    end
  end

  return hash
end


puts "START\t#{Time.now}\t$ ruby #{__FILE__}"

Dir.glob("./revision/*.json.gz").each{|filepath|
  
  if filepath.include?('ref_and_cites') == false
    outpath = filepath.dup
    outpath.sub!('.json', '_ref_and_cites.json')

    outpath_parscit = filepath.dup
    outpath_parscit.sub!('./revision/', './parscit/')
    outpath_parscit.sub!('.json.gz', '.txt')
    outpath_parscit_result = outpath_parscit.dup
    outpath_parscit_result.sub!('.txt', '.xml')

    total_lines = Zlib::GzipReader.open(filepath).read.count("\n")
    i = 0

    Zlib::GzipWriter.open(outpath){|outfile|
      Zlib::GzipReader.open(filepath){|file|
        while line = file.gets
          line.chomp!

          i += 1
          h = JSON.load(line)

          page_id = h['pageid']
          page_title = h['title']

          puts "#{Time.now}\t#{i}/#{total_lines}\t#{page_id}\t#{page_title}"


          h.delete('sha1')
          h.delete('model')
          h.delete('format')

          text = h['text']
          h.delete('text')

          h['refs'] = Array.new
          h['template_cites'] = Array.new

          if text.nil? == false
            text.gsub!(/\n+/, ' ')
            text.gsub!(/\s+/, ' ')
            text.gsub!(/<!--[^>]*-->/, '')
            text.gsub!(/<ref[^>]*\/>/i, '')
            text.gsub!(/{{citation needed[^}]*}}/i, '')
            text.gsub!(/{{dead link[^}]*}}/i, '')

            text.scan(/<ref[^>]*>[^>]*<\/ref>/i).sort.uniq.each{|ref|
              tmp = extract_template(ref)
              h['refs'].push(tmp)
            }

            text.scan(/{{cit[^}]*}}/i).sort.uniq.each{|ref|
              tmp = extract_template(ref)
              h['template_cites'].push(tmp)
            }
          end
          outfile.puts h.to_json
        end
        file.close
      }
      outfile.close
    }

    i = 1

    File.open(outpath_parscit, 'w'){|file|
      @list_input_parscit.sort_by{|k,v|-v}.to_h.each{|k,v|
        str = "[#{i}] #{k}"
        file.puts str
        i += 1
      }

      system("perl -CSD #{@path_parscit} -m extract_citations #{outpath_parscit} > #{outpath_parscit_result}")
    }

    system("gzip --force --verbose #{outpath_parscit}")
    system("gzip --force --verbose #{outpath_parscit_result}")

    outpath_parscit = "#{outpath_parscit}.gz"
    outpath_parscit_result = "#{outpath_parscit_result}.gz"

    dic_xml = Hash.new
    xml = Nokogiri::XML.parse(Zlib::GzipReader.open(outpath_parscit_result).read)
    xml.css('//citationList/citation').each{|item|
      l = item.search('title').length
      if l == 0
      elsif l == 1
        t = item.search('title')[0]
        m = item.search('marker')[0]
        r = item.search('rawString')[0]
        marker = m.text
        title = t.text
        raw_string = r.text
        dic_xml[marker] = title
      else
        raise "Error\t#{item}"
      end
    }

    dic_title = Hash.new
    Zlib::GzipReader.open(outpath_parscit){|file|
      while line = file.gets
        line.chomp!
        if /^(\[\d+\]) (.*?)$/ =~ line
          marker = $1
          input_title = $2
          if dic_xml.has_key?(marker) == true
            dic_title[input_title] = dic_xml[marker]
          else
            dic_title[input_title] = nil
          end
        else
          raise "Error::Regexp:\t#{outpath_parscit}\t#{line}"
        end
      end
      file.close
    }

    a = Array.new

    Zlib::GzipReader.open(outpath){|file|
      while line = file.gets
        line.chomp!
        a.push(line)
      end
      file.close
    }

    Zlib::GzipWriter.open(outpath){|outfile|
      a.each{|line|
        h = JSON.load(line)

        h['refs'].each{|e|
          if e.has_key?('input_parscit') == true
            t = e['input_parscit']
            e['parscit_title'] = dic_title[t]
          end
        }

        h['template_cites'].each{|e|
          if e.has_key?('input_parscit') == true
            t = e['input_parscit']
            e['parscit_title'] = e['input_parscit']
          end
        }
        outfile.puts h.to_json
      }
      outfile.close
    }
    
  end
}


puts "END\t#{Time.now}\t$ ruby #{__FILE__}"
