module Redcar
  class Project
    module Fuzzy
      
      # Matches all files with the search string
      #
      # @param [String] query
      #  Search string, can contain full file name with path or just the file name.
      #  Name of each directory in the path doesn't have to be specified exactly.
      #
      # @param [String] files Array of files to match the search string
      #
      # @return [Array<String>]
      # array of all the files that match the path
      #
      # @todo Optimize the match algorithm
      #
      def self.match_files(query, files)
        res = files.map { |file_name| [file_name, match_file(query, file_name)] }
        # res = files.map { |file_name| [file_name, match_string(text, file_name.gsub("/", ""))] }
        res = res.select { |r| r[1] }.sort { |a, b| b[1] <=> a[1] }
        res.map { |r| r[0] }
      end
      
      
      # Test if search string matches file name
      #
      # @param [String] query
      #  Search string, can contain full file name with path or
      #  just the file name. Name of each directory in the path doesn't
      #  have to be specified exactly.
      #
      # @param [String] file_name
      #  File name of the target file, can contain either just the file name,
      #  or the whole path.
      #
      # @return [Integer]
      #  match score if match was successful, nil otherwise
      #
      # @todo Optimize the match algorithm
      #
      def self.match_file(query, file_name)
        pattern_path = query.split("/")
        file_path = file_name.split("/")
        
        pattern = pattern_path.pop
        file = file_path.pop
        
        score = 0
        
        # if there is path specified in the search
        if pattern_path && pattern_path.size > 0
          # doesn't match if search is deeper than the file,
          # eg. search: a/b and file is only b
          # or doesn't match the filename
          return false if file_path.size == 0 || !match_string(pattern, file)
          pattern = pattern_path.shift
          file = file_path.shift
          
          while true
            matched = false
            
            res = match_string(pattern, file)
            if res
              pattern = pattern_path.shift
              matched = true
              score += res
            end
            file = file_path.shift
            
            return false if file_path.empty? && !matched
            return score if pattern_path.empty? && matched
          end
        else
          match_string(pattern, file)
        end
      end
      
      
      # Fuzzy match on two strings
      #
      # @param [String] query search string
      # @param [String] string target to be searched
      #
      # @return [Integer] match score if match was successful, nil otherwise
      #
      # @todo Benchmark to see if regex is the fastest solution
      #
      def self.match_string(query, string)
        re = make_regex(query)
        score = 0
        last = nil
        
        m = string.match(re)
        return nil unless m
        
        m.captures.each_with_index do |capture, index|
          if index > 0
            # FIX - probably doesn't work properly on string with duplicate letters,
            # still better than nothing though. The string needs to be sliced after each
            # iteration in order to prevent this
            current_index = string.index(capture)
            last_index = string.index(last)
            score += 1 if current_index == last_index + 1
          end
          last = capture
        end
        score
      end
     
      # Create regex for the filter
      def self.make_regex(text)
        re_src = "(" + text.split(//).map{|l| Regexp.escape(l) }.join(").*?(") + ")"
        Regexp.new(re_src, :options => Regexp::IGNORECASE)
      end
      
    end
  end
end
